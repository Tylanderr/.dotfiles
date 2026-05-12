local float_term_buf = nil
local float_term_win = nil

local function toggle_float_term()
  if float_term_win and vim.api.nvim_win_is_valid(float_term_win) then
    vim.api.nvim_win_close(float_term_win, false)
    float_term_win = nil
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  if not float_term_buf or not vim.api.nvim_buf_is_valid(float_term_buf) then
    float_term_buf = vim.api.nvim_create_buf(false, true)
  end

  float_term_win = vim.api.nvim_open_win(float_term_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })

  if vim.bo[float_term_buf].buftype ~= "terminal" then
    vim.cmd("terminal")
  end

  vim.cmd("startinsert")
end

return {
  vim.keymap.set({ "n", "t" }, "<C-t>", toggle_float_term)
}
