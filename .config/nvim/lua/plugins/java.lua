return {
  'nvim-java/nvim-java',
  ft = "java",
  version = "v3.0.0",
  config = function()
    -- Temporary to suppress a deprecation message
    local original_deprecate = vim.deprecate
    vim.deprecate = function(name, alternative, version, plugin, backtrace)
      if name == "The `require('lspconfig')` \"framework\"" and plugin == 'nvim-lspconfig' then
        return
      end

      return original_deprecate(name, alternative, version, plugin, backtrace)
    end

    require('java').setup({
      java_test = {
        enable = false
      },

      java_debug_adapter = {
        enable = false,
      },

      spring_boot_tools = {
        enable = true,
      },

      notifications = {
        dap = false
      },

      mason = {
        registries = {
          'github:nvim-java/mason-registry',
        }
      }
    })

    -- jdtls uses this custom request for Spring Boot and workspace commands.
    vim.lsp.handlers['workspace/executeClientCommand'] = function(_, params, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
      local command = (client.commands or {})[params.command]
        or vim.lsp.commands[params.command]

      if not command then
        return vim.lsp.rpc_response_error(
          vim.lsp.protocol.ErrorCodes.MethodNotFound,
          'Command ' .. params.command .. ' not supported on client'
        )
      end

      local ok, result = pcall(command, params.arguments, ctx)
      if ok then
        return result or vim.NIL
      end

      return vim.lsp.rpc_response_error(
        vim.lsp.protocol.ErrorCodes.InternalError,
        result
      )
    end

    require('lspconfig').jdtls.setup({
      settings = {
        java = {
          configuration = {
            runtimes = {
              {
                name = "openjdk-17",
                path = "/usr/lib/jvm/",
                default = true,
              }
            }
          }
        }
      },
    })

    vim.deprecate = original_deprecate
  end,
}
