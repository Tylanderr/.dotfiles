local left_term_buf = nil
local left_term_win = nil
local left_previous_buf = nil

local function setup_term_keymaps(buf)
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    buffer = buf,
    nowait = true,
  })

  vim.keymap.set("n", "i", "i", { buffer = buf })
  vim.keymap.set("n", "a", "a", { buffer = buf })
end

local function ensure_terminal(buf)
  if vim.bo[buf].buftype == "terminal" then
    return
  end

  vim.api.nvim_buf_call(buf, function()
    vim.fn.jobstart(vim.o.shell, {
      term = true,
    })
  end)

  setup_term_keymaps(buf)
end

local function leftmost_non_opencode_window()
  local ok, ui = pcall(require, "opencode.ui.ui")
  local target = nil
  local target_col = math.huge

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local config = vim.api.nvim_win_get_config(win)

    if config.relative == "" then
      local is_opencode = ok and ui.is_opencode_window(win)

      if not is_opencode then
        local position = vim.api.nvim_win_get_position(win)

        if position[2] < target_col then
          target_col = position[2]
          target = win
        end
      end
    end
  end

  return target
end

local function toggle_left_terminal()
  -- Restore the previous buffer when the terminal is already open.
  if left_term_win
      and vim.api.nvim_win_is_valid(left_term_win)
      and left_term_buf
      and vim.api.nvim_win_get_buf(left_term_win) == left_term_buf then
    vim.api.nvim_set_current_win(left_term_win)

    if left_previous_buf and vim.api.nvim_buf_is_valid(left_previous_buf) then
      vim.api.nvim_win_set_buf(left_term_win, left_previous_buf)
    end

    left_term_win = nil
    left_previous_buf = nil
    return
  end

  local target = leftmost_non_opencode_window()

  if not target then
    vim.notify("No non-opencode window available", vim.log.levels.WARN)
    return
  end

  if not left_term_buf or not vim.api.nvim_buf_is_valid(left_term_buf) then
    left_term_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[left_term_buf].bufhidden = "hide"
    ensure_terminal(left_term_buf)
  end

  left_previous_buf = vim.api.nvim_win_get_buf(target)
  left_term_win = target

  vim.api.nvim_set_current_win(target)
  vim.api.nvim_win_set_buf(target, left_term_buf)
  vim.cmd("startinsert")
end

local function toggle_left_terminal_from_terminal_mode()
  local escape = vim.api.nvim_replace_termcodes(
    "<C-\\><C-n>",
    true,
    false,
    true
  )

  vim.api.nvim_feedkeys(escape, "n", false)
  vim.schedule(toggle_left_terminal)
end

-- Ctrl+T in normal mode.
vim.keymap.set("n", "<C-t>", toggle_left_terminal, {
  desc = "Toggle left-pane terminal",
})

-- Ctrl+T while inside the terminal.
vim.keymap.set("t", "<C-t>", toggle_left_terminal_from_terminal_mode, {
  desc = "Toggle left-pane terminal",
  nowait = true,
})

return {}
