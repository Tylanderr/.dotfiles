return {
  'folke/tokyonight.nvim',
  priority = 1000,
  init = function()
    vim.cmd.colorscheme 'tokyonight-storm'
    vim.cmd.hi 'Comment gui=none'
  end,
  config = function()
    local current_scheme = 'tokyonight-storm'
    local current_transparency = true

    require('tokyonight').setup({
      transparent = current_transparency,
    })

    -- Define toggle function
    vim.keymap.set('n', '<leader>ut', function()
      if current_scheme == 'tokyonight-storm' then
        current_scheme = 'tokyonight-day'
        current_transparency = false
      else
        current_scheme = 'tokyonight-storm'
        current_transparency = true
      end
      vim.cmd.colorscheme(current_scheme)
    end, { desc = 'Toggle Tokyonight Theme' })
  end
}
