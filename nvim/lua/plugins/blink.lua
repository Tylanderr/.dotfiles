return {
  "saghen/blink.cmp",
  lazy = false,
  dependencies = {
    "rafamadriz/friendly-snippets",
  },

  version = "1.*",

  ---@module "blink.cmp"
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      ["<c-g>"] = { "show_documentation", "hide_documentation", "fallback" },
      ["<space>"] = false,
    },

    completion = {
      menu = {
        border = "rounded",
      },
      documentation = {
        auto_show = false,
        window = { border = "rounded" },
      },
    },

    cmdline = {
      keymap = { preset = "inherit" },
      completion = {
        menu = { auto_show = true },
        ghost_text = { enabled = false },
      },
    },

  },
  opts_extend = { "sources.default" },
  config = function(_, opts)
    require("blink.cmp").setup(opts)

    vim.keymap.set("n", "<leader>cm", function()
      local cfg = require("blink.cmp.config").completion.menu
      cfg.auto_show = not cfg.auto_show
      local state = cfg.auto_show and "shown" or "hidden"
      vim.notify("blink.cmp menu auto_show " .. state, vim.log.levels.INFO)
    end, { desc = "Toggle blink.cmp menu auto_show" })
  end,
}
