return {
  "sindrets/diffview.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>gdm",
      function()
        local lib = require("diffview.lib")
        for index = #lib.views, 1, -1 do
          local view = lib.views[index]
          view:close()
          lib.dispose_view(view)
        end

        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes(":DiffviewOpen ", true, false, true),
          "n",
          false
        )
      end,
      desc = "DiffviewOpen",
    },
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

        local api = vim.api
        local leftmost_win
        local leftmost_position
        for _, win in ipairs(api.nvim_tabpage_list_wins(api.nvim_get_current_tabpage())) do
          local position = api.nvim_win_get_position(win)
          if
            not leftmost_position
            or position[2] < leftmost_position[2]
            or (position[2] == leftmost_position[2] and position[1] < leftmost_position[1])
          then
            leftmost_win = win
            leftmost_position = position
          end
        end

        if leftmost_win then
          api.nvim_set_current_win(leftmost_win)
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
