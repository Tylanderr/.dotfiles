return {
  "sudo-tee/opencode.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        anti_conceal = { enabled = false },
        file_types = { 'opencode_output' },
      },
      ft = { 'opencode_output' },
    },
    'saghen/blink.cmp',
    'ibhagwan/fzf-lua',
  },
  config = function()
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
          ['<leader>av'] = { 'add_visual_selection', mode = { 'v' } },
          ['<leader>oi'] = { function()
            require('opencode.core').open({ new_session = false, focus = 'input', start_insert = false })
          end },
          ['<leader>on'] = { function()
            require('opencode.core').open({ new_session = true, focus = 'input', start_insert = false })
          end }
        },
        input_window = {
          ['<tab>'] = { 'switch_mode' },
          ['<C-c>'] = {
            function()
              if require('opencode.state').is_running() then
                require('opencode.api').cancel()
              end
            end,
            mode = { 'n' },
          },
        },
      },
      ui = {
        window_width = 0.40,
        zoom_width = 0.8,
      },
    })

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
