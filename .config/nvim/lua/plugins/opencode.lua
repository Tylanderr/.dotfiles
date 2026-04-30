return {
  "sudo-tee/opencode.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        render_modes = { 'n', 'i', 'c', 't' },
        anti_conceal = {
          enabled = true,
          disabled_modes = { 'n', 'c', 't' },
        },
        file_types = { 'markdown', 'opencode_output' },
      },
    },
  },
  config = function()
    local markdown_render_enabled = true

    local function set_markdown_render_state(buf)
      if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
        return
      end

      local ok, render_markdown = pcall(require, 'render-markdown')
      if not ok then
        return
      end

      local ft = vim.bo[buf].filetype
      if ft == 'opencode_output' then
        vim.api.nvim_buf_call(buf, function()
          render_markdown.set_buf(true)
        end)
      elseif ft == 'markdown' then
        vim.api.nvim_buf_call(buf, function()
          render_markdown.set_buf(markdown_render_enabled)
        end)
      end
    end

    require("opencode").setup({
      preferred_picker = 'fzf',
      preferred_completion = 'blink',
      default_global_keymaps = true,
      default_mode = 'coworker',
      default_system_prompt = nil,
      keymap_prefix = '<leader>o',
      opencode_executable = 'opencode',

      keymap = {
        editor = {
          ['<C-\\>'] = { 'toggle' },
          ['<leader>/'] = { 'quick_chat', mode = { 'n', 'x' } },
          ['<leader>ods'] = false,
          ['<leader>av'] = {
            function()
              local mode = vim.fn.mode()
              if mode:match('n') then
                local line = vim.fn.line('.')
                require('opencode.api').add_visual_selection({ open_input = false }, { start = line, stop = line })
              else
                require('opencode.api').add_visual_selection({ open_input = false })
              end
            end,
            mode = { 'n', 'v' },
          },

          ['<leader>oi'] = { function()
            require('opencode.core').open({ new_session = false, focus = 'input', start_insert = false })
          end },

          ['<leader>ox'] = { function()
            require('opencode.context').unload_attachments()
          end },

          ['<leader>on'] = { function()
            local Promise = require('opencode.promise')
            Promise.async(function()
              local context = require('opencode.context')
              -- Save current selections and mentioned files (including pasted images) before new_session clears them
              local ctx = context.get_context()
              local saved_selections = vim.deepcopy(ctx.selections or {})
              local saved_files = vim.deepcopy(ctx.mentioned_files or {})
              require('opencode.core').open({ new_session = true, focus = 'input', start_insert = false }):await()
              -- Ensure coworker agent is selected
              require('opencode.core').switch_to_mode('coworker'):await()
              -- Restore selections and files into the new session
              for _, sel in ipairs(saved_selections) do
                context.add_selection(sel)
              end
              for _, file in ipairs(saved_files) do
                context.add_file(file)
              end
            end)()
          end }
        },

        input_window = {
          ['<leader>ods'] = false,
          ['<M-m>'] = false,
          ['<C-c>'] = {
            function()
              local ok, state = pcall(require, 'opencode.state')
              if ok and state.is_running and state.is_running() then
                require('opencode.api').cancel()
              end
            end,
            mode = { 'n' },
          },
        },
        output_window = {
          ['<leader>ods'] = false,
        }
      },

      ui = {
        window_width = 0.30,
        zoom_width = 0.8,
      },
    })

    -- Reset opencode windows to their default width (30%)
    vim.keymap.set("n", "<leader>or", function()
      local opencode_fts = { opencode = true, opencode_output = true, opencode_footer = true }
      local default_width = math.floor(vim.o.columns * 0.30)

      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype
        if opencode_fts[ft] then
          pcall(vim.api.nvim_win_set_width, win, default_width)
        end
      end
    end, { desc = "Reset opencode window size" })

    vim.keymap.set("n", "<leader>mr", function()
      markdown_render_enabled = not markdown_render_enabled

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        set_markdown_render_state(buf)
      end

      local state = markdown_render_enabled and "enabled" or "disabled"
      vim.notify("Markdown rendering " .. state .. " (opencode_output unchanged)", vim.log.levels.INFO)
    end, { desc = "Toggle markdown rendering" })

    local markdown_render_group = vim.api.nvim_create_augroup("OpencodeMarkdownRender", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
      group = markdown_render_group,
      callback = function(args)
        set_markdown_render_state(args.buf)
      end,
    })

    -- Delete all saved opencode sessions
    vim.keymap.set("n", "<leader>ods", function()
      local choice = vim.fn.confirm("Delete ALL opencode sessions?", "&Yes\n&No", 2)
      if choice ~= 1 then return end

      vim.fn.jobstart({ "opencode", "session", "list" }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          local ids = {}
          for _, line in ipairs(data) do
            local id = line:match("^(ses_%S+)")
            if id then
              table.insert(ids, id)
            end
          end

          if #ids == 0 then
            vim.notify("opencode: no sessions to delete", vim.log.levels.INFO)
            return
          end

          local deleted = 0
          local total = #ids
          for _, id in ipairs(ids) do
            vim.fn.jobstart({ "opencode", "session", "delete", id }, {
              on_exit = function(_, code)
                if code == 0 then
                  deleted = deleted + 1
                else
                  vim.notify("opencode: failed to delete session " .. id, vim.log.levels.WARN)
                end
                if deleted == total then
                  vim.notify(string.format("opencode: deleted %d session(s)", total), vim.log.levels.INFO)
                end
              end,
            })
          end
        end,
        on_exit = function(_, code)
          if code ~= 0 then
            vim.notify("opencode: session list command failed", vim.log.levels.ERROR)
          end
        end,
      })
    end, { desc = "Delete all opencode sessions" })

    -- Close open windows except the focused and opencode related windows.
    -- If focused on an opencode window, also keep the leftmost non-opencode window.
    vim.keymap.set("n", "<leader>wo", function()
      local cur_win = vim.api.nvim_get_current_win()
      local ok, ui = pcall(require, "opencode.ui.ui")
      local focused_is_opencode = ok and ui.is_opencode_window(cur_win)

      -- Find the leftmost non-opencode window (only matters when focused on opencode)
      local leftmost = nil
      if focused_is_opencode and ok then
        local leftmost_col = math.huge
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not ui.is_opencode_window(win) then
            local pos = vim.api.nvim_win_get_position(win)
            if pos[2] < leftmost_col then
              leftmost_col = pos[2]
              leftmost = win
            end
          end
        end
      end

      local opencode_fts = { opencode = true, opencode_output = true, opencode_footer = true }
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if win ~= cur_win and win ~= leftmost then
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.bo[buf].filetype
          if not opencode_fts[ft] then
            pcall(vim.api.nvim_win_close, win, false)
          end
        end
      end
    end)
  end,
}
