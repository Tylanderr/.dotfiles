return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    { "mason-org/mason.nvim",   opts = { ui = { border = "rounded" } } },
    { "folke/lazydev.nvim",     ft = "lua",                            opts = {} },
    { "deathbeam/lspecho.nvim", opts = { echo = true } },
  },
  config = function()
    local function unique_locations(items)
      local seen, unique = {}, {}

      for _, item in ipairs(items) do
        local filename = item.filename
        if not filename or filename == "" then
          filename = vim.api.nvim_buf_get_name(item.bufnr or 0)
        end
        filename = vim.fs.normalize(vim.fn.fnamemodify(filename, ":p"))

        local key = table.concat({ filename, tostring(item.lnum), tostring(item.col) }, "\0")
        if not seen[key] then
          seen[key] = true
          unique[#unique + 1] = vim.tbl_extend("force", item, { filename = filename })
        end
      end

      return unique
    end

    local function picker_item(item)
      local path = vim.fn.fnamemodify(item.filename, ":p:.")
      local text = item.text or ""

      return {
        path = item.filename,
        bufnr = item.bufnr,
        lnum = item.lnum,
        col = item.col,
        text = string.format("%s│%s│%s%s", path, item.lnum or 1, item.col or 1, text == "" and "" or ("│ " .. text)),
      }
    end

    local function pick_unique_locations(list)
      local items = vim.tbl_map(picker_item, unique_locations(list.items))

      if #items == 0 then
        vim.notify("No locations found", vim.log.levels.INFO)
        return
      end

      require("mini.pick").start({
        source = { name = list.title, items = items },
      })
    end

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
        end

        map("gd", function()
          vim.lsp.buf.definition({
            on_list = function(list)
              local items = unique_locations(list.items)

              if #items == 1 then
                local item = items[1]
                local bufnr = item.bufnr or vim.fn.bufadd(item.filename)

                vim.api.nvim_win_set_buf(0, bufnr)
                vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
                return
              end

              if #items > 1 then
                local picker_items = vim.tbl_map(picker_item, items)

                require("mini.pick").start({
                  source = { items = picker_items, name = list.title },
                })
              end
            end,
          })
        end, "[G]oto [D]efinition")

        map("gr", function() vim.lsp.buf.references(nil, { on_list = pick_unique_locations }) end, "[G]oto [R]eferences")
        map("gi", function() vim.lsp.buf.implementation({ on_list = pick_unique_locations }) end, "[G]oto [I]mplementation")
        map("gD", function() vim.lsp.buf.declaration({ on_list = pick_unique_locations }) end, "[G]oto [D]eclaration")
        map("gy", function() vim.lsp.buf.type_definition({ on_list = pick_unique_locations }) end, "Goto T[y]pe Definition")

        map("K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "Hover Documentation")
        map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
        map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
        map("<leader>vd", function() vim.diagnostic.open_float() end, "Open diagnostics float")
        map("<leader>li", "<cmd>LspInfo<CR>", "Open LspInfo")
        map("<leader>lr", "<cmd>LspRestart<CR>", "Restart LSP")
      end,
    })

    local function tableMerge(t1, t2)
      for _, v in ipairs(t2) do
        table.insert(t1, v)
      end
    end

    local active = {
      "html",
      "lua_ls",
    }

    local home_servers = {
      "gopls",
      "templ",
    }

    local work_servers = {
      "angularls",
      "ansiblels",
      "ts_ls",
      "yamlls",
      "nginx_language_server",
      "pylsp",
      -- "copilot"
    }

    if vim.fn.hostname() == "tjh" then
      tableMerge(active, home_servers)
    else
      tableMerge(active, work_servers)
    end

    for _, server in pairs(active) do
      vim.lsp.enable(server)
    end

    vim.diagnostic.config({
      virtual_text = false,
      underline = false,
      float = {
        border = "rounded",
      }
    })

    vim.keymap.set("n", "<leader>lx", function()
      local diagnosticVisible = vim.diagnostic.config().virtual_text
      vim.diagnostic.config({
        virtual_text = not diagnosticVisible,
      })
    end)
  end,
}
