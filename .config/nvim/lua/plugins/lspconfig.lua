return {
  {
    'neovim/nvim-lspconfig',
    lazy = false,
    dependencies = {
      { 'williamboman/mason.nvim',           version = "^1.0.0",    opts = {} },
      { 'williamboman/mason-lspconfig.nvim', version = "^1.0.0" },
      { 'folke/lazydev.nvim',                ft = "lua",            opts = {} },
      { 'deathbeam/lspecho.nvim',            opts = { echo = true } },
      { 'hrsh7th/cmp-cmdline' },
      { 'folke/snacks.nvim' },
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('gd', function() Snacks.picker.lsp_definitions() end, '[G]oto [D]efinition')
          map('gr', function() Snacks.picker.lsp_references() end, '[G]oto [R]eferences')
          map('gi', function() Snacks.picker.lsp_implementations() end, '[G]oto [I]mplementation')
          map('gD', function() Snacks.picker.lsp_declarations() end, '[G]oto [D]eclaration')
          map("gy", function() Snacks.picker.lsp_type_definitions() end, "Goto T[y]pe Definition")

          map('K', vim.lsp.buf.hover, 'Hover Documentation')
          map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
          map('<leader>vd', function() vim.diagnostic.open_float() end, 'Open diagnostics float')
          map('<leader>li', "<cmd>LspInfo<CR>", 'Open LspInfo')
          map('<leader>lr', "<cmd>LspRestart<CR>", 'Restart LSP')
        end,
      })

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = vim.tbl_deep_extend('force', capabilities, require('cmp_nvim_lsp').default_capabilities())

      local function tableMerge(t1, t2)
        for _, v in ipairs(t2) do
          table.insert(t1, v)
        end
      end

      local work_flag = false

      local active = {
        'html',
        'lua_ls',
      }

      local home_servers = {
        'gopls',
        'templ',
      }

      local work_servers = {
        'angularls',
        'ansiblels',
        'ts_ls',
        'yamlls',
        'nginx_language_server',
      }

      if work_flag then
        tableMerge(active, work_servers)
      else
        tableMerge(active, home_servers)
      end

      for _, server in pairs(active) do
        vim.lsp.enable(server)
      end
    end,

    vim.diagnostic.config({
      virtual_text = false,
      underline = false,
    }),

    vim.keymap.set("n", "<leader>lx", function()
      local diagnosticVisible = vim.diagnostic.config().virtual_text
      vim.diagnostic.config({
        virtual_text = not diagnosticVisible,
      })
    end)
  },
}
