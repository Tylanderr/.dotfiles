return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  event = "VeryLazy",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    local harpoon = require "harpoon"

    harpoon:setup()

    local function select_harpoon(index)
      local ok, err = pcall(function()
        harpoon:list():select(index)
      end)

      if ok then
        return
      end

      local message = tostring(err)
      if message:match("E1513") or message:match("winfixbuf") then
        vim.notify("Navigation blocked by a fixed-buffer window", vim.log.levels.WARN)
        return
      end

      error(err, 0)
    end

    vim.keymap.set("n", "<leader>ha", function()
      harpoon:list():add()
    end)
    vim.keymap.set("n", "<C-e>", function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end)

    vim.keymap.set("n", "<C-h>", function()
      select_harpoon(1)
    end)
    vim.keymap.set("n", "<C-j>", function()
      select_harpoon(2)
    end)
    vim.keymap.set("n", "<C-k>", function()
      select_harpoon(3)
    end)
    vim.keymap.set("n", "<C-l>", function()
      select_harpoon(4)
    end)
    vim.keymap.set("n", "<leader><C-h>", function()
      harpoon:list():replace_at(1)
    end)
    vim.keymap.set("n", "<leader><C-j>", function()
      harpoon:list():replace_at(2)
    end)
    vim.keymap.set("n", "<leader><C-k>", function()
      harpoon:list():replace_at(3)
    end)
    vim.keymap.set("n", "<leader><C-l>", function()
      harpoon:list():replace_at(4)
    end)
  end,
}
