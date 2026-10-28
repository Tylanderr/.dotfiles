return {
  "neovim/nvim-lspconfig",
  lazy = false,
  dependencies = {
    { "mason-org/mason.nvim",   opts = { ui = { border = "rounded" } } },
    { "folke/lazydev.nvim",     ft = "lua",                            opts = {} },
    { "deathbeam/lspecho.nvim", opts = { echo = true } },
  },
  config = function()
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
        end

        map("gd", function()
          vim.lsp.buf.definition({
            on_list = function(list)
              local items = list.items

              if #items == 1 then
                local item = items[1]
                local bufnr = item.bufnr or vim.fn.bufadd(item.filename)

                vim.api.nvim_win_set_buf(0, bufnr)
                vim.api.nvim_win_set_cursor(0, { item.lnum, item.col - 1 })
                return
              end

              if #items > 1 then
                local picker_items = vim.tbl_map(function(item)
                  return {
                    path = item.filename,
                    bufnr = item.bufnr,
                    lnum = item.lnum,
                    col = item.col,
                    text = item.text,
                  }
                end, items)

                require("mini.pick").start({
                  source = { items = picker_items, name = list.title },
                })
              end
            end,
          })
        end, "[G]oto [D]efinition")

        map("gr", function() require("mini.extra").pickers.lsp({ scope = "references" }) end, "[G]oto [R]eferences")
        map("gi", function() require("mini.extra").pickers.lsp({ scope = "implementation" }) end, "[G]oto [I]mplementation")
        map("gD", function() require("mini.extra").pickers.lsp({ scope = "declaration" }) end, "[G]oto [D]eclaration")
        map("gy", function() require("mini.extra").pickers.lsp({ scope = "type_definition" }) end, "Goto T[y]pe Definition")

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
