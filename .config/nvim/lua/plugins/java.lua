return {
  'nvim-java/nvim-java',
  ft = "java",
  version = "v3.0.0",
  config = function()
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
  end,
}
