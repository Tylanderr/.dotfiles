return {
  'folke/todo-comments.nvim',
  event = 'VeryLazy',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = { signs = false },
  vim.keymap.set("n", "<leader>td",
    function() require("fzf-lua").grep({ search = "TODO|FIXME|XXX|HACK", no_esc = true }) end)
}
