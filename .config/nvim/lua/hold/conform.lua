return {
  "stevearc/conform.nvim",
  event = "VeryLazy",
  config = function()
    require('conform').setup({
      formatters_by_ft = {
        templ = { "templ" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
      },
    })
  end
}
