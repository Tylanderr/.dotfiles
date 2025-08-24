return {
  "folke/trouble.nvim",
  event = "VeryLazy",
  config = function()
    require("trouble").setup({})

    vim.keymap.set("n", "<leader>qf", "<cmd>Trouble diagnostics filter.severity=vim.diagnostic.severity.ERROR<CR>")
    vim.keymap.set("n", "<leader>qt", "<cmd>Trouble diagnostics toggle<CR>")

    vim.keymap.set("n", "qf", function()
      require("trouble").jump({ skip_groups = true })
    end)

    vim.keymap.set("n", "qn", function()
      require("trouble").next({ skip_groups = true, jump = true })
    end)

    vim.keymap.set("n", "qp", function()
      require("trouble").prev({ skip_groups = true, jump = true })
    end)
  end
}
