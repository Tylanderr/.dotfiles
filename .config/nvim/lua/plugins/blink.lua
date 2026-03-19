return {
  'saghen/blink.cmp',
  lazy = false,
  dependencies = {
    'rafamadriz/friendly-snippets',
  },

  version = '1.*',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      preset = 'default',
      ['<c-g>'] = { 'show_documentation', 'hide_documentation', 'fallback' },
      ['<space>'] = false,
    },

    appearance = {
      nerd_font_variant = 'mono'
    },

    completion = {
      documentation = { auto_show = false },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
    },

    cmdline = {
      keymap = { preset = 'inherit' },
      completion = { menu = { auto_show = true } },
    },

    fuzzy = { implementation = "prefer_rust_with_warning" }
  },
  opts_extend = { "sources.default" },
  config = function(_, opts)
    require('blink.cmp').setup(opts)

    vim.keymap.set('n', '<leader>cm', function()
      local cfg = require('blink.cmp.config').completion.menu
      cfg.auto_show = not cfg.auto_show
      local state = cfg.auto_show and 'shown' or 'hidden'
      vim.notify('blink.cmp menu auto_show ' .. state, vim.log.levels.INFO)
    end, { desc = 'Toggle blink.cmp menu auto_show' })
  end,
}
