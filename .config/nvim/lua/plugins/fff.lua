return {
  "dmtrKovalenko/fff",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  opts = {
    layout = {
      prompt_position = "top",
    },
    keymaps = {
      close = { "<Esc>", "<C-c>"}
    },
    debug = {
      enabled = false,
      show_scores = false,
    },
    grep = {
      modes = { "regex", "plain", "fuzzy" },
    },
    select = {
      select_window = function(current_buf, action)
        local current_win = vim.api.nvim_get_current_win()
        local ok, ui = pcall(require, "opencode.ui.ui")
        if ok and ui.is_opencode_window(current_win) then
          local target, target_col
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local config = vim.api.nvim_win_get_config(win)
            if config.relative == "" and not ui.is_opencode_window(win) then
              local col = vim.api.nvim_win_get_position(win)[2]
              if not target_col or col < target_col then
                target, target_col = win, col
              end
            end
          end

          if not target then
            vim.cmd("topleft vsplit")
            target = vim.api.nvim_get_current_win()
          end

          return target
        end

        if action ~= "edit" then
          return nil
        end

        local buftype = vim.api.nvim_get_option_value("buftype", { buf = current_buf })
        local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = current_buf })
        local winfixbuf = require("fff.utils").window_has_winfixbuf(current_win)
        if buftype == "" and modifiable and not winfixbuf then
          return nil
        end

        return require("fff.utils").find_suitable_window()
      end,
    },
  },
  lazy = false,
  keys = {
    { "<leader>ff", function() require("fff").find_files({ layout = { height = 0.6, width = 0.4 }, preview = { enabled = false }, }) end, desc = "Find files", nowait = true, },
    { "<leader>fg", function() require("fff").live_grep() end, desc = "Live grep", nowait = true, },
    { "<leader>fz", function() require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } }) end, desc = "Fuzzy grep", },
    { "<leader>fw", function() require("fff").live_grep_under_cursor() end, mode = { "n", "x" }, desc = "Search current word / selection", },
  },
}
