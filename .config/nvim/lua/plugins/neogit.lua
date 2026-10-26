local neogit_open_context

return {
  "NeogitOrg/neogit",
  cmd = { "Neogit" },
  keys = {
    { "<leader>gt", "<cmd>Neogit<CR>", mode = "n", desc = "Neogit" },
    { "<leader>gb", "<cmd>Neogit branch<CR>", mode = "n", desc = "Neogit branches" },
    { "<leader>gz", "<cmd>Neogit stash<CR>", mode = "n", desc = "Neogit stash" },
  },
  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "FugitiveChanged",
      callback = function()
        if package.loaded.neogit then
          require("neogit").dispatch_refresh()
        end
      end,
    })
  end,
  commit = "d93d7813cbd7acc44d2b058490c399ab84bf8d21",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    vim.keymap.set("n", "<leader>gs", function()
      local win = vim.api.nvim_get_current_win()
      local ok, ui = pcall(require, "opencode.ui.ui")
      neogit_open_context = {
        tabpage = vim.api.nvim_get_current_tabpage(),
        redirect = ok and ui.is_opencode_window(win),
      }
      vim.cmd("Neogit kind=floating")
    end, { desc = "Neogit status" })
    local function is_opencode_window(win)
      local ok, ui = pcall(require, "opencode.ui.ui")
      return ok and ui.is_opencode_window(win)
    end

    local function leftmost_non_opencode_window(tabpage)
      local target
      local target_position

      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative == "" and not is_opencode_window(win) then
          local position = vim.api.nvim_win_get_position(win)
          if not target_position
            or position[2] < target_position[2]
            or (position[2] == target_position[2] and position[1] < target_position[1])
          then
            target = win
            target_position = position
          end
        end
      end

      return target
    end

    require("neogit").setup({
      use_default_keymaps = false,
      disable_context_highlighting = true,
      disable_hint = true,
      floating = {
        height = 0.7,
        width = 0.7,
      },
      mappings = {
        commit_editor = {},
        commit_editor_I = {},
        rebase_editor = {},
        rebase_editor_I = {},
        finder = {},
        popup = {},
        status = {
          ["j"] = "MoveDown",
          ["k"] = "MoveUp",
          ["o"] = "OpenTree",
          ["q"] = "Close",
          ["x"] = "Discard",
          ["s"] = "Stage",
          ["S"] = "StageUnstaged",
          ["<c-s>"] = "StageAll",
          ["u"] = "Unstage",
          ["K"] = "Untrack",
          ["U"] = "UnstageStaged",
          ["Y"] = "YankSelected",
          ["<c-r>"] = "RefreshBuffer",
        },
      },
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "NeogitStatus",
      callback = function(ev)
        vim.keymap.set("n", "<cr>", function()
          local instance = require("neogit.buffers.status").instance()
          if not instance then return end

          local item = instance.buffer.ui:get_item_under_cursor()
          if item and item.absolute_path then
            -- File: close float, then open in the originating or redirected window
            local path = item.absolute_path
            local open_context = neogit_open_context
            neogit_open_context = nil
            instance:close()
            vim.schedule(function()
              if open_context and open_context.redirect then
                local tabpage = open_context.tabpage
                if not vim.api.nvim_tabpage_is_valid(tabpage) then
                  vim.notify("The originating tab is no longer available", vim.log.levels.WARN)
                  return
                end

                vim.api.nvim_set_current_tabpage(tabpage)
                local target = leftmost_non_opencode_window(tabpage)
                if target then
                  vim.api.nvim_set_current_win(target)
                else
                  vim.cmd("topleft vsplit")
                end
              end

              vim.cmd("edit " .. vim.fn.fnameescape(path))
            end)
            return
          end

          -- Commit: close float, then open commit view
          local ref = instance.buffer.ui:get_yankable_under_cursor()
          if ref then
            neogit_open_context = nil
            instance:close()
            vim.schedule(function()
              require("neogit.buffers.commit_view").new(ref):open()
            end)
          end
        end, { buffer = ev.buf, silent = true })

        -- Toggle folds: Item level for file diffs, Section level for Recent Commits
        vim.keymap.set("n", "<tab>", function()
          local instance = require("neogit.buffers.status").instance()
          if not instance then return end

          -- Prefer an Item fold (file diffs); fall back to any foldable ancestor
          -- (covers Section headers like "Recent Commits" and child commit rows)
          local fold = instance.buffer.ui:get_component_under_cursor(function(c)
            return c.options.foldable and c.options.tag == "Item"
          end) or instance.buffer.ui:get_fold_under_cursor()
          if not fold then return end

          if fold.options.on_open then
            fold.options.on_open(fold, instance.buffer.ui)
          else
            local start, _ = fold:row_range_abs()
            -- Move cursor to the first row of the fold so normal! za acts on the
            -- correct fold rather than any nested fold under the cursor
            instance.buffer:move_cursor(start)
            local ok, _ = pcall(function() vim.cmd("normal! za") end)
            if ok then
              fold.options.folded = not fold.options.folded
            end
          end
        end, { buffer = ev.buf, silent = true })
      end,
    })

  end
}
