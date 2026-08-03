local float_term_buf = nil
local float_term_win = nil
local notes_term_buf = nil
local notes_term_win = nil

local function float_dimensions()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  return {
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

local function open_float(buf)
  local dimensions = float_dimensions()

  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = dimensions.width,
    height = dimensions.height,
    row = dimensions.row,
    col = dimensions.col,
    style = "minimal",
    border = "rounded",
  })
end

local function setup_term_keymaps(buf)
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = buf, nowait = true })
  vim.keymap.set("n", "i", "i", { buffer = buf })
  vim.keymap.set("n", "a", "a", { buffer = buf })
end

local function toggle_float_term()
  if float_term_win and vim.api.nvim_win_is_valid(float_term_win) then
    vim.api.nvim_win_close(float_term_win, false)
    float_term_win = nil
    return
  end

  local is_new_buf = not float_term_buf or not vim.api.nvim_buf_is_valid(float_term_buf)
  if is_new_buf then
    float_term_buf = vim.api.nvim_create_buf(false, true)
  end
  local buf = assert(float_term_buf)

  float_term_win = open_float(buf)

  if vim.bo[buf].buftype ~= "terminal" then
    vim.cmd("terminal")
    setup_term_keymaps(buf)
  end

  vim.cmd("startinsert")
end

local function toggle_notes_term()
  if notes_term_win and vim.api.nvim_win_is_valid(notes_term_win) then
    vim.api.nvim_win_close(notes_term_win, false)
    notes_term_win = nil
    return
  end

  local is_new_buf = not notes_term_buf or not vim.api.nvim_buf_is_valid(notes_term_buf)

  if is_new_buf then
    notes_term_buf = vim.api.nvim_create_buf(false, true)
  end
  local buf = assert(notes_term_buf)

  notes_term_win = open_float(buf)

  if vim.bo[buf].buftype ~= "terminal" then
    vim.fn.jobstart({ "nvim", "todo.md" }, {
      term = true,
      cwd = vim.fn.expand("~/vault/obsidian-developer-vault/"),
    })
    setup_term_keymaps(buf)
  end

  vim.cmd("startinsert")
end

return {
  vim.keymap.set({ "n", "t" }, "<C-t>", toggle_float_term),
  vim.keymap.set({ "n", "t" }, "<C-p>", toggle_notes_term, { desc = "Toggle notes terminal" }),
}
