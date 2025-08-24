return {
  "ThePrimeagen/refactoring.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("refactoring").setup({
      prompt_func_return_type = {
        go = false,
        java = false,

        cpp = false,
        c = false,
        h = false,
        hpp = false,
        cxx = false,
      },
      prompt_func_param_type = {
        go = false,
        java = false,

        cpp = false,
        c = false,
        h = false,
        hpp = false,
        cxx = false,
      },
      printf_statements = {},
      print_var_statements = {},
      show_success_message = false,
    })

    -- You can also use below = true here to to change the position of the printf
    -- statement (or set two remaps for either one). This remap must be made in normal mode.
    vim.keymap.set("n", "<leader>rp", function()
      require('refactoring').debug.printf({ below = false, show_success_message = false })
    end
    )

    vim.keymap.set({ "x", "n" }, "<leader>rv", function()
      require('refactoring').debug.print_var({ show_success_message = false })
    end)
    -- Supports both visual and normal mode

    vim.keymap.set("n", "<leader>rc", function()
      require('refactoring').debug.cleanup({ show_success_message = false })
    end)
    -- Supports only normal mode
  end,
}
