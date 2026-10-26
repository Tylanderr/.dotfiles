return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  keys = {
    { "<leader>tf", "<cmd>Trouble diagnostics filter.severity=vim.diagnostic.severity.ERROR<CR>", desc = "Trouble errors" },
    { "<leader>tt", "<cmd>Trouble diagnostics toggle<CR>", desc = "Toggle Trouble diagnostics" },
    { "tf", function() require("trouble").jump({ skip_groups = true }) end, desc = "Jump to Trouble item" },
    { "tn", function() require("trouble").next({ skip_groups = true, jump = true }) end, desc = "Next Trouble item" },
    { "tp", function() require("trouble").prev({ skip_groups = true, jump = true }) end, desc = "Previous Trouble item" },
  },
  config = function()
    require("trouble").setup({})
  end
}
