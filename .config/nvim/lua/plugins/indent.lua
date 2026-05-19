return {
  "lukas-reineke/indent-blankline.nvim",
  event = "VeryLazy",
  main = "ibl",
  ---@module "ibl"
  ---@type ibl.config
  keys = {
    { "<leader>lt", "<cmd>IBLToggle<cr>", desc = "Indent (L)ine (T)oggle" },
  },
  opts = {
    enabled = false,
    exclude = {
      filetypes = {
        "java",
        "typescript",
        "markdown",
        "go",
        "lazy",
        "dbout",
        "mason",
        "opencode",
        "opencode_output",
      },
    },
  },
}
