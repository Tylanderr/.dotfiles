local function send_fff_to_quickfix()
  local state = require("fff.picker_ui.picker_ui_state").state
  if not state.active then return end

  local canonicalize = require("fff.utils").canonicalize_fff_path
  local qf_items = {}

  if state.mode == "grep" then
    local grep_items = {}
    if next(state.selected_items) then
      for _, item in pairs(state.selected_items) do
        table.insert(grep_items, item)
      end
    else
      local grep = require("fff.picker_ui.grep_renderer")
      local grep_config = vim.tbl_extend("force", state.grep_config or {}, { max_matches_per_file = 0 })
      local result = grep.search(state.query, 0, 10000, grep_config, state.grep_mode)
      grep_items = result and result.items or {}
    end

    for _, item in ipairs(grep_items) do
      local path = canonicalize(item.relative_path)
      if path then
        table.insert(qf_items, {
          filename = path,
          lnum = item.line_number or 1,
          col = (item.col or 0) + 1,
          text = "",
        })
      end
    end
  else
    local paths = {}
    if next(state.selected_files) then
      for relative_path in pairs(state.selected_files) do
        table.insert(paths, relative_path)
      end
    else
      for _, item in ipairs(state.filtered_items) do
        table.insert(paths, item.relative_path)
      end
    end

    for _, relative_path in ipairs(paths) do
      local path = canonicalize(relative_path)
      if path then
        table.insert(qf_items, {
          filename = path,
          lnum = 1,
          col = 1,
          text = vim.fn.fnamemodify(path, ":."),
        })
      end
    end
  end

  if #qf_items == 0 then
    vim.notify("No matches to send to quickfix", vim.log.levels.WARN)
    return
  end

  local is_grep = state.mode == "grep"
  require("fff.picker_ui.layout_manager").close()
  require("utils.quickfix").set(qf_items)
  pcall(vim.cmd, "cc 1")

  local count = #qf_items
  local unit = is_grep and (count == 1 and "match" or "matches") or (count == 1 and "file" or "files")
  vim.notify(string.format("Added %d %s to quickfix list", count, unit), vim.log.levels.INFO)
end

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
        local windows = require("utils.windows")
        if windows.is_opencode_window(current_win) then
          local target = windows.leftmost_window(0)
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
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "FFFOpen",
      callback = function()
        local state = require("fff.picker_ui.picker_ui_state").state
        local action = send_fff_to_quickfix
        for _, mapping in ipairs({
          { buf = state.input_buf, modes = { "i", "n" } },
          { buf = state.list_buf, modes = "n" },
          { buf = state.preview_buf, modes = "n" },
        }) do
          if mapping.buf and vim.api.nvim_buf_is_valid(mapping.buf) then
            vim.keymap.set(mapping.modes, "<C-q>", action, {
              buffer = mapping.buf,
              silent = true,
              desc = "Send matches to quickfix",
            })
          end
        end
      end,
      desc = "Override fff quickfix send to keep the list closed",
    })
  end,
  keys = {
    { "<leader>ff", function() require("fff").find_files({ layout = { height = 0.6, width = 0.4 }, preview = { enabled = false }, }) end, desc = "Find files", nowait = true, },
    { "<leader>fg", function() require("fff").live_grep() end, desc = "Live grep", nowait = true, },
    { "<leader>fz", function() require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } }) end, desc = "Fuzzy grep", },
    { "<leader>fw", function() require("fff").live_grep_under_cursor() end, mode = { "n", "x" }, desc = "Search current word / selection", },
  },
}
