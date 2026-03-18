return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  keys = {
    { "<leader>gdm", ":DiffviewOpen ", desc = "DiffviewOpen" },
    {
      "<leader>gdo",
      function()
        local lib = require("diffview.lib")
        local view = lib.get_current_view()
        if not view then
          vim.notify("Not in a diffview", vim.log.levels.WARN)
          return
        end

        ---@diagnostic disable-next-line: undefined-field
        local entry = view:infer_cur_file()
        if not entry then
          vim.notify("No file entry found", vim.log.levels.WARN)
          return
        end

        local path = entry.absolute_path
        if not path or path:match("^diffview://") then
          vim.notify("No real file path available", vim.log.levels.WARN)
          return
        end

        vim.cmd("1tabnext")

        local buflist = vim.fn.tabpagebuflist(1)
        for _, bufnr in ipairs(buflist) do
          if vim.api.nvim_buf_get_name(bufnr) == path then
            local wins = vim.api.nvim_tabpage_list_wins(1)
            for _, win in ipairs(wins) do
              if vim.api.nvim_win_get_buf(win) == bufnr then
                vim.fn.win_gotoid(win)
                return
              end
            end
          end
        end

        vim.cmd("edit " .. vim.fn.fnameescape(path))
      end,
      desc = "Open current diffview file in tab 1",
    },
  },
  opts = {
    file_panel = {
      listing_style = "tree",
      tree_options = {
        flatten_dirs = true,
      },
      win_config = {
        width = 50,
      },
    },
  },
}
