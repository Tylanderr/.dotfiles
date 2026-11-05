vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<CR>")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

vim.keymap.set("v", "<Tab>", ">gv")
vim.keymap.set("v", "<S-Tab>", "<gv")

vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "v" }, "<leader>y", [["+y]], { nowait = true })
vim.keymap.set({ "n" }, "<leader>ya", [[ggVG"+y]])
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "q", "<nop>")
vim.keymap.set("n", "<M-m>", "<nop>")
vim.keymap.set("n", "<c-q>", "<nop>")
vim.keymap.set("n", "<c-f>", "<nop>")

vim.keymap.set("v", "<leader>s", [[y:%s/\<<C-r>0\>/<C-r>0/gI<Left><Left><Left>]])
vim.keymap.set({ "n", "v" }, "<leader>=", "mzgg=G`zzz", { noremap = true, silent = true })

vim.keymap.set("n", "<leader>nh", "<cmd>noh<CR>")
vim.keymap.set("n", "<leader>wv", "<cmd>vsplit<CR>")
vim.keymap.set("n", "<leader>ws", "<cmd>split<CR>")

vim.keymap.set("n", "<leader>sft", function() print(vim.bo.filetype) end)

vim.keymap.set("n", "<leader>i", "1<C-w>w")

vim.keymap.set("n", "qn", "<cmd>cnext<CR>")
vim.keymap.set("n", "qp", "<cmd>cprev<CR>")
vim.keymap.set("n", "qc", "<cmd>cclose<CR>")
vim.keymap.set("n", "qo", function()
  vim.cmd("topleft vertical copen")
  vim.cmd("wincmd H")
  vim.cmd("vertical resize 50")
end, { desc = "Open quickfix on the far left", silent = true })

vim.keymap.set("n", "<leader>qu", function()
  local api = vim.api
  local current_win = api.nvim_get_current_win()
  local opencode_filetypes = {
    opencode = true,
    opencode_output = true,
    opencode_footer = true,
    opencode_session_tabs = true,
  }
  local has_other_editor_window = false

  for _, win in ipairs(api.nvim_list_wins()) do
    local config = api.nvim_win_get_config(win)
    local is_regular_window = config.relative == "" and not config.external

    if win ~= current_win and is_regular_window then
      local buf = api.nvim_win_get_buf(win)
      if not opencode_filetypes[vim.bo[buf].filetype] then
        has_other_editor_window = true
        break
      end
    end
  end

  if has_other_editor_window then
    vim.cmd("quit")
  else
    vim.cmd("quitall")
  end
end, { desc = "Quit pane; exit if only OpenCode would remain" })
vim.keymap.set("n", "<leader>QU", "<cmd>qa!<CR>")

vim.keymap.set("n", "<leader>tl", "<cmd>tabnext<CR>")
vim.keymap.set("n", "<leader>th", "<cmd>tabprev<CR>")
vim.keymap.set("n", "<leader>tc", function()
  if vim.fn.tabpagenr() == 1 then
    vim.cmd("tabonly")
  else
    vim.cmd("tabclose")
  end
end)

vim.keymap.set({ "n", "v" }, "<leader>cf", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.api.nvim_get_mode().mode
  local method = (mode == "v" or mode == "V" or mode == "\22")
  and vim.lsp.protocol.Methods.textDocument_rangeFormatting
  or vim.lsp.protocol.Methods.textDocument_formatting
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })

  if vim.bo[bufnr].filetype == "templ" then
    clients = vim.tbl_filter(function(client)
      return client.name == "templ"
    end, clients)
  end

  if #clients == 0 then
    vim.notify("No configured formatter for this buffer", vim.log.levels.WARN)
    return
  end
  if #clients > 1 then
    vim.notify(
      "Multiple LSP formatters attached (" .. table.concat(vim.tbl_map(function(client)
        return client.name
      end, clients), ", ") .. "); formatting was skipped",
      vim.log.levels.WARN
    )
    return
  end

  vim.lsp.buf.format({ async = true, id = clients[1].id })
end, { noremap = true, silent = true, desc = "Format with LSP" })

vim.keymap.set("n", "<leader>x", function()
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    vim.notify("Current buffer has no file", vim.log.levels.WARN)
    return
  end

  vim.system({ "chmod", "+x", "--", filename }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify("Made executable: " .. filename, vim.log.levels.INFO)
      else
        vim.notify("chmod failed: " .. (result.stderr ~= "" and result.stderr or filename), vim.log.levels.ERROR)
      end
    end)
  end)
end, { desc = "Make current file executable" })
