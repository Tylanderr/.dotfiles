return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },

  ---@module "fzf-lua"
  ---@type fzf-lua.Config|{}
  ---@diagnostic disable: missing-fields
  opts = {
    grep = {
      hidden = true,
    },
  },
  ---@diagnostic enable: missing-fields
  keys = {
    { "<leader><leader>", function() require("fzf-lua").buffers() end,   desc = "Buffers" },
    { "<leader>fg",       function() require("fzf-lua").live_grep() end, desc = "Grep",   nowait = true },
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
    { "<leader>fw", function() require("fzf-lua").grep_visual() end,          desc = "Visual selection or word", mode = { "n", "x" } },
    { "<leader>fd", function() require("fzf-lua").diagnostics_document() end, desc = "Diagnostics" },
    { "<leader>fh", function() require("fzf-lua").helptags() end,             desc = "Help Pages" },
    { "<leader>fk", function() require("fzf-lua").keymaps() end,              desc = "Keymaps" },
    { "<leader>u",  function() require("fzf-lua").undotree() end,             desc = "Undo History" },
  },
}
