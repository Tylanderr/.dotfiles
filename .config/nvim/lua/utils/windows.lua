local M = {}

function M.is_opencode_window(win)
  local ok, ui = pcall(require, "opencode.ui.ui")
  return ok and ui.is_opencode_window(win)
end

-- Leftmost (then topmost) non-floating window. Skips OpenCode windows unless
-- opts.include_opencode is set; opts.exclude(win) can reject extra windows.
function M.leftmost_window(tabpage, opts)
  opts = opts or {}
  local target, target_position
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage or 0)) do
    local is_candidate = vim.api.nvim_win_get_config(win).relative == ""
      and (opts.include_opencode or not M.is_opencode_window(win))
      and not (opts.exclude_winfixbuf and vim.wo[win].winfixbuf)
      and not (opts.exclude and opts.exclude(win))
    if is_candidate then
      local position = vim.api.nvim_win_get_position(win)
      if not target_position
        or position[2] < target_position[2]
        or (position[2] == target_position[2] and position[1] < target_position[1])
      then
        target, target_position = win, position
      end
    end
  end
  return target
end

return M
