return {
  "MeanderingProgrammer/render-markdown.nvim",
  event = "VeryLazy",
  config = function()
    local render_markdown = require('render-markdown')
    render_markdown.setup({
      render_modes = { 'n', 'no', 'i', 'c', 't' },
      anti_conceal = {
        enabled = true,
        disabled_modes = { 'n', 'c', 't' },
      },
      file_types = { 'markdown', 'opencode_output' },
    })

    local markdown_render_enabled = true

    local function set_markdown_render_state(buf)
      if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
        return
      end

      local ft = vim.bo[buf].filetype
      if ft == 'opencode_output' then
        vim.api.nvim_buf_call(buf, function()
          render_markdown.set_buf(true)
        end)
      elseif ft == 'markdown' then
        vim.api.nvim_buf_call(buf, function()
          render_markdown.set_buf(markdown_render_enabled)
        end)
      end
    end

    vim.keymap.set('n', '<leader>mr', function()
      markdown_render_enabled = not markdown_render_enabled

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        set_markdown_render_state(buf)
      end

      local state = markdown_render_enabled and 'enabled' or 'disabled'
      vim.notify('Markdown rendering ' .. state .. ' (opencode_output unchanged)', vim.log.levels.INFO)
    end, { desc = 'Toggle markdown rendering' })

    local markdown_render_group = vim.api.nvim_create_augroup('OpencodeMarkdownRender', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
      group = markdown_render_group,
      callback = function(args)
        set_markdown_render_state(args.buf)
      end,
    })
  end,
}
