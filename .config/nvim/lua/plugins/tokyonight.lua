return {
  'folke/tokyonight.nvim',
  priority = 1000,
  init = function()
    vim.cmd.colorscheme 'tokyonight-storm'
    vim.cmd.hi 'Comment gui=none'
  end,
  config = function()
    local current_transparency = true

    require('tokyonight').setup({
      transparent = current_transparency,
    })
  end
}
