return {
  "folke/noice.nvim",
  event = "VeryLazy",
  opts = {
    routes = {
      {
        filter = {
          event = 'msg_show',
          any = {
            { find = '%d+L, %d+B' },
            { find = '; after #%d+' },
            { find = '; before #%d+' },
            { find = '%d fewer lines' },
            { find = '%d more lines' },
            { find = 'Type  :qa' },

            -- jdtls messages to ignore
            { find = 'Publish Diagnostics' },
            { find = 'Validate documents' },
            { find = 'Building -' },

            -- lua_ls messages to ignore
            { find = 'Diagnosing -' },
            { find = 'Processing -' },

            -- nvim deprecated messages
            { find = 'is deprecated' },
          },
        },
        opts = { skip = true },
      }
    },
    messages = {
      enabled = true
    },
    notify = {
      enabled = true
    },
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
        ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
      },
      progress = {
        enabled = false
      }
    },
    commands = {
      history = {
        view = "popup"
      }
    },
  },
  dependencies = {
    { "MunifTanjim/nui.nvim" },
    {
      "rcarriga/nvim-notify",
      opts = {
        stages = "static",
        render = "minimal",
        minimum_width = 10
      }
    },
  },
  vim.keymap.set("n", "<leader>nd", "<cmd>NoiceDismiss<CR>", { desc = "Dismiss Noice Message" }),
  vim.keymap.set("n", "<leader>nl", "<cmd>NoiceHistory<CR>", { desc = "Show recent noice messages" }),
}
