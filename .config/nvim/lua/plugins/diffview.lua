return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  opts = {
    file_panel = {
      listing_style = "tree",
      tree_options = {
        flatten_dirs = true,
      },
      win_config = {
        width = 50,
      }
    }
  },

  vim.keymap.set("n", "<leader>gdm", ":DiffviewOpen ")
}
