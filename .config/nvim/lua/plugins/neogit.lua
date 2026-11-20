local neogit_open_context

return {
  "NeogitOrg/neogit",
  commit = "d93d7813cbd7acc44d2b058490c399ab84bf8d21",
  cmd = { "Neogit" },
  keys = {
    { "<leader>gs", desc = "Neogit status" },
    { "<leader>gt", "<cmd>Neogit<CR>", desc = "Neogit" },
    { "<leader>gb", "<cmd>Neogit branch<CR>", desc = "Neogit branches" },
    { "<leader>gz", "<cmd>Neogit stash<CR>", desc = "Neogit stash" },
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
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "tpope/vim-fugitive",
      cmd = "Git",
      keys = {
        { "<leader>gB", "<cmd>Git blame<CR>", desc = "Git blame" },
        { "<leader>gp", "<cmd>Git push<CR>", desc = "Git push" },
        { "<leader>gP", "<cmd>Git push --force<CR>", desc = "Git force push" },
        { "<leader>gu", "<cmd>Git pull --rebase<CR>", desc = "Git pull with rebase" },
        { "<leader>ga", "<cmd>Git commit --amend --no-edit<CR>", desc = "Amend Git commit" },
        { "<leader>gc", ":Git commit -m \"\"<Left>", desc = "Git commit" },
        { "<leader>go", ":Git push -u origin ", desc = "Git push to origin" },
      },
    },
  },
  config = function()
    local windows = require("utils.windows")

    local function focus_leftmost_editor(tabpage)
      if not vim.api.nvim_tabpage_is_valid(tabpage) then
        vim.notify("The originating tab is no longer available", vim.log.levels.WARN)
        return false
      end

      vim.api.nvim_set_current_tabpage(tabpage)
      local target = windows.leftmost_window(tabpage, { exclude_winfixbuf = true })
      if target then
        vim.api.nvim_set_current_win(target)
      else
        vim.cmd("topleft vsplit")
        vim.wo.winfixbuf = false
      end

      return true
    end

    vim.keymap.set("n", "<leader>gs", function()
      neogit_open_context = {
        tabpage = vim.api.nvim_get_current_tabpage(),
      }
      vim.cmd("Neogit kind=floating")
    end, { desc = "Neogit status" })

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
            -- File: close float, then open in the far-left editable window.
            local path = item.absolute_path
            local open_context = neogit_open_context
            local tabpage = open_context and open_context.tabpage or vim.api.nvim_get_current_tabpage()
            neogit_open_context = nil
            instance:close()
            vim.schedule(function()
              if not focus_leftmost_editor(tabpage) then return end
              vim.cmd("edit " .. vim.fn.fnameescape(path))
            end)
            return
          end

          -- Commit: close float, then open commit view
          local ref = instance.buffer.ui:get_yankable_under_cursor()
          if ref then
            local open_context = neogit_open_context
            local tabpage = open_context and open_context.tabpage or vim.api.nvim_get_current_tabpage()
            neogit_open_context = nil
            instance:close()
            vim.schedule(function()
              if not focus_leftmost_editor(tabpage) then return end
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
