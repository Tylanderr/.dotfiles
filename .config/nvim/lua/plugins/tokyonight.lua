return {
  "folke/tokyonight.nvim",
  priority = 1000,
  config = function()
    require("tokyonight").setup({
      style = "storm",
      transparent = true,
    })

    vim.cmd.colorscheme("tokyonight")
    vim.cmd.hi("Comment gui=none")
  end
}
