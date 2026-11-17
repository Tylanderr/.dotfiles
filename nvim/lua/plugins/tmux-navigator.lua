return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
  },
  keys = {
    { "<C-Space>h", "<cmd>TmuxNavigateLeft<cr>",  mode = { "n", "t" }, desc = "Navigate pane left" },
    { "<C-Space>j", "<cmd>TmuxNavigateDown<cr>",  mode = { "n", "t" }, desc = "Navigate pane down" },
    { "<C-Space>k", "<cmd>TmuxNavigateUp<cr>",    mode = { "n", "t" }, desc = "Navigate pane up" },
    { "<C-Space>l", "<cmd>TmuxNavigateRight<cr>", mode = { "n", "t" }, desc = "Navigate pane right" },
  },
  init = function()
    -- Disable the default C-hjkl bindings
    vim.g.tmux_navigator_no_mappings = 1
  end,
}
