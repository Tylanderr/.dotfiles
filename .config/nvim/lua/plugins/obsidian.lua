return {
  "epwalsh/obsidian.nvim",
  version = "*",
  event = "VeryLazy",
  ft = "markdown",
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = {
      {
        name = "obsidian-developer-vault",
        path = "~/vault/obsidian-developer-vault",
      },
    },
    ui = {
      enable = false,
      checkboxes = {
        [" "] = { order = 1, char = " ", hl_group = "ObsidianTodo" },
        ["x"] = { order = 2, char = "x", hl_group = "ObsidianDone" },
      },
    },
  },
}
