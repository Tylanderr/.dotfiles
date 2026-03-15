return {
  "nvim-lualine/lualine.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require('lualine').setup {
      options = {
        theme = 'tokyonight'
      },
      sections = {
        lualine_b = {
          'branch'
        },
        lualine_c = {
          {
            'filename',
            path = 1
          }
        },
        lualine_x = {
          {
            'encoding'
          }
        }
      }
    }
  end
}
