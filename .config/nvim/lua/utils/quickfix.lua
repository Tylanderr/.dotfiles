local M = {}

function M.textfunc(info)
  local is_quickfix = info.quickfix == 1
  local list
  if is_quickfix then
    list = vim.fn.getqflist({ id = info.id, items = 1 }).items
  else
    list = vim.fn.getloclist(0, { id = info.id, items = 1 }).items
  end

  local lines = {}
  for index = info.start_idx, info.end_idx do
    local item = list[index]
    local filename = item.filename
    if item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) then
      filename = vim.api.nvim_buf_get_name(item.bufnr)
    end

    local basename = filename and vim.fn.fnamemodify(filename, ":t") or ""
    lines[#lines + 1] = string.format("%s|%d col %d|", basename, item.lnum or 1, item.col or 1)
  end

  return lines
end

_G.QuickfixFilenameText = M.textfunc

return M
