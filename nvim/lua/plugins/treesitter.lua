local parsers = {
  "angular",
  "bash",
  "c",
  "css",
  "diff",
  "dockerfile",
  "editorconfig",
  "git_config",
  "gitcommit",
  "gitignore",
  "hcl",
  "html",
  "ini",
  "java",
  "javascript",
  "json",
  "lua",
  "luadoc",
  "make",
  "markdown",
  "markdown_inline",
  "nginx",
  "pem",
  "perl",
  "properties",
  "python",
  "regex",
  "ruby",
  "sql",
  "ssh_config",
  "toml",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
}

local install_requested = {}
local supported_parsers = {}
local max_lines = 20000
local max_bytes = 1024 * 1024

local function buffer_is_too_large(bufnr)
  local lines = vim.api.nvim_buf_line_count(bufnr)
  return lines > max_lines or vim.api.nvim_buf_get_offset(bufnr, lines) > max_bytes
end

local function attach_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local filetype = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(filetype)
  if not lang then
    return
  end

  if buffer_is_too_large(bufnr) then
    return
  end

  local ok, parser_loaded = pcall(vim.treesitter.language.add, lang)
  if not ok or not parser_loaded then
    return
  end

  local has_highlights, highlights = pcall(vim.treesitter.query.get, lang, "highlights")
  if has_highlights and highlights then
    vim.treesitter.start(bufnr, lang)
  end

  local has_indents, indent_query = pcall(vim.treesitter.query.get, lang, "indents")
  if filetype ~= "ruby" and has_indents and indent_query then
    vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end

  if filetype == "ruby" then
    vim.bo[bufnr].syntax = "ON"
  end
end

local function request_install(languages)
  local missing = {}
  for _, lang in ipairs(languages) do
    if supported_parsers[lang] and not install_requested[lang] then
      install_requested[lang] = true
      missing[#missing + 1] = lang
    end
  end

  if #missing == 0 then
    return
  end

  require("nvim-treesitter").install(missing):await(function(err)
    if err then
      vim.schedule(function()
        vim.notify("Tree-sitter parser installation failed: " .. tostring(err), vim.log.levels.ERROR)
      end)
      return
    end

    vim.schedule(function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        attach_buffer(bufnr)
      end
    end)
  end)
end

local function attach_or_install(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == "" then
    return
  end

  local lang = vim.treesitter.language.get_lang(filetype)
  if lang then
    local ok, parser_loaded = pcall(vim.treesitter.language.add, lang)
    if not ok or not parser_loaded then
      request_install({ lang })
    end
  end
  attach_buffer(bufnr)
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local treesitter = require("nvim-treesitter")
    treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })

    vim.treesitter.language.register("markdown", { "opencode", "opencode_output" })
    vim.treesitter.language.register("json", "jsonc")

    for _, lang in ipairs(require("nvim-treesitter.config").get_available()) do
      supported_parsers[lang] = true
    end

    local group = vim.api.nvim_create_augroup("UserTreeSitter", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(event)
        vim.schedule(function()
          attach_or_install(event.buf)
        end)
      end,
    })

    request_install(parsers)

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      vim.schedule(function()
        attach_or_install(bufnr)
      end)
    end
  end,
}
