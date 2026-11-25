local left_term_buf = nil
local left_term_win = nil
local left_previous_buf = nil
local left_previous_bufhidden = nil
local left_previous_view = nil
local left_previous_win = nil
local left_restore_group = vim.api.nvim_create_augroup("LeftTerminalRestore", { clear = true })

local function changes_review(action, buf)
  local ok, changes = pcall(require, "utils.changes")
  if ok and changes[action] then
    changes[action](buf)
  end
end

local function clear_terminal_restore(abandon_review)
  if left_previous_buf and vim.api.nvim_buf_is_valid(left_previous_buf) then
    if left_previous_bufhidden ~= nil then
      vim.bo[left_previous_buf].bufhidden = left_previous_bufhidden
    end
    if abandon_review then
      changes_review("abandon", left_previous_buf)
    end
  end

  left_term_win = nil
  left_previous_buf = nil
  left_previous_bufhidden = nil
  left_previous_view = nil
  left_previous_win = nil
end

local function schedule_stale_restore_check()
  vim.schedule(function()
    if left_term_win and vim.api.nvim_win_is_valid(left_term_win)
      and vim.api.nvim_win_get_buf(left_term_win) ~= left_term_buf then
      clear_terminal_restore(true)
    end
  end)
end

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

    local previous_buf_valid = left_previous_buf and vim.api.nvim_buf_is_valid(left_previous_buf)
    local restore_buf = previous_buf_valid and left_previous_buf or nil
    if not restore_buf then
      restore_buf = vim.api.nvim_create_buf(true, false)
    end

    vim.api.nvim_win_set_buf(left_term_win, restore_buf)
    if previous_buf_valid and left_previous_bufhidden ~= nil then
      vim.bo[restore_buf].bufhidden = left_previous_bufhidden
    end
    changes_review("resume", restore_buf)

    if left_previous_view then
      pcall(vim.api.nvim_win_call, left_term_win, function()
        vim.fn.winrestview(left_previous_view)
      end)
    end

    local previous_win = left_previous_win
    if previous_win and vim.api.nvim_win_is_valid(previous_win) then
      pcall(vim.api.nvim_set_current_win, previous_win)
    end

    clear_terminal_restore(false)
    return
  end

  if left_term_win then
    clear_terminal_restore(true)
  end

  local previous_win = vim.api.nvim_get_current_win()
  local target = require("utils.windows").leftmost_window(0, { exclude_winfixbuf = true })

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
    vim.api.nvim_create_autocmd("BufWinLeave", {
      group = left_restore_group,
      buffer = left_term_buf,
      callback = schedule_stale_restore_check,
    })
  end

  left_previous_buf = vim.api.nvim_win_get_buf(target)
  left_previous_bufhidden = vim.bo[left_previous_buf].bufhidden
  left_previous_view = vim.api.nvim_win_call(target, vim.fn.winsaveview)
  left_previous_win = previous_win
  left_term_win = target

  changes_review("suspend", left_previous_buf)
  vim.bo[left_previous_buf].bufhidden = "hide"
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

vim.api.nvim_create_autocmd("WinClosed", {
  group = left_restore_group,
  callback = function(event)
    if left_term_win and event.match == tostring(left_term_win) then
      vim.schedule(function()
        if left_term_win and not vim.api.nvim_win_is_valid(left_term_win) then
          clear_terminal_restore(true)
        end
      end)
    end
  end,
})
