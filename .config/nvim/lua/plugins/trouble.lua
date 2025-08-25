return {
  "folke/trouble.nvim",
  event = "VeryLazy",
  config = function()
    require("trouble").setup({})

    vim.keymap.set("n", "<leader>tf", "<cmd>Trouble diagnostics filter.severity=vim.diagnostic.severity.ERROR<CR>")
    vim.keymap.set("n", "<leader>tt", "<cmd>Trouble diagnostics toggle<CR>")

    vim.keymap.set("n", "tf", function()
      require("trouble").jump({ skip_groups = true })
    end)

    vim.keymap.set("n", "tn", function()
      require("trouble").next({ skip_groups = true, jump = true })
    end)

    vim.keymap.set("n", "tp", function()
      require("trouble").prev({ skip_groups = true, jump = true })
    end)
  end
}
