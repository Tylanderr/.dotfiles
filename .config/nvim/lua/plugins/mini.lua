return {
  {
    "nvim-mini/mini.nvim",
    lazy = false,
    config = function()
      require("mini.ai").setup { n_lines = 500 }
      require("mini.surround").setup()
      require("mini.extra").setup()
      require("mini.pick").setup({
        mappings = {
          choose_in_split = "",
          choose_in_tabpage = "",
          choose_in_vsplit = "",
          scroll_down = "",
          scroll_left = "",
          scroll_right = "",
          move_start = "",
          paste = "",
          send_to_quickfix = {
            char = "<C-q>",
            func = function()
              local pick = require("mini.pick")
              local matches = pick.get_picker_matches() or {}
              local marked = matches.marked or {}
              local items = #marked > 0 and marked or (matches.all or {})

              if #items == 0 then
                vim.notify("No matches to send to quickfix", vim.log.levels.WARN)
                return false
              end

              pick.default_choose_marked(items)
              return true
            end,
          },

        },
        window = {
          config = function()
            local height = math.floor(0.618 * vim.o.lines)
            local width = math.floor(0.618 * vim.o.columns)

            return {
              relative = "editor",
              anchor = "NW",
              height = height,
              width = width,
              row = math.floor(0.5 * (vim.o.lines - height)),
              col = math.floor(0.5 * (vim.o.columns - width)),
              border = "rounded",
            }
          end,
        },
      })

      local map = vim.keymap.set
      map("n", "<leader>fd", function() require("mini.extra").pickers.diagnostic({ scope = "current" }) end, { desc = "Document diagnostics" })
      map("n", "<leader>fh", function() require("mini.pick").builtin.help() end, { desc = "Help pages" })
      map("n", "<leader>fk", function() require("mini.extra").pickers.keymaps() end, { desc = "Keymaps" })
      map("n", "<leader><leader>", function() require("mini.pick").builtin.buffers() end, { desc = "Buffers" })
      map("n", "<leader>u", function() local tree = vim.fn.undotree() local entries, seen = {}, {}
        local function add_entry(entry)
          if type(entry) ~= "table" or not entry.seq or seen[entry.seq] then
            return
          end
          seen[entry.seq] = true
          table.insert(entries, entry)
          if type(entry.alt) == "table" then
            for _, alternate in ipairs(entry.alt) do
              if type(alternate) == "table" then
                add_entry(alternate)
              end
            end
          end
        end

        for _, entry in ipairs(tree.entries or {}) do
          add_entry(entry)
        end
        table.sort(entries, function(a, b)
          return a.seq < b.seq
        end)

        local items = {}
        for _, entry in ipairs(entries) do
          local time = entry.time and os.date("%Y-%m-%d %H:%M:%S", entry.time)
          or "unknown time"
          local current = entry.seq == tree.seq_cur and " [current]" or ""
          table.insert(items, {
            seq = entry.seq,
            text = string.format("%s  seq %d%s", time, entry.seq, current),
          })
        end

        if #items == 0 then
          vim.notify("No undo history for this buffer", vim.log.levels.INFO)
          return
        end

        vim.ui.select(items, {
          prompt = "Undo history",
          format_item = function(item)
            return item.text
          end,
        }, function(item)
            if item then
              vim.cmd("undo " .. item.seq)
            end
          end)
      end, { desc = "Undo history" })
    end,
  },
}
