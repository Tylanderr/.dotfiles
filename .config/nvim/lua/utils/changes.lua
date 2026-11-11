local M = {}

local api = vim.api
local reviews = {}
local models = {}
local resume_bookmarks = {}
local namespaces = {
  diff = api.nvim_create_namespace("AgentChangesDiff"),
  syntax = api.nvim_create_namespace("AgentChangesSyntax"),
  panel = api.nvim_create_namespace("AgentChangesPanel"),
}

local panel_width = 30
local max_syntax_bytes = 1024 * 1024
local max_inline_bytes = 4000
local file_context = 6
local icons = { fold_open = "\u{f47c}", folder_open = "\u{e5fe}" }
local review_window_options = {
  "foldmethod", "foldenable", "foldlevel", "foldcolumn", "foldtext",
  "number", "wrap", "list", "spell", "statuscolumn", "winbar",
}

local close_review, refresh, load_file, open_panel, close_panel

-- Highlights follow diffview.hl's links while keeping this module usable alone.
local function setup_highlights()
  local function link(name, target)
    api.nvim_set_hl(0, name, { link = target, default = true })
  end

  link("AgentChangesAdd", "DiffAdd")
  link("AgentChangesDelete", "DiffDelete")
  link("AgentChangesChange", "DiffChange")
  link("AgentChangesText", "DiffText")
  local title = api.nvim_get_hl(0, { name = "Label", link = false })
  title.bold, title.default = true, true
  api.nvim_set_hl(0, "AgentChangesPanelTitle", title)
  local counter = api.nvim_get_hl(0, { name = "Identifier", link = false })
  counter.bold, counter.default = true, true
  api.nvim_set_hl(0, "AgentChangesPanelCounter", counter)
  link("AgentChangesPanelRootPath", "AgentChangesPanelTitle")
  link("AgentChangesPanelPath", "Comment")
  link("AgentChangesPanelFileName", "Normal")
  link("AgentChangesPanelSelected", "Type")
  link("AgentChangesPanelInsertions", "diffAdded")
  link("AgentChangesPanelDeletions", "diffRemoved")
  link("AgentChangesPanelFolderName", "Directory")
  link("AgentChangesPanelFolderSign", "PreProc")
  link("AgentChangesPanelNonText", "NonText")
  link("AgentChangesPanelStatusAdded", "diffAdded")
  link("AgentChangesPanelStatusModified", "diffChanged")
  link("AgentChangesPanelStatusDeleted", "diffRemoved")
end

setup_highlights()
api.nvim_create_autocmd("ColorScheme", {
  group = api.nvim_create_augroup("AgentChangesHighlights", { clear = true }),
  callback = setup_highlights,
})

local status_highlights = {
  A = "AgentChangesPanelStatusAdded",
  ["?"] = "AgentChangesPanelStatusAdded",
  M = "AgentChangesPanelStatusModified",
  T = "AgentChangesPanelStatusModified",
  U = "AgentChangesPanelStatusModified",
  D = "AgentChangesPanelStatusDeleted",
}

local row_highlights = {
  add = "AgentChangesAdd",
  delete = "AgentChangesDelete",
  change_old = "AgentChangesChange",
  change_new = "AgentChangesChange",
}

local function notify_error(message)
  vim.notify(message, vim.log.levels.WARN)
end

local function is_opencode_window(win)
  local ok, ui = pcall(require, "opencode.ui.ui")
  return ok and ui.is_opencode_window(win)
end

local function leftmost_non_opencode_window(tabpage)
  local target, target_position
  for _, win in ipairs(api.nvim_tabpage_list_wins(tabpage)) do
    local buf = api.nvim_win_get_buf(win)
    local is_panel = vim.bo[buf].filetype == "AgentChangesFiles"
    if api.nvim_win_get_config(win).relative == "" and not is_panel and not is_opencode_window(win) then
      local position = api.nvim_win_get_position(win)
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

local function is_current_review(review)
  return reviews[review.tabpage] == review
    and api.nvim_tabpage_is_valid(review.tabpage)
    and api.nvim_buf_is_valid(review.buf)
    and api.nvim_win_is_valid(review.win)
    and api.nvim_win_get_tabpage(review.win) == review.tabpage
    and api.nvim_win_get_buf(review.win) == review.buf
end

local function without_equalalways(fn)
  local equalalways = vim.o.equalalways
  vim.o.equalalways = false
  local ok, result = pcall(fn)
  vim.o.equalalways = equalalways
  if not ok then
    error(result, 0)
  end
  return result
end

local function run_git(args, cwd, callback, binary)
  local command = { "git" }
  vim.list_extend(command, args)
  vim.system(command, { cwd = cwd, text = not binary }, function(result)
    vim.schedule(function()
      callback(result)
    end)
  end)
end

local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return data
end

-- Changed files and tree ------------------------------------------------------

local function parse_name_status(output)
  local files, by_path = {}, {}
  local fields = vim.split(output, "\0", { plain = true, trimempty = true })
  for i = 1, #fields - 1, 2 do
    local file = {
      path = fields[i + 1],
      status = fields[i]:sub(1, 1),
      additions = 0,
      deletions = 0,
    }
    files[#files + 1] = file
    by_path[file.path] = file
  end
  return files, by_path
end

local function apply_numstat(by_path, output)
  for record in vim.gsplit(output, "\0", { plain = true, trimempty = true }) do
    local added, deleted, path = record:match("^([%d%-]+)\t([%d%-]+)\t(.*)$")
    local file = path and by_path[path]
    if file then
      if added == "-" then
        file.binary = true
      else
        file.additions = tonumber(added) or 0
        file.deletions = tonumber(deleted) or 0
      end
    end
  end
end

local function add_untracked_stats(file, root)
  local contents = read_file(root .. "/" .. file.path)
  if not contents then
    return
  end
  if contents:sub(1, 8000):find("\0", 1, true) then
    file.binary = true
    return
  end
  local _, newline_count = contents:gsub("\n", "")
  file.additions = newline_count + ((#contents > 0 and contents:sub(-1) ~= "\n") and 1 or 0)
end

local function build_entries(files)
  local root = { dirs = {}, files = {} }
  for _, file in ipairs(files) do
    local node
    node = root
    local parts = vim.split(file.path, "/", { plain = true })
    for i = 1, #parts - 1 do
      node.dirs[parts[i]] = node.dirs[parts[i]] or { name = parts[i], dirs = {}, files = {} }
      node = node.dirs[parts[i]]
    end
    node.files[#node.files + 1] = file
  end

  local entries, ordered = {}, {}
  local function walk(node, depth)
    local names = vim.tbl_keys(node.dirs)
    table.sort(names)
    for _, name in ipairs(names) do
      local dir, label = node.dirs[name], name
      while #dir.files == 0 and vim.tbl_count(dir.dirs) == 1 do
        local _, child = next(dir.dirs)
        dir, label = child, label .. "/" .. child.name
      end
      entries[#entries + 1] = { kind = "dir", depth = depth, label = label }
      walk(dir, depth + 1)
    end
    table.sort(node.files, function(a, b)
      return a.path < b.path
    end)
    for _, file in ipairs(node.files) do
      ordered[#ordered + 1] = file
      entries[#entries + 1] = { kind = "file", depth = depth, index = #ordered }
    end
  end
  walk(root, 0)
  return entries, ordered
end

-- Diff model ------------------------------------------------------------------

local function split_lines(text)
  if text == "" then
    return {}
  end
  local lines = vim.split(text, "\n", { plain = true })
  if lines[#lines] == "" then
    lines[#lines] = nil
  end
  return lines
end

local function compute_folds(rows)
  local visible = {}
  for row, info in ipairs(rows) do
    if info.kind ~= "context" then
      for i = math.max(1, row - file_context), math.min(#rows, row + file_context) do
        visible[i] = true
      end
    end
  end
  local folds, start = {}, nil
  for row = 1, #rows + 1 do
    if row <= #rows and not visible[row] then
      start = start or row
    elseif start then
      folds[#folds + 1] = { start, row - 1 }
      start = nil
    end
  end
  return folds
end

local function message_model(lines)
  local rows = {}
  for i = 1, #lines do
    rows[i] = { kind = "message" }
  end
  return { lines = lines, rows = rows, folds = {}, number_width = 1 }
end

local function build_model(old_text, new_text)
  local hunks = vim.text.diff(old_text, new_text, {
    result_type = "indices",
    algorithm = "histogram",
    indent_heuristic = true,
    linematch = 60,
  })
  if not hunks or #hunks == 0 then
    return nil
  end

  local old_lines, new_lines = split_lines(old_text), split_lines(new_text)
  local model = {
    lines = {}, rows = {}, old_rows = {}, new_rows = {},
    old_text = old_text, new_text = new_text,
  }
  local function push(text, info)
    local row = #model.lines + 1
    model.lines[row], model.rows[row] = text or "", info
    if info.new then
      model.new_rows[info.new] = row
    end
    if info.old and info.kind ~= "context" then
      model.old_rows[info.old] = row
    end
    if info.kind ~= "context" and not model.first_change then
      model.first_change = row
    end
    return row
  end

  local old_i, new_i = 1, 1
  local function append_context_until(old_stop)
    while old_i < old_stop do
      push(new_lines[new_i], { kind = "context", old = old_i, new = new_i })
      old_i, new_i = old_i + 1, new_i + 1
    end
  end

  for _, hunk in ipairs(hunks) do
    local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]
    -- For a zero-count side, the start is the line before the insertion point.
    if old_count == 0 then old_start = old_start + 1 end
    if new_count == 0 then new_start = new_start + 1 end
    append_context_until(old_start)

    local paired = math.min(old_count, new_count)
    local first_old_row = #model.lines + 1
    for i = 0, old_count - 1 do
      push(old_lines[old_start + i], {
        kind = i < paired and "change_old" or "delete",
        old = old_start + i,
      })
    end
    for i = 0, new_count - 1 do
      local info = { kind = i < paired and "change_new" or "add", new = new_start + i }
      if i < paired then
        info.pair = first_old_row + i
      end
      push(new_lines[new_start + i], info)
    end
    old_i, new_i = old_start + old_count, new_start + new_count
  end
  append_context_until(#old_lines + 1)

  model.folds = compute_folds(model.rows)
  model.number_width = #tostring(math.max(#old_lines, #new_lines, 1))
  return model
end

local function split_characters(text)
  local chars, offsets = {}, { 0 }
  for char in text:gmatch("[%z\1-\127\192-\255][\128-\191]*") do
    chars[#chars + 1] = char
    offsets[#offsets + 1] = offsets[#offsets] + #char
  end
  return chars, offsets
end

local function simple_inline_ranges(old, new)
  local prefix = 0
  while prefix < #old and prefix < #new and old:byte(prefix + 1) == new:byte(prefix + 1) do
    prefix = prefix + 1
  end
  local suffix = 0
  while suffix < #old - prefix and suffix < #new - prefix
    and old:byte(#old - suffix) == new:byte(#new - suffix)
  do
    suffix = suffix + 1
  end
  return { { prefix, #old - suffix } }, { { prefix, #new - suffix } }
end

local function inline_ranges(old, new)
  if old == "" or new == "" or #old + #new > max_inline_bytes then
    return simple_inline_ranges(old, new)
  end
  local old_chars, old_offsets = split_characters(old)
  local new_chars, new_offsets = split_characters(new)
  local old_text = table.concat(old_chars, "\n") .. "\n"
  local new_text = table.concat(new_chars, "\n") .. "\n"
  local hunks = vim.text.diff(old_text, new_text, { result_type = "indices" })
  local old_ranges, new_ranges = {}, {}
  for _, hunk in ipairs(hunks or {}) do
    if hunk[2] > 0 then
      old_ranges[#old_ranges + 1] = { old_offsets[hunk[1]], old_offsets[hunk[1] + hunk[2]] }
    end
    if hunk[4] > 0 then
      new_ranges[#new_ranges + 1] = { new_offsets[hunk[3]], new_offsets[hunk[3] + hunk[4]] }
    end
  end
  return old_ranges, new_ranges
end

local function apply_syntax(buf, model, path)
  local filetype = vim.filetype.match({ filename = path })
  local lang = filetype and vim.treesitter.language.get_lang(filetype)
  if not lang then return end

  local parser_ok = pcall(vim.treesitter.language.add, lang)
  local query_ok, query = pcall(vim.treesitter.query.get, lang, "highlights")
  if not parser_ok or not query_ok or not query then return end

  local function highlight(text, row_map)
    if text == "" or #text > max_syntax_bytes then return end
    local scratch = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(scratch, 0, -1, false, split_lines(text))
    local ok, trees = pcall(function()
      return vim.treesitter.get_parser(scratch, lang):parse()
    end)
    if ok and trees and trees[1] then
      for capture_id, node, metadata in query:iter_captures(trees[1]:root(), scratch, 0, -1) do
        local capture = query.captures[capture_id]
        if capture and capture:sub(1, 1) ~= "_" and capture ~= "spell" and capture ~= "nospell" and capture ~= "conceal" then
          local start_row, start_col, end_row, end_col = node:range()
          local priority = tonumber(metadata and metadata.priority) or 110
          for source_row = start_row, end_row do
            local display_row = row_map[source_row + 1]
            if display_row then
              local line = model.lines[display_row]
              local col_start = source_row == start_row and start_col or 0
              local col_end = math.min(source_row == end_row and end_col or #line, #line)
              if col_end > col_start then
                api.nvim_buf_set_extmark(buf, namespaces.syntax, display_row - 1, col_start, {
                  end_col = col_end,
                  hl_group = "@" .. capture .. "." .. lang,
                  priority = priority,
                })
              end
            end
          end
        end
      end
    end
    api.nvim_buf_delete(scratch, { force = true })
  end

  highlight(model.new_text, model.new_rows)
  highlight(model.old_text, model.old_rows)
end

local function render_diff(review, model, file, preserve_cursor)
  if not is_current_review(review) then return end
  local buf, win = review.buf, review.win
  local cursor = preserve_cursor and api.nvim_win_get_cursor(win) or nil

  api.nvim_buf_clear_namespace(buf, namespaces.diff, 0, -1)
  api.nvim_buf_clear_namespace(buf, namespaces.syntax, 0, -1)
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, model.lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  models[buf] = model

  for row, info in ipairs(model.rows) do
    local group = row_highlights[info.kind]
    if group then
      api.nvim_buf_set_extmark(buf, namespaces.diff, row - 1, 0, { line_hl_group = group })
    end
    if info.kind == "change_new" and info.pair then
      local old_ranges, new_ranges = inline_ranges(model.lines[info.pair], model.lines[row])
      for _, range in ipairs(old_ranges) do
        if range[2] > range[1] then
          api.nvim_buf_set_extmark(buf, namespaces.diff, info.pair - 1, range[1], {
            end_col = range[2], hl_group = "AgentChangesText", priority = 200,
          })
        end
      end
      for _, range in ipairs(new_ranges) do
        if range[2] > range[1] then
          api.nvim_buf_set_extmark(buf, namespaces.diff, row - 1, range[1], {
            end_col = range[2], hl_group = "AgentChangesText", priority = 200,
          })
        end
      end
    end
  end

  if file then
    apply_syntax(buf, model, file.path)
  end

  vim.wo[win][0].winbar = file and (" WORKING TREE vs HEAD - " .. file.path:gsub("%%", "%%%%")) or ""
  api.nvim_win_call(win, function()
    pcall(vim.cmd, "normal! zE")
    for _, fold in ipairs(model.folds) do
      if fold[2] > fold[1] then
        vim.cmd(("%d,%dfold"):format(fold[1], fold[2]))
      end
    end
    pcall(vim.cmd, "normal! zM")
  end)

  local row = cursor and math.min(cursor[1], math.max(1, #model.lines)) or model.first_change or 1
  api.nvim_win_set_cursor(win, { row, 0 })
  if not cursor and model.first_change then
    api.nvim_win_call(win, function() vim.cmd("normal! zz") end)
  end
end

local function show_message(review, lines)
  review.loaded_path = nil
  render_diff(review, message_model(lines), nil, false)
end

local function get_file_icon(path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then return nil end
  local name = vim.fs.basename(path)
  return devicons.get_icon(name, name:match("%.([^.]+)$"), { default = true })
end

-- Panel -----------------------------------------------------------------------

local function render_panel(review)
  local panel = review.panel
  if not (panel and api.nvim_buf_is_valid(panel.buf) and api.nvim_win_is_valid(panel.win)) then return end

  local lines, marks, current = {}, {}, ""
  local function add(text, group)
    if group and text ~= "" then
      marks[#marks + 1] = { #lines, #current, #current + #text, group }
    end
    current = current .. text
  end
  local function newline()
    lines[#lines + 1] = current
    current = ""
  end

  panel.row_to_file, panel.file_to_row = {}, {}
  add(vim.fn.fnamemodify(review.root or vim.fn.getcwd(), ":~"), "AgentChangesPanelRootPath"); newline()
  add("Help: ", "AgentChangesPanelPath"); add("g?", "AgentChangesPanelCounter"); newline()
  newline()
  add("Changes ", "AgentChangesPanelTitle")
  add(("(%d)"):format(#review.files), "AgentChangesPanelCounter"); newline()

  for _, entry in ipairs(review.entries) do
    if entry.kind == "dir" then
      add("  " .. string.rep(" ", entry.depth * 2))
      add(icons.fold_open, "AgentChangesPanelNonText")
      add(" " .. icons.folder_open .. " ", "AgentChangesPanelFolderSign")
      add(entry.label, "AgentChangesPanelFolderName")
    else
      local file = review.files[entry.index]
      panel.row_to_file[#lines + 1] = entry.index
      panel.file_to_row[entry.index] = #lines + 1
      add(file.status .. " ", status_highlights[file.status])
      add(string.rep(" ", entry.depth * 2 + 2))
      local icon, icon_hl = get_file_icon(file.path)
      if icon then add(icon .. " ", icon_hl) end
      add(vim.fs.basename(file.path), entry.index == review.index and "AgentChangesPanelSelected" or "AgentChangesPanelFileName")
      if file.binary then
        add(" -", "AgentChangesPanelNonText")
      else
        add(" " .. tostring(file.additions), "AgentChangesPanelInsertions")
        add(", ")
        add(tostring(file.deletions), "AgentChangesPanelDeletions")
      end
    end
    newline()
  end

  newline()
  add("Showing changes for:", "AgentChangesPanelTitle"); newline()
  add("HEAD", "AgentChangesPanelPath"); newline()

  vim.bo[panel.buf].modifiable = true
  api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
  vim.bo[panel.buf].modifiable = false
  api.nvim_buf_clear_namespace(panel.buf, namespaces.panel, 0, -1)
  for _, mark in ipairs(marks) do
    api.nvim_buf_set_extmark(panel.buf, namespaces.panel, mark[1], mark[2], {
      end_col = mark[3], hl_group = mark[4],
    })
  end
  local row = panel.file_to_row[review.index]
  if row then api.nvim_win_set_cursor(panel.win, { row, 0 }) end
end

local function map(buf, key, callback, desc, opts)
  vim.keymap.set("n", key, callback, vim.tbl_extend("force", {
    buffer = buf,
    silent = true,
    desc = desc,
  }, opts or {}))
end

local function select_offset(review, offset)
  if #review.files == 0 then return end
  load_file(review, ((review.index or 1) - 1 + offset) % #review.files + 1)
end

local help_lines = {
  "<Tab>/<S-Tab>  next/previous file",
  "<CR>/o/l       open selected file (panel)",
  "]c / [c        next/previous hunk",
  "zo/zc/zR/zM    expand/collapse unchanged context",
  "gf             close review and edit file at cursor line",
  "<leader>b      toggle file panel",
  "<leader>e      focus file panel",
  "r              refresh changes",
  "q              close review",
}

local function set_common_keymaps(review, buf)
  map(buf, "q", function() close_review(review) end, "Close changes review", { nowait = true })
  map(buf, "r", function() refresh(review) end, "Refresh changes review")
  map(buf, "<Tab>", function() select_offset(review, 1) end, "Next changed file")
  map(buf, "<S-Tab>", function() select_offset(review, -1) end, "Previous changed file")
  map(buf, "<leader>b", function()
    if review.panel and api.nvim_win_is_valid(review.panel.win) then
      close_panel(review)
      if api.nvim_win_is_valid(review.win) then api.nvim_set_current_win(review.win) end
    else
      open_panel(review)
    end
  end, "Toggle changed-files panel")
  map(buf, "<leader>e", function()
    open_panel(review)
    if review.panel then api.nvim_set_current_win(review.panel.win) end
  end, "Focus changed-files panel")
  map(buf, "g?", function()
    vim.notify(table.concat(help_lines, "\n"), vim.log.levels.INFO, { title = "Changes review" })
  end, "Changes review help")
end

open_panel = function(review)
  if review.panel and api.nvim_win_is_valid(review.panel.win) then return end
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "AgentChangesFiles"
  vim.bo[buf].modifiable = false

  local win = without_equalalways(function()
    return api.nvim_open_win(buf, false, { split = "left", win = review.win, width = panel_width })
  end)
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.winbar = ""
  wo.cursorline = true
  wo.wrap = false
  wo.list = false
  wo.spell = false
  wo.winfixwidth = true
  pcall(function() wo.winfixbuf = true end)
  api.nvim_win_set_width(win, panel_width)

  review.panel = { buf = buf, win = win, row_to_file = {}, file_to_row = {} }
  set_common_keymaps(review, buf)
  local function select_under_cursor()
    local index = review.panel and review.panel.row_to_file[api.nvim_win_get_cursor(0)[1]]
    if index then load_file(review, index) end
  end
  for _, key in ipairs({ "<CR>", "o", "l", "<2-LeftMouse>" }) do
    map(buf, key, select_under_cursor, "Open diff for selected file")
  end
  api.nvim_create_autocmd("WinClosed", {
    group = review.augroup,
    pattern = tostring(win),
    once = true,
    callback = function()
      if review.panel and review.panel.win == win then review.panel = nil end
    end,
  })
  render_panel(review)
end

close_panel = function(review)
  local panel = review.panel
  review.panel = nil
  if panel and api.nvim_win_is_valid(panel.win) then
    without_equalalways(function()
      pcall(api.nvim_win_close, panel.win, true)
    end)
  end
end

-- Navigation and file loading -------------------------------------------------

local function jump_hunk(review, direction)
  local model = models[review.buf]
  if not model then return end
  local function is_start(row)
    local current = model.rows[row]
    local previous = model.rows[row - 1]
    return current and row_highlights[current.kind] and (not previous or not row_highlights[previous.kind])
  end
  local row = api.nvim_win_get_cursor(review.win)[1] + direction
  while row >= 1 and row <= #model.rows do
    if is_start(row) then
      api.nvim_win_set_cursor(review.win, { row, 0 })
      vim.cmd("normal! zv")
      return
    end
    row = row + direction
  end
end

local function goto_file(review)
  local file = review.files[review.index or 0]
  local model = models[review.buf]
  if not (file and model and review.root) or file.status == "D" then return end
  local target_line
  for row = api.nvim_win_get_cursor(review.win)[1], #model.rows do
    if model.rows[row].new then
      target_line = model.rows[row].new
      break
    end
  end
  local win, path = review.win, review.root .. "/" .. file.path
  close_review(review)
  if not api.nvim_win_is_valid(win) then return end
  api.nvim_set_current_win(win)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if target_line then pcall(api.nvim_win_set_cursor, win, { target_line, 0 }) end
end

load_file = function(review, index)
  local file = review.files[index]
  if not file or not is_current_review(review) then return end
  local preserve_cursor = review.loaded_path == file.path
  review.index = index
  review.file_request = review.file_request + 1
  local request = review.file_request
  render_panel(review)

  local function finish(old_text)
    if review.file_request ~= request or not is_current_review(review) then return end
    local model
    if file.binary then
      model = message_model({ ("Binary file %s differs."):format(file.path) })
    else
      local new_text = ""
      if file.status ~= "D" then
        new_text = read_file(review.root .. "/" .. file.path) or ""
      end
      model = build_model(old_text, new_text)
        or message_model({ ("No textual changes in %s (mode change or submodule?)."):format(file.path) })
    end
    render_diff(review, model, file, preserve_cursor)
    if review.resume_bookmark and review.resume_bookmark.selected_path == file.path then
      local cursor = review.resume_bookmark.cursor
      if cursor then
        local row = math.max(1, math.min(cursor[1], #model.lines))
        local col = math.max(0, math.min(cursor[2], #(model.lines[row] or "")))
        api.nvim_win_set_cursor(review.win, { row, col })
        api.nvim_win_call(review.win, function() vim.cmd("normal! zv") end)
      end
      review.resume_bookmark = nil
    end
    review.loaded_path = file.path
  end

  if file.binary or file.status == "A" or file.status == "?" then
    finish("")
    return
  end
  run_git({ "cat-file", "-p", "HEAD:" .. file.path }, review.root, function(result)
    finish(result.code == 0 and (result.stdout or "") or "")
  end, true)
end

-- Review lifecycle ------------------------------------------------------------

close_review = function(review)
  if reviews[review.tabpage] ~= review then return end
  reviews[review.tabpage] = nil
  review.request = review.request + 1
  review.file_request = review.file_request + 1
  pcall(api.nvim_del_augroup_by_id, review.augroup)
  close_panel(review)
  if api.nvim_win_is_valid(review.win) then
    if api.nvim_win_get_buf(review.win) == review.buf then
      local previous = api.nvim_buf_is_valid(review.previous_buf) and review.previous_buf
        or api.nvim_create_buf(true, false)
      api.nvim_win_set_buf(review.win, previous)
    end
    for name, value in pairs(review.saved_window_options) do
      pcall(function() vim.wo[review.win][name] = value end)
    end
  end
end

refresh = function(review)
  review.request = review.request + 1
  local request = review.request
  local function is_latest()
    return review.request == request and is_current_review(review)
  end

  local selected = review.files[review.index or 0]
  local selected_path = selected and selected.path
    or (review.resume_bookmark and review.resume_bookmark.selected_path)
  local cwd = vim.fn.getcwd()
  local source = api.nvim_buf_is_valid(review.previous_buf) and api.nvim_buf_get_name(review.previous_buf) or ""
  if source ~= "" then
    local source_dir = vim.fn.fnamemodify(source, ":p:h")
    if vim.fn.isdirectory(source_dir) == 1 then cwd = source_dir end
  end

  run_git({ "rev-parse", "--show-toplevel" }, cwd, function(root_result)
    if not is_latest() then return end
    local root = vim.trim(root_result.stdout or "")
    if root_result.code ~= 0 or root == "" then
      return show_message(review, { "Not inside a Git repository." })
    end
    review.root = root

    local diff_args = { "diff", "--no-ext-diff", "--no-textconv", "--no-renames", "-z" }
    local git_args = vim.list_extend(vim.deepcopy(diff_args), { "--name-status", "HEAD", "--" })
    run_git(git_args, root, function(status_result)
      if not is_latest() then return end
      if status_result.code ~= 0 then
        return show_message(review, { "Could not compare working tree with HEAD.", vim.trim(status_result.stderr or "") })
      end

      run_git(vim.list_extend(vim.deepcopy(diff_args), { "--numstat", "HEAD", "--" }), root, function(numstat_result)
        if not is_latest() then return end
        run_git({ "ls-files", "--others", "--exclude-standard", "-z" }, root, function(untracked_result)
          if not is_latest() then return end
          if untracked_result.code ~= 0 then
            return show_message(review, { "Could not list untracked files.", vim.trim(untracked_result.stderr or "") })
          end

          local files, by_path = parse_name_status(status_result.stdout or "")
          apply_numstat(by_path, numstat_result.stdout or "")
          for path in vim.gsplit(untracked_result.stdout or "", "\0", { plain = true, trimempty = true }) do
            if not by_path[path] then
              local file = { path = path, status = "?", additions = 0, deletions = 0 }
              add_untracked_stats(file, root)
              files[#files + 1] = file
            end
          end

          review.entries, review.files = build_entries(files)
          if #review.files == 0 then
            review.index = nil
            render_panel(review)
            return show_message(review, { "No uncommitted changes against HEAD." })
          end
          local index = 1
          for i, file in ipairs(review.files) do
            if file.path == selected_path then index = i; break end
          end
          load_file(review, index)
        end)
      end)
    end)
  end)
end

local function create_review(tabpage, win, opts)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "AgentChanges" -- don't run diff syntax over source comments
  vim.bo[buf].modifiable = false
  api.nvim_buf_set_name(buf, ("AgentChanges://%d/%d"):format(tabpage, buf))

  local review = {
    tabpage = tabpage,
    win = win,
    buf = buf,
    previous_buf = api.nvim_win_get_buf(win),
    request = 0,
    file_request = 0,
    files = {},
    entries = {},
    augroup = api.nvim_create_augroup(("AgentChanges_%d"):format(tabpage), { clear = true }),
    saved_window_options = {},
    resume_bookmark = opts,
  }
  for _, name in ipairs(review_window_options) do
    review.saved_window_options[name] = vim.wo[win][name]
  end
  reviews[tabpage] = review
  api.nvim_win_set_buf(win, buf)

  local wo = vim.wo[win]
  wo.foldmethod = "manual"
  wo.foldenable = true
  wo.foldlevel = 0
  wo.foldcolumn = "1"
  wo.foldtext = "foldtext()"
  wo.number = true
  wo.wrap = false
  wo.list = false
  wo.spell = false
  wo.statuscolumn = "%!v:lua.require'utils.changes'.statuscolumn()"

  set_common_keymaps(review, buf)
  map(buf, "]c", function() jump_hunk(review, 1) end, "Next hunk")
  map(buf, "[c", function() jump_hunk(review, -1) end, "Previous hunk")
  map(buf, "gf", function() goto_file(review) end, "Open file at cursor line")

  local function schedule_close()
    vim.schedule(function() close_review(review) end)
  end
  api.nvim_create_autocmd("WinClosed", {
    group = review.augroup, pattern = tostring(win), callback = schedule_close,
  })
  api.nvim_create_autocmd("BufWinLeave", {
    group = review.augroup, buffer = buf, callback = schedule_close,
  })
  api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function() models[buf] = nil end,
  })

  if not opts or opts.panel_open ~= false then
    open_panel(review)
  end
  show_message(review, { "Loading changes…" })
  refresh(review)
end

function M.statuscolumn()
  local win = vim.g.statusline_winid
  local model = models[api.nvim_win_get_buf(win)]
  local info = model and model.rows[vim.v.lnum]
  local width = model and model.number_width or 1
  if not info or vim.v.virtnum ~= 0 then
    return "%C" .. string.rep(" ", width * 2 + 4)
  end

  local function number(value)
    return value and ("%" .. width .. "d"):format(value) or string.rep(" ", width)
  end
  local sign, group = " ", "LineNr"
  if info.new and info.kind ~= "context" then
    sign, group = "+", "AgentChangesPanelInsertions"
  elseif info.old and info.kind ~= "context" then
    sign, group = "-", "AgentChangesPanelDeletions"
  end
  return ("%%C%%#LineNr#%s %s %%#%s#%s%%* "):format(number(info.old), number(info.new), group, sign)
end

function M.open_current_file()
  local current_buf = api.nvim_get_current_buf()
  local filetype = vim.bo[current_buf].filetype
  if filetype ~= "AgentChanges" and filetype ~= "AgentChangesFiles" then
    return false
  end

  local review = reviews[api.nvim_get_current_tabpage()]
  local file = review and review.files[review.index or 0]
  if not (review and file and review.root and is_current_review(review)) then
    notify_error("No changed file selected")
    return true
  end

  local path = review.root .. "/" .. file.path
  resume_bookmarks[vim.fs.normalize(path)] = {
    tabpage = review.tabpage,
    win = review.win,
    selected_path = file.path,
    cursor = api.nvim_win_get_cursor(review.win),
    panel_open = review.panel ~= nil and api.nvim_win_is_valid(review.panel.win),
  }
  close_review(review)
  vim.cmd("1tabnext")

  local target, target_position
  for _, win in ipairs(api.nvim_tabpage_list_wins(api.nvim_get_current_tabpage())) do
    local position = api.nvim_win_get_position(win)
    if not target_position
      or position[2] < target_position[2]
      or (position[2] == target_position[2] and position[1] < target_position[1])
    then
      target, target_position = win, position
    end
  end
  if target then
    api.nvim_set_current_win(target)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return true
end

function M.toggle()
  local tabpage = api.nvim_get_current_tabpage()
  local review = reviews[tabpage]
  if review then
    if is_current_review(review) then
      refresh(review)
      api.nvim_set_current_win(review.win)
      return
    end
    close_review(review)
  end

  local current_path = api.nvim_buf_get_name(api.nvim_get_current_buf())
  local bookmark_key = current_path ~= "" and vim.fs.normalize(current_path)
  local bookmark = bookmark_key and resume_bookmarks[bookmark_key]
  if bookmark then
    resume_bookmarks[bookmark_key] = nil
    local restore_tabpage = bookmark.tabpage
    if not api.nvim_tabpage_is_valid(restore_tabpage) then
      restore_tabpage = api.nvim_get_current_tabpage()
      bookmark.win = nil
    end
    api.nvim_set_current_tabpage(restore_tabpage)
    local win = bookmark.win
    if not (win and api.nvim_win_is_valid(win) and api.nvim_win_get_tabpage(win) == restore_tabpage) then
      win = leftmost_non_opencode_window(restore_tabpage)
    end
    if not win then
      notify_error("No window available to restore the changes review")
      return
    end
    create_review(restore_tabpage, win, bookmark)
    return
  end

  local win = leftmost_non_opencode_window(tabpage)
  if not win then
    notify_error("No non-opencode window available")
    return
  end
  create_review(tabpage, win)
end

return M
