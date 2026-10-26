return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  opts = {
    ensure_installed = { "bash", "c", "html", "lua", "luadoc", "markdown", "vim", "vimdoc", "java" },
    auto_install = true,
    highlight = {
      enable = true,
      disable = function(_, bufnr)
        local lines = vim.api.nvim_buf_line_count(bufnr)
        return lines > 20000 or vim.api.nvim_buf_get_offset(bufnr, lines) > 1024 * 1024
      end,
      additional_vim_regex_highlighting = { "ruby" },
    },
    indent = {
      enable = true,
      disable = function(lang, bufnr)
        if lang == "ruby" then
          return true
        end

        local lines = vim.api.nvim_buf_line_count(bufnr)
        return lines > 20000 or vim.api.nvim_buf_get_offset(bufnr, lines) > 1024 * 1024
      end,
    },
  },
  config = function(_, opts)
    ---@diagnostic disable-next-line: missing-fields
    require("nvim-treesitter.configs").setup(opts)
  end,
}
