return {
  "sudo-tee/opencode.nvim",
  event = "VeryLazy",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "MeanderingProgrammer/render-markdown.nvim",
      opts = {
        anti_conceal = { enabled = false },
        file_types = { 'markdown', 'opencode_output' },
      },
      ft = { 'markdown', 'Avante', 'copilot-chat', 'opencode_output' },
    },
    'hrsh7th/nvim-cmp',
    'ibhagwan/fzf-lua',
  },
  config = function()
    require("opencode").setup({
      preferred_picker = 'fzf',
      preferred_completion = 'nvim-cmp',
      default_global_keymaps = true,
      default_mode = 'coworker',
      default_system_prompt = nil,
      keymap_prefix = '<leader>o',
      opencode_executable = 'opencode',

      keymap = {
        editor = {
          ['<C-\\>'] = { 'toggle' },
          ['<leader>/'] = { 'quick_chat', mode = { 'n', 'x' } },
          ['<leader>av'] = { 'add_visual_selection', mode = { 'v' } },
          ['<leader>oi'] = { function()
            require('opencode.core').open({ new_session = false, focus = 'input', start_insert = false })
          end }
        },
        input_window = {
          ['<tab>'] = { 'switch_mode' },
          ['<C-c>'] = {
            function()
              if require('opencode.state').is_running() then
                require('opencode.api').cancel()
              end
            end,
            mode = { 'n' },
          },
        },
      },
      ui = {
        window_width = 0.30,
        zoom_width = 0.8,
      },
    })

    vim.keymap.set("n", "<leader>mr", function() require('render-markdown').toggle() end,
      { desc = "Toggle markdown render" })
  end,
}
