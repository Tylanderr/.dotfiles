return {
  'nvim-java/nvim-java',
  ft = "java",
  config = function()
    require('java').setup({
      java_test = {
        enable = true
      },

      java_debug_adapter = {
        enable = true,
        version = '0.58.2'
      },

      spring_boot_tools = {
        enable = true,
        version = '1.55.1'
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
