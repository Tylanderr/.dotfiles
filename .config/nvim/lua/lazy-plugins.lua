require("lazy").setup({
  spec = {
    -- Primary plugins
    { import = "plugins.autopairs" },
    { import = "plugins.blink" },
    { import = "plugins.dadbod" },
    { import = "plugins.diffview" },
    { import = "plugins.fff" },
    { import = "plugins.harpoon" },
    { import = "plugins.lspconfig" },
    { import = "plugins.lualine" },
    { import = "plugins.mini" },
    { import = "plugins.noice" },
    { import = "plugins.oil" },
    { import = "plugins.opencode" },
    { import = "plugins.refactoring" },
    { import = "plugins.tmux-navigator" },
    { import = "plugins.tokyonight" },
    { import = "plugins.treesitter" },
    { import = "plugins.trouble" },
    { import = "plugins.vimsleuth" },

    -- Secondary plugins
    { import = "plugins.indent" },
    { import = "plugins.java" },
    { import = "plugins.lazygit" },
    { import = "plugins.markdown" },
    -- { import = "plugins.neogit" },
    { import = "plugins.obsidian" },
    { import = "plugins.todo-comments" },
  },
  ui = {
    border = "rounded"
  },
})
