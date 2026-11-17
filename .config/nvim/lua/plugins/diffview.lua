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
    { "<leader>gdo", function()
        if require("utils.changes").open_current_file() then
          return
        end

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

        local api = vim.api
        local layout = view.cur_layout
        local source_win = api.nvim_get_current_win()
        local a, b = layout and layout.a, layout and layout.b
        if a and b and source_win ~= a.id and source_win ~= b.id and api.nvim_win_is_valid(b.id) then
          source_win = b.id
        end
        local cursor = api.nvim_win_get_cursor(source_win)
        local line, col = cursor[1], cursor[2]

        if a and b and source_win == a.id and api.nvim_win_is_valid(a.id) and api.nvim_win_is_valid(b.id) then
          local function buffer_text(win)
            return table.concat(api.nvim_buf_get_lines(api.nvim_win_get_buf(win), 0, -1, false), "\n") .. "\n"
          end
          local ok, hunks = pcall(vim.text.diff, buffer_text(a.id), buffer_text(b.id), { result_type = "indices" })
          if ok then
            local offset = 0
            for _, hunk in ipairs(hunks or {}) do
              local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]
              if old_count == 0 then
                if line <= old_start then break end
                offset = offset + new_count
              elseif line < old_start then
                break
              elseif line < old_start + old_count then
                line = new_count > 0 and new_start + math.min(line - old_start, new_count - 1) or new_start + 1
                col = 0
                offset = 0
                break
              else
                offset = offset + new_count - old_count
              end
            end
            line = line + offset
          end
        end

        vim.cmd("1tabnext")

        local leftmost_win = require("utils.windows").leftmost_window(0, { include_opencode = true })

        if leftmost_win then
          api.nvim_set_current_win(leftmost_win)
        end

        vim.cmd("edit " .. vim.fn.fnameescape(path))
        line = math.max(1, math.min(line, api.nvim_buf_line_count(0)))
        local text = api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
        pcall(api.nvim_win_set_cursor, 0, { line, math.min(col, #text) })
        vim.cmd("normal! zvzz")
      end,
      desc = "Open current diffview file in tab 1",
    }
  }
}
