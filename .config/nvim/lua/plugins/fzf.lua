-- Wraps a fzf-lua file action so that if fzf was opened from an opencode
-- window (input or output), focus is redirected to the leftmost window
-- and then the file is opened there
local function with_opencode_redirect(action)
  return function(selected, opts)
    local ctx_winid = opts and opts.__CTX and opts.__CTX.winid
    if ctx_winid then
      local ok, ui = pcall(require, "opencode.ui.ui")
      if ok and ui.is_opencode_window(ctx_winid) then
        -- Find the leftmost non-opencode window by screen column position
        local wins = vim.api.nvim_tabpage_list_wins(0)
        local target = nil
        local target_col = math.huge
        for _, win in ipairs(wins) do
          if not ui.is_opencode_window(win) then
            local pos = vim.api.nvim_win_get_position(win)
            if pos[2] < target_col then
              target_col = pos[2]
              target = win
            end
          end
        end
        if not target then
          -- No non-opencode window exists; create one
          vim.cmd("topleft vsplit")
          target = vim.api.nvim_get_current_win()
        end
        vim.api.nvim_set_current_win(target)
        -- Patch the context so fzf's action opens into this window
        opts.__CTX.winid = target
        opts.__CTX.bufnr = vim.api.nvim_win_get_buf(target)
      end
    end
    return action(selected, opts)
  end
end

return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },

  ---@module "fzf-lua"
  ---@diagnostic disable: missing-fields
  ---@type fun(): fzf-lua.Config
  opts = function()
    local actions = require("fzf-lua.actions")
    return {
      grep = {
        hidden = true,
      },
      actions = {
        files = {
          ["enter"] = with_opencode_redirect(actions.file_edit),
          ["ctrl-s"] = with_opencode_redirect(actions.file_split),
          ["ctrl-v"] = with_opencode_redirect(actions.file_vsplit),
          ["ctrl-t"] = with_opencode_redirect(actions.file_tabedit),
          ["ctrl-q"] = {
            fn = actions.file_edit_or_qf,
            prefix = "select-all+"
          }
        },
      },
    }
  end,
  ---@diagnostic enable: missing-fields
  keys = {
    {
      "<leader>ff",
      function()
        require("fzf-lua").files({
          previewer = false,
          winopts = {
            height = 0.6,
            width = 0.4,
          }
        })
      end,
      desc = "Find Files",
      nowait = true
    },
    { "<leader>fg",       function() require("fzf-lua").live_grep() end,            desc = "Grep",                     nowait = true },
    { "<leader>fw",       function() require("fzf-lua").grep_visual() end,          desc = "Visual selection or word", mode = { "n", "x" } },
    { "<leader>fd",       function() require("fzf-lua").diagnostics_document() end, desc = "Diagnostics" },
    { "<leader>fh",       function() require("fzf-lua").helptags() end,             desc = "Help Pages" },
    { "<leader>fk",       function() require("fzf-lua").keymaps() end,              desc = "Keymaps" },
    { "<leader>u",        function() require("fzf-lua").undotree() end,             desc = "Undo History" },
    { "<leader><leader>", function() require("fzf-lua").buffers() end,              desc = "Buffers" },
  },
}
