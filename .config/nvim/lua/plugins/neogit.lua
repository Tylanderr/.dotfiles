local function float_layout()
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    return
  end

  return {
    height = math.floor(ui.height * 0.7),
    width = math.floor(ui.width * 0.7),
  }
end

return {
  "NeogitOrg/neogit",
  event = "VeryLazy",
  commit = "d93d7813cbd7acc44d2b058490c399ab84bf8d21",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "tpope/vim-fugitive",
  },
  config = function()
    require("neogit").setup({
      use_default_keymaps = false,
      disable_context_highlighting = true,
      disable_hint = true,
      floating = float_layout(),
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
          ["<tab>"] = "Toggle",
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
            -- File: close float, then open in vsplit
            local path = item.absolute_path
            instance:close()
            vim.schedule(function()
              vim.cmd("edit " .. vim.fn.fnameescape(path))
            end)
            return
          end

          -- Commit: close float, then open commit view
          local ref = instance.buffer.ui:get_yankable_under_cursor()
          if ref then
            instance:close()
            vim.schedule(function()
              require("neogit.buffers.commit_view").new(ref):open()
            end)
          end
        end, { buffer = ev.buf, silent = true })
      end,
    })

    vim.keymap.set("n", "<leader>gs", "<cmd>Neogit kind=floating<CR>")
    vim.keymap.set("n", "<leader>gt", "<cmd>Neogit<CR>")
    vim.keymap.set('n', '<leader>gb', '<cmd>Git blame<CR>')
    vim.keymap.set("n", "<leader>gp", "<cmd>Git push<CR>")
    vim.keymap.set("n", "<leader>gP", "<cmd>Git push --force<CR>")
    vim.keymap.set("n", "<leader>gu", "<cmd>Git pull --rebase<CR>")
    vim.keymap.set("n", "<leader>ga", "<cmd>Git commit --amend --no-edit<CR>");
    vim.keymap.set('n', '<leader>gc', ':Git commit -m ""<Left>')
    vim.keymap.set("n", "<leader>go", ":Git push -u origin ");

    vim.api.nvim_create_autocmd("User", {
      pattern = "FugitiveChanged",
      callback = function()
        require("neogit").dispatch_refresh()
      end,
    })
  end
}
