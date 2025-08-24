return {
  "NeogitOrg/neogit",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "sindrets/diffview.nvim",
      opts = {
        file_panel = {
          listing_style = "list",
          win_config = {
            width = 50,
          }
        }
      }
    },
    "tpope/vim-fugitive",
    "folke/snacks.nvim",
  },
  config = function()
    require("neogit").setup({
      use_default_keymaps = false,
      mappings = {
        commit_editor = {},
        commit_editor_I = {},
        rebase_editor = {},
        rebase_editor_I = {},
        finder = {},
        -- Setting any of these to `false` will disable the mapping.
        popup = {
          ["?"] = "HelpPopup",
          ["1"] = "CommitPopup",
        },
        status = {
          ["j"] = "MoveDown",
          ["k"] = "MoveUp",
          ["o"] = "OpenTree",
          ["<C-q>"] = "Close",
          ["<tab>"] = "Toggle",
          ["x"] = "Discard",
          ["s"] = "Stage",
          ["S"] = "StageUnstaged",
          ["<c-s>"] = "StageAll",
          ["u"] = "Unstage",
          ["K"] = "Untrack",
          ["U"] = "UnstageStaged",
          ["Y"] = "YankSelected",
          ["<c-r>"] = "RefreshBuffer",
          ["<cr>"] = "GoToFile",
        },
      },
    })

    vim.keymap.set("n", "<leader>gs", "<cmd>Neogit kind=floating<CR>")
    vim.keymap.set("n", "<leader>gt", "<cmd>Neogit<CR>")
    vim.keymap.set('n', '<leader>gb', '<cmd>Git blame<CR>')
    vim.keymap.set("n", "<leader>gp", "<cmd>Git push<CR>")
    vim.keymap.set("n", "<leader>gu", "<cmd>Git pull --rebase<CR>")
    vim.keymap.set('n', '<leader>gc', ':Git commit -m ""<Left>')
    vim.keymap.set("n", "<leader>go", ":Git push -u origin ");
    vim.keymap.set("n", "<leader>gdm", ":DiffviewOpen ")

    vim.api.nvim_create_autocmd("User", {
      pattern = "FugitiveChanged",
      callback = function()
        require("neogit").dispatch_refresh()
      end,
    })
  end
}
