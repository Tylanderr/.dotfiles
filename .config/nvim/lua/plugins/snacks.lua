return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    terminal = {
      win = {
        position = "float"
      }
    },
    dashboard = {
      enabled = true,
      preset = {
        keys = {
          { icon = ' ', key = 'f', desc = 'File', action = function() require("fzf-lua").files() end },
          { icon = ' ', key = 'g', desc = 'Grep', action = function() require("fzf-lua").live_grep() end },
          { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
        }
      },
      formats = {
        key = function(item)
          return { { "[", hl = "special" }, { item.key, hl = "key" }, { "]", hl = "special" } }
        end,
      },
      sections = {
        { section = "header" },
        {
          section = "keys",
          gap = 1,
          padding = 1
        },
      }
    },
    picker = {
      enabled = false,
    },
    quickfile = { enabled = true },
    indent = {
      enabled = true,
      animate = {
        enabled = false
      },
      filter = function(buf)
        local exclude = { "java", "typescript", "markdown", "go", "lazy", "snacks_dashboard", "dbout", "mason",
          "sidekick_terminal", "opencode", "opencode_output" }
        local ft = vim.bo[buf].filetype
        return not vim.tbl_contains(exclude, ft)
      end
    },
  },
  keys = {
    { "<leader>lg", function() Snacks.lazygit() end, desc = "Lazygit" },
  }
}
