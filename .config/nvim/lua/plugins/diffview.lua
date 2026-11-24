return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewFileHistory",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
  },
  opts = {
    file_panel = {
      listing_style = "tree",
      tree_options = {
        flatten_dirs = true,
      },
      win_config = {
        width = 50,
      }
    },
    hooks = {
      view_opened = function(view)
        vim.schedule(function()
          if view:is_cur_tabpage() and view.cur_layout then
            view.cur_layout:get_main_win():focus()
          end
        end)
      end,
    },
  },

  keys = {
    { "<c-u>", function() require("diffview.actions").scroll_view(-0.25)() end, ft = { "DiffviewFiles", "DiffviewFileHistory" }, desc = "Scroll the view up", },
    { "<c-d>", function() require("diffview.actions").scroll_view(0.25)() end, ft = { "DiffviewFiles", "DiffviewFileHistory" }, desc = "Scroll the view down", },
    { "<leader>gdu", function() require("utils.changes").toggle() end, desc = "Toggle left-pane unified diff of the current agent unit", },
    { "<leader>gdr", function() require("utils.changes").start_unit() end, desc = "Reset current unit diff", },

    { "<leader>gdm", function()
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
  }
}
