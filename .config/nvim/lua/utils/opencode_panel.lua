local M = {}

local api = vim.api
local background_open_key = "_dotfiles_opencode_background_open"
local background_preparation_depth = 0
local setup_complete = false
local pending_toggle

---Create the side-panel splits without entering either window.
---@param windows OpencodeWindowState
function M.create_background_split_windows(windows)
  local position = windows.position
  if position ~= "left" and position ~= "right" then
    error("Background OpenCode panels support only left/right split positions")
  end

  local previous_windows = {
    input_win = windows.input_win,
    output_win = windows.output_win,
    tab_strip_win = windows.tab_strip_win,
  }
  local existing_windows = {}
  for _, win in ipairs(api.nvim_list_wins()) do
    existing_windows[win] = true
  end

  local ok, err = xpcall(function()
    windows.output_win = api.nvim_open_win(windows.output_buf, false, {
      split = position,
      vertical = true,
      win = -1,
    })

    windows.input_win = api.nvim_open_win(windows.input_buf, false, {
      split = require("opencode.config").ui.input_position == "top" and "above" or "below",
      win = windows.output_win,
    })

    windows.tab_strip_win = require("opencode.ui.session_tab_strip").create_window(windows)
  end, debug.traceback)

  if not ok then
    for _, win in ipairs(api.nvim_list_wins()) do
      if not existing_windows[win] then
        pcall(api.nvim_win_close, win, true)
      end
    end
    for _, key in ipairs({ "tab_strip_win", "input_win", "output_win" }) do
      local old_win = previous_windows[key]
      windows[key] = old_win
    end
    error(err, 0)
  end

  return {
    input_win = windows.input_win,
    output_win = windows.output_win,
    tab_strip_win = windows.tab_strip_win,
  }
end

local function validate_background_layout(config)
  if config.ui.position ~= "left" and config.ui.position ~= "right" then
    error("Background OpenCode toggling supports only left/right split positions")
  end
  if config.ui.input_position ~= "top" and config.ui.input_position ~= "bottom" then
    error("Background OpenCode toggling supports only top/bottom input positions")
  end
end

---Install narrowly scoped adapters for background opening.
function M.setup()
  if setup_complete then
    return
  end

  local config = require("opencode.config")
  local state = require("opencode.state")
  local ui = require("opencode.ui.ui")

  local original_prepare_windows = ui.prepare_windows
  ui.prepare_windows = function(action, opts)
    if not opts or opts[background_open_key] ~= true then
      return original_prepare_windows(action, opts)
    end

    validate_background_layout(config)
    local background_opts = vim.tbl_extend("force", {}, opts)
    background_opts[background_open_key] = nil
    background_opts.focus = nil
    background_opts.start_insert = false

    local previous_depth = background_preparation_depth
    background_preparation_depth = previous_depth + 1
    local ok, result = xpcall(function()
      return original_prepare_windows(action, background_opts)
    end, debug.traceback)
    background_preparation_depth = previous_depth

    if not ok then
      error(result, 0)
    end
    return result
  end

  local original_create_split_windows = ui.create_split_windows
  ui.create_split_windows = function(windows, ...)
    if background_preparation_depth > 0 then
      return M.create_background_split_windows(windows)
    end
    return original_create_split_windows(windows, ...)
  end

  local original_set_panel_focused = state.ui.set_panel_focused
  state.ui.set_panel_focused = function()
    return original_set_panel_focused(ui.is_opencode_focused())
  end

  setup_complete = true
end

local function open_in_background(action, new_session)
  local Promise = require("opencode.promise")
  local config = require("opencode.config")
  local session_runtime = require("opencode.services.session_runtime")
  local state = require("opencode.state")
  local ui = require("opencode.ui.ui")

  validate_background_layout(config)

  return Promise.async(function()
    if action == "migrate" and state.windows then
      ui.teardown_visible_windows(state.windows)
    end

    return session_runtime.open({
      new_session = new_session,
      open_action = action == "restore_hidden" and "restore_hidden" or "create_fresh",
      [background_open_key] = true,
      start_insert = false,
    }):await()
  end)()
end

---Toggle OpenCode using native visibility decisions, preserving editor focus while opening.
---@param new_session? boolean
function M.toggle(new_session)
  if pending_toggle then
    if not pending_toggle._resolved then
      return pending_toggle
    end
    pending_toggle = nil
  end

  local state = require("opencode.state")
  local config = require("opencode.config")
  local decision = state.ui.resolve_toggle_decision(config.ui.persist_state, state.display_route ~= nil)
  local action = decision.action
  local is_new_session = new_session == true

  if action ~= "open" and action ~= "restore_hidden" and action ~= "migrate" then
    return require("opencode.api").toggle(new_session)
  end

  local ok, opening = pcall(open_in_background, action, is_new_session)
  if not ok then
    pending_toggle = nil
    return require("opencode.promise").new():reject(opening)
  end

  pending_toggle = opening
  opening:finally(function()
    if pending_toggle == opening then
      pending_toggle = nil
    end
  end)
  return opening
end

return M
