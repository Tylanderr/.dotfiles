return {
  "lukas-reineke/indent-blankline.nvim",
  event = "VeryLazy",
  main = "ibl",
  keys = {
    { "<leader>lt", "<cmd>IBLToggle<cr>", desc = "Indent (L)ine (T)oggle" },
  },
  ---@module "ibl"
  ---@type ibl.config
  opts = {
    enabled = false,
    exclude = {
      filetypes = {
        "markdown",
        "lazy",
        "dbout",
        "mason",
        "opencode",
        "opencode_output",
      },
    },
  },
}
