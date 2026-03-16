return {
  "lukas-reineke/indent-blankline.nvim",
  event = "VeryLazy",
  main = "ibl",
  ---@module "ibl"
  ---@type ibl.config
  opts = {
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
