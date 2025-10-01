return {
  "stevearc/oil.nvim",
  dependencies = {
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    require("oil").setup({
      default_file_explorer = true,
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        -- overwrite default keymaps with custom functions
        ["<C-s>"] = false,
        ["<C-h>"] = false,
        ["<C-j>"] = false,
        ["<C-k>"] = false,
        ["<C-l>"] = false,
        ["<C-c>"] = false,
        ["<C-t>"] = false,
        ["<C-v>"] = { "actions.select", opts = { vertical = true } },
        ["q"] = { "actions.close", nowait = true },
      },
      float = {
        padding = 2,
        max_width = 110,
        max_height = 35,
        border = "rounded",
        win_options = {
          winblend = 1
        },
        override = function(conf)
          local ui = vim.api.nvim_list_uis()[1]
          if not ui then
            return conf
          end

          local width = math.floor(ui.width * 0.4)
          local height = math.floor(ui.height * 0.5)

          conf.width = math.min(width, conf.max_width or width)
          conf.height = math.min(height, conf.max_height or height)

          conf.row = math.floor((ui.height - conf.height) / 2)
          conf.col = math.floor((ui.width - conf.width) / 2)

          return conf
        end
      }
    })
    vim.keymap.set("n", "-", require("oil").open_float)
    vim.keymap.set("n", "<leader>-", "<cmd>Oil<CR>")
  end,
}
