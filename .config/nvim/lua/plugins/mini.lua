return {
  {
    "nvim-mini/mini.nvim",
    lazy = false,
    config = function()
      require("mini.ai").setup { n_lines = 500 }
      require("mini.surround").setup()
      require("mini.extra").setup()
      local function is_absolute_path(path)
        return path:sub(1, 1) == "/"
          or (path:match("^%a:") ~= nil and (path:sub(3, 3) == "/" or path:sub(3, 3) == "\\"))
      end

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

              local qf_items = {}
              for _, item in ipairs(items) do
                local entry
                if type(item) == "table" then
                  local bufnr = item.bufnr or item.buf_id or item.buf
                  local filename = item.path
                  if (not filename or filename == "") and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                    filename = vim.api.nvim_buf_get_name(bufnr)
                  end
                  local valid_buffer = bufnr and vim.api.nvim_buf_is_valid(bufnr)
                  if filename and filename ~= "" then
                    if filename:match("^%w[%w+.-]*://") then
                      local ok, uri_path = pcall(vim.uri_to_fname, filename)
                      filename = ok and uri_path or nil
                    elseif not is_absolute_path(filename) then
                      local cwd = pick.get_picker_opts().source.cwd or vim.fn.getcwd()
                      filename = vim.fs.joinpath(cwd, filename)
                    end
                  end
                  if (filename and filename ~= "") or valid_buffer then
                    entry = {
                      bufnr = valid_buffer and bufnr or nil,
                      filename = filename ~= "" and filename or nil,
                      lnum = item.lnum or 1,
                      col = item.col or 1,
                      end_lnum = item.end_lnum,
                      end_col = item.end_col,
                      text = "",
                    }
                  end
                elseif type(item) == "string" then
                  local path, lnum, col, text = item:match("^(.-)%z(%d+)%z?(%d*)%z?(.*)$")
                  path = path or item
                  local buffer_id = tonumber(path)
                  if buffer_id and vim.api.nvim_buf_is_valid(buffer_id) then
                    entry = { bufnr = buffer_id, lnum = tonumber(lnum) or 1, col = tonumber(col) or 1, text = text or "" }
                  elseif path ~= "" then
                    if path:match("^%w[%w+.-]*://") then
                      local ok, uri_path = pcall(vim.uri_to_fname, path)
                      path = ok and uri_path or nil
                    elseif path and not is_absolute_path(path) then
                      local cwd = pick.get_picker_opts().source.cwd or vim.fn.getcwd()
                      path = vim.fs.joinpath(cwd, path)
                    end
                    if path then
                      entry = {
                        filename = path,
                        lnum = tonumber(lnum) or 1,
                        col = tonumber(col) or 1,
                        text = "",
                      }
                    end
                  end
                end

                if entry then
                  table.insert(qf_items, entry)
                end
              end

              if #qf_items == 0 then
                vim.notify("No file or location matches to send to quickfix", vim.log.levels.WARN)
                return false
              end

              local picker_opts = pick.get_picker_opts()
              local title = picker_opts.source.name or "MiniPick"
              local query = table.concat(pick.get_picker_query())
              if query ~= "" then title = title .. " : " .. query end
              require("utils.quickfix")
              vim.fn.setqflist({}, " ", {
                items = qf_items,
                title = title,
                nr = "$",
                quickfixtextfunc = "v:lua.QuickfixFilenameText",
              })
              vim.schedule(function()
                pcall(vim.cmd, "cc 1")
              end)
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
