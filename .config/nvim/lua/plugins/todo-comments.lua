return {
  'folke/todo-comments.nvim',
  event = 'VeryLazy',
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = { signs = false },
  vim.keymap.set("n", "<leader>td", function() Snacks.picker.todo_comments() end)
}
