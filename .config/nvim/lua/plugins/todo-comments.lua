return {
  "folke/todo-comments.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = { signs = false },
  keys = {
    {
      "<leader>td",
      function()
        require("fff").live_grep({
          query = "TODO|FIXME|NOTE|HACK|WARN",
          grep = { modes = { "regex" } },
        })
      end,
      desc = "Search TODO comments",
    },
  },
}
