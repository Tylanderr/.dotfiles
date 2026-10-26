local left_term_buf = nil
local left_term_win = nil
local left_previous_buf = nil
local terminal_job = nil

local function setup_term_keymaps(buf)
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", {
    buffer = buf,
    nowait = true,
  })

  vim.keymap.set("n", "i", "i", { buffer = buf })
  vim.keymap.set("n", "a", "a", { buffer = buf })
end

local function ensure_terminal()
  if left_term_buf and vim.api.nvim_buf_is_valid(left_term_buf) and terminal_job then
    local ok, running = pcall(vim.fn.jobwait, { terminal_job }, 0)
    if ok and running and running[1] == -1 then
      return left_term_buf
    end
  end

  left_term_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[left_term_buf].bufhidden = "hide"
  setup_term_keymaps(left_term_buf)

  local buf = left_term_buf
  vim.api.nvim_buf_call(buf, function()
    terminal_job = vim.fn.jobstart(vim.o.shell, {
      term = true,
      on_exit = function(_, _, _)
        vim.schedule(function()
          if left_term_buf == buf then
            terminal_job = nil
          end
        end)
      end,
    })
  end)

  if type(terminal_job) ~= "number" or terminal_job <= 0 then
    terminal_job = nil
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    left_term_buf = nil
    vim.notify("Failed to start terminal shell", vim.log.levels.ERROR)
    return nil
  end

  return buf
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

    local restore_buf = left_previous_buf
    if not restore_buf or not vim.api.nvim_buf_is_valid(restore_buf) then
      restore_buf = vim.api.nvim_create_buf(true, false)
    end

    local ok, err = pcall(vim.api.nvim_win_set_buf, left_term_win, restore_buf)
    if not ok then
      vim.notify("Could not restore previous buffer: " .. tostring(err), vim.log.levels.WARN)
      return
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

  if vim.wo[target].winfixbuf then
    vim.notify("Cannot display terminal in a fixed-buffer window", vim.log.levels.WARN)
    return
  end

  local terminal_buf = ensure_terminal()
  if not terminal_buf then
    return
  end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = terminal_buf })
  local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = terminal_buf })
  if buftype == "" or not modifiable then
    vim.notify("Terminal buffer is not editable", vim.log.levels.WARN)
    return
  end

  local previous_buf = vim.api.nvim_win_get_buf(target)
  local ok, err = pcall(vim.api.nvim_win_set_buf, target, terminal_buf)
  if not ok then
    vim.notify("Could not open terminal: " .. tostring(err), vim.log.levels.WARN)
    return
  end

  left_previous_buf = previous_buf
  left_term_win = target
  vim.api.nvim_set_current_win(target)
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
