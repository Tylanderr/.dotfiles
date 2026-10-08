return {
  "sudo-tee/opencode.nvim",
  event = "VeryLazy",
  -- commit = "8edc19ac64e3075d4d68e49ef6846dec562ed316",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    local api = vim.api
    local fn = vim.fn
    local Promise = require("opencode.promise")
    local context = require("opencode.context")
    local session_runtime = require("opencode.services.session_runtime")
    local agent_model = require("opencode.services.agent_model")

    local opencode_filetypes = {
      opencode = true,
      opencode_output = true,
      opencode_footer = true,
    }

    local function async(callback)
      Promise.async(callback)()
    end

    local function open_session(options)
      return session_runtime
        .open(vim.tbl_extend("force", { new_session = false }, options or {}))
        :await()
    end

    local function switch_to_coworker()
      agent_model.switch_to_mode("coworker"):await()
    end

    local function toggle_panel()
      local previous_win = api.nvim_get_current_win()
      local toggle_promise = require("opencode.api").toggle()

      if api.nvim_win_is_valid(previous_win) then
        api.nvim_set_current_win(previous_win)
      end

      return toggle_promise
    end

    local function paste_current_text()
      local current_win = api.nvim_get_current_win()
      local mode = fn.mode()
      local buf = api.nvim_get_current_buf()
      local text

      if mode == "v" or mode == "V" or mode == "\022" then
        local current_pos = fn.getpos(".")
        local old_register = fn.getreg("x")
        local old_register_type = fn.getregtype("x")

        vim.cmd('normal! "xy')
        text = fn.getreg("x")

        fn.setreg("x", old_register, old_register_type)
        vim.cmd("normal! gv")
        api.nvim_feedkeys(
          api.nvim_replace_termcodes("<Esc>", true, false, true),
          "nx",
          true
        )
        fn.setpos(".", current_pos)
      else
        local line = fn.line(".")
        text = api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
      end

      if not text or not text:match("%S") then
        vim.notify("No text selected", vim.log.levels.WARN)
        return
      end

      async(function()
        open_session({ new_session = false })
        require("opencode.ui.input_window")._append_to_input(text)

        if api.nvim_win_is_valid(current_win) then
          api.nvim_set_current_win(current_win)
        end

        vim.cmd("stopinsert")
      end)
    end

    local function add_current_file()
      local file = api.nvim_buf_get_name(0)

      if file == "" then
        vim.notify("Current buffer has no file to add", vim.log.levels.WARN)
        return
      end

      context.add_file(file)
    end

    local function open_input()
      Promise.async(function()
        local state = require("opencode.state")
        local ui = require("opencode.ui.ui")

        open_session({ focus = "input", start_insert = false })
        switch_to_coworker()

        local observation = state.session.active_observation()
        if not observation then
          error("OpenCode session is not active")
        end

        if observation:read().sync.session.state ~= "current" then
          observation:_start_resource("session")
        end

        for _ = 1, 60 do
          if state.session.active_observation() ~= observation then
            return
          end

          local sync = observation:read().sync.session
          if sync.state == "current" then
            ui.focus_input({ restore_position = true, start_insert = false })
            return
          end

          if sync.state == "error" or sync.state == "unsupported" then
            error("Session metadata unavailable: " .. vim.inspect(sync))
          end

          Promise.delay(50):await()
        end

        error("Timed out waiting for OpenCode session metadata")
      end)():catch(function(err)
        vim.notify("OpenCode input: " .. tostring(err), vim.log.levels.ERROR)
      end)
    end

    local function open_output()
      async(function()
        open_session({
          focus = "output",
          start_insert = false,
        })
        switch_to_coworker()

        local observation = require("opencode.state").session.active_observation()
        if not observation then
          vim.notify("OpenCode session is not active", vim.log.levels.WARN)
          return
        end

        local ok, err = pcall(function()
          observation:_start_resource("messages")
        end)

        if not ok then
          vim.notify(
            "Failed to refresh OpenCode output: " .. tostring(err),
            vim.log.levels.ERROR
          )
        end
      end)
    end

    local function start_new_session()
      async(function()
        local saved_context = context.get_context()
        local saved_selections = vim.deepcopy(saved_context.selections or {})
        local saved_files = vim.deepcopy(saved_context.mentioned_files or {})

        open_session({
          new_session = true,
          focus = "input",
          start_insert = false,
        })
        switch_to_coworker()

        for _, selection in ipairs(saved_selections) do
          context.add_selection(selection)
        end
        for _, file in ipairs(saved_files) do
          context.add_file(file)
        end
      end)
    end

    local function unload_attachments()
      context.unload_attachments()
    end

    local function paste_image()
      local state = require("opencode.state")
      local ui = require("opencode.ui.ui")
      local image_handler = require("opencode.image_handler")

      ui.focus_input({ restore_position = true, start_insert = false })

      local windows = state.windows
      if not windows then
        vim.notify("OpenCode input window is not open", vim.log.levels.WARN)
        return
      end

      local win = windows.input_win
      local buf = windows.input_buf
      if not win or not buf then
        vim.notify("OpenCode input window is not available", vim.log.levels.WARN)
        return
      end

      local row, col = unpack(api.nvim_win_get_cursor(win))
      local line = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""

      -- Split the current line at the cursor.
      api.nvim_buf_set_lines(buf, row - 1, row, false, {
        line:sub(1, col),
        line:sub(col + 1),
      })
      api.nvim_win_set_cursor(win, { row + 1, 0 })

      if not image_handler.paste_image_from_clipboard() then
        return
      end

      -- Image insertion is scheduled by opencode.nvim, so wait for it.
      vim.schedule(function()
        local image_row = row + 1

        -- Insert a new line after the image mention.
        api.nvim_buf_set_lines(buf, image_row, image_row, false, { "" })
        api.nvim_set_current_win(win)
        api.nvim_win_set_cursor(win, { image_row + 1, 0 })

        vim.cmd("stopinsert")
      end)
    end

    local function reset_window_width()
      local default_width = math.floor(vim.o.columns * 0.33)

      for _, win in ipairs(api.nvim_list_wins()) do
        local buf = api.nvim_win_get_buf(win)
        if opencode_filetypes[vim.bo[buf].filetype] then
          pcall(api.nvim_win_set_width, win, default_width)
        end
      end
    end

    local function delete_all_sessions()
      if fn.confirm("Delete ALL opencode sessions?", "&Yes\n&No", 2) ~= 1 then
        return
      end

      fn.jobstart({ "opencode", "session", "list" }, {
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
            fn.jobstart({ "opencode", "session", "delete", id }, {
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
    end

    local function close_other_windows()
      local current_win = api.nvim_get_current_win()
      local ok, ui = pcall(require, "opencode.ui.ui")
      local focused_is_opencode = ok and ui.is_opencode_window(current_win)

      -- Keep the leftmost non-OpenCode window when focused on OpenCode.
      local leftmost
      if focused_is_opencode and ok then
        local leftmost_col = math.huge
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
          if not ui.is_opencode_window(win) then
            local position = api.nvim_win_get_position(win)
            if position[2] < leftmost_col then
              leftmost_col = position[2]
              leftmost = win
            end
          end
        end
      end

      for _, win in ipairs(api.nvim_list_wins()) do
        if win ~= current_win and win ~= leftmost then
          local buf = api.nvim_win_get_buf(win)
          if not opencode_filetypes[vim.bo[buf].filetype] then
            pcall(api.nvim_win_close, win, false)
          end
        end
      end
    end

    require("opencode").setup({
      preferred_picker = "fzf",
      preferred_completion = "blink",
      default_global_keymaps = true,
      default_mode = "coworker",
      default_system_prompt = nil,
      keymap_prefix = "<leader>o",
      opencode_executable = "opencode",

      context = {
        current_file = {
          enabled = false,
        },
        diagnostics = {
          enabled = false,
        }
      },

      keymap = {
        editor = {
          ["<C-\\>"] = { toggle_panel },
          ["<leader>/"] = { "quick_chat", mode = { "n", "x" } },
          ["<leader>ot"] = { "configure_variant" },
          ["<leader>av"] = { paste_current_text, mode = { "n", "v" }, desc = "Paste selection into OpenCode input", },
          ["<leader>af"] = { add_current_file, mode = { "n" } },
          ["<leader>oi"] = { open_input, mode = { "n" } },
          ["<leader>oo"] = { open_output, mode = { "n" }, desc = "Open and refresh OpenCode output", },
          ["<leader>ox"] = { unload_attachments },
          ["<leader>on"] = { start_new_session },
          ["<leader>ov"] = { paste_image },
          ["<leader>ods"] = false,
        },

        input_window = {
          ["j"] = { function() vim.cmd("normal! gj") end, mode = "n" },
          ["k"] = { function() vim.cmd("normal! gk") end, mode = "n" },
          ["<leader>ods"] = false,
          ["<M-m>"] = false,
          ["<S-tab>"] = { "switch_mode", mode = { "n" } },
          ["<C-c>"] = {
            function()
              local ok, state = pcall(require, "opencode.state")
              if ok and state.jobs.is_running() then
                require("opencode.api").cancel()
              end
            end,
            mode = { "n" },
          },
        },
        output_window = {
          ["<leader>ods"] = false,
        }
      },

      ui = {
        window_width = 0.33,
        zoom_width = 0.8,
        picker_width = 0.6,

        input = {
          text = {
            wrap = true,
          },
        },

        output = {
          tools = {
            show_reasoning_output = false,
          }
        }
      },
    })

    vim.keymap.set("n", "<leader>ow", reset_window_width, {
      desc = "Reset opencode window size",
    })

    -- Delete all saved opencode sessions
    vim.keymap.set("n", "<leader>ods", delete_all_sessions, {
      desc = "Delete all opencode sessions",
    })

    -- Close open windows except the focused and opencode related windows.
    -- If focused on an opencode window, also keep the leftmost non-opencode window.
    vim.keymap.set("n", "<leader>wo", close_other_windows)
  end,
}
