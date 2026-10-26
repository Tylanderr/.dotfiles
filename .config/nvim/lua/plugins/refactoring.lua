return {
  "ThePrimeagen/refactoring.nvim",
  commit = "6784b54587e6d8a6b9ea199318512170ffb9e418",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    { "<leader>rp", function() require("refactoring").debug.printf({ below = false, show_success_message = false }) end, mode = "n", desc = "Insert printf statement" },
    { "<leader>rv", function() require("refactoring").debug.print_var({ show_success_message = false }) end, mode = { "x", "n" }, desc = "Insert print variable" },
    { "<leader>rc", function() require("refactoring").debug.cleanup({ show_success_message = false }) end, mode = "n", desc = "Clean up debug statements" },
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

  end,
}
