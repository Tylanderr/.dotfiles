local left_term_buf = nil
local left_term_win = nil
local left_previous_buf = nil

local function setup_term_keymaps(buf)
  local last_ctrl_c = nil

  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    buffer = buf,
    nowait = true,
  })

  vim.keymap.set("t", "<C-c>", function()
    local now = vim.uv.hrtime()
    local double_press = last_ctrl_c and now - last_ctrl_c <= 400 * 1e6

    if double_press then
      last_ctrl_c = nil
      return "<C-\\><C-n>"
    end

    last_ctrl_c = now
    return "<C-c>"
  end, {
    buffer = buf,
    expr = true,
    nowait = true,
    desc = "Interrupt; press twice for terminal-normal mode",
  })
end

local function toggle_left_terminal()
  -- Restore the previous buffer when the terminal is already open.
  if left_term_win
      and vim.api.nvim_win_is_valid(left_term_win)
      and vim.api.nvim_win_get_buf(left_term_win) == left_term_buf then
    vim.api.nvim_set_current_win(left_term_win)

    if left_previous_buf and vim.api.nvim_buf_is_valid(left_previous_buf) then
      vim.api.nvim_win_set_buf(left_term_win, left_previous_buf)
    end

    left_term_win = nil
    left_previous_buf = nil
    return
  end

  local target = require("utils.windows").leftmost_window(0)

  if not target then
    vim.notify("No non-opencode window available", vim.log.levels.WARN)
    return
  end

  if not left_term_buf or not vim.api.nvim_buf_is_valid(left_term_buf) then
    left_term_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[left_term_buf].bufhidden = "hide"
    vim.api.nvim_buf_call(left_term_buf, function()
      vim.fn.jobstart(vim.o.shell, { term = true })
    end)
    setup_term_keymaps(left_term_buf)
  end

  left_previous_buf = vim.api.nvim_win_get_buf(target)
  left_term_win = target

  vim.api.nvim_set_current_win(target)
  vim.api.nvim_win_set_buf(target, left_term_buf)
  vim.cmd("startinsert")
end

-- Ctrl+T in normal mode.
vim.keymap.set("n", "<C-t>", toggle_left_terminal, {
  desc = "Toggle left-pane terminal",
})

-- Ctrl+T while inside the terminal.
vim.keymap.set("t", "<C-t>", function()
  vim.schedule(toggle_left_terminal)
  return "<C-\\><C-n>"
end, {
  expr = true,
  desc = "Toggle left-pane terminal",
  nowait = true,
})
