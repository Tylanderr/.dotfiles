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

    for index, key in ipairs({ "h", "j", "k", "l" }) do
      vim.keymap.set("n", "<C-" .. key .. ">", function()
        select_harpoon(index)
      end)
      vim.keymap.set("n", "<leader><C-" .. key .. ">", function()
        harpoon:list():replace_at(index)
      end)
    end
  end,
}
