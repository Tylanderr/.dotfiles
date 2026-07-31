return {
    "kdheepak/lazygit.nvim",
    lazy = true,
    cmd = {
        "LazyGit",
        "LazyGitConfig",
        "LazyGitCurrentFile",
        "LazyGitFilter",
        "LazyGitFilterCurrentFile",
    },
    dependencies = {
        "nvim-lua/plenary.nvim",
        "tpope/vim-fugitive",
    },

    keys = {
        { "<leader>gs", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        { "<leader>gb", "<cmd>Git blame<CR>", desc = "Blame" }
    }
}
