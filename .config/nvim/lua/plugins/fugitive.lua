return {
  "tpope/vim-fugitive",
  cmd = "Git",
  keys = {
    { "<leader>gB", "<cmd>Git blame<CR>", desc = "Git blame" },
    { "<leader>gp", "<cmd>Git push<CR>", desc = "Git push" },
    { "<leader>gP", "<cmd>Git push --force<CR>", desc = "Git force push" },
    { "<leader>gu", "<cmd>Git pull --rebase<CR>", desc = "Git pull with rebase" },
    { "<leader>ga", "<cmd>Git commit --amend --no-edit<CR>", desc = "Amend Git commit" },
    { "<leader>gc", ":Git commit -m \"\"<Left>", desc = "Git commit" },
    { "<leader>go", ":Git push -u origin ", desc = "Git push to origin" },
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "FugitiveChanged",
      callback = function()
        if package.loaded.neogit then
          require("neogit").dispatch_refresh()
        end
      end,
    })
  end,
}
