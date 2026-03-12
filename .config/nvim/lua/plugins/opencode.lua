return {
  "sudo-tee/opencode.nvim",
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
    'folke/snacks.nvim',
  },
  config = function()
    require("opencode").setup({
      preferred_picker = 'snacks',
      preferred_completion = 'nvim-cmp',
      default_global_keymaps = true,
      default_mode = 'plan',
      default_system_prompt = nil,
      keymap_prefix = '<leader>o',
      opencode_executable = 'opencode',

      keymap = {
        editor = {
          ['<C-\\>'] = { 'toggle' },
          ['<leader>/'] = { 'quick_chat', mode = { 'n', 'x' } },
          ['<leader>av'] = { 'add_visual_selection', mode = {'v'} },
        },
        input_window = {
          ['<tab>'] = { 'switch_mode' },
        },
      },
      ui = {
        window_width = 0.30,
        zoom_width = 0.8,
      },
    })
  end,
}
