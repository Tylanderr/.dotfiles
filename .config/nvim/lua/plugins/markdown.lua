return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown", "opencode_output" },
  config = function()
    local render_markdown = require("render-markdown")
    render_markdown.setup({
      render_modes = { "n", "no", "i", "c", "t", "v", "V", "\22" },
      anti_conceal = {
        enabled = true,
        disabled_modes = { "n", "c", "t" },
      },
      file_types = { "markdown", "opencode_output" },
    })

    local markdown_render_enabled = true

    local function set_markdown_render_state(buf, attach)
      if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
        return
      end

      local ft = vim.bo[buf].filetype
      if ft ~= "markdown" and ft ~= "opencode_output" then
        return
      end

      local manager = require("render-markdown.core.manager")
      if not manager.attached(buf) and attach then
        manager.attach(buf)
      end

      if not manager.attached(buf) then
        return
      end

      local desired = ft == "opencode_output" or markdown_render_enabled
      local current = require("render-markdown.state").get(buf).enabled
      if current ~= desired then
        require("render-markdown.core.manager").set_buf(buf, desired)
      end
    end

    vim.keymap.set("n", "<leader>mr", function()
      markdown_render_enabled = not markdown_render_enabled
      render_markdown.set(markdown_render_enabled)

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "opencode_output" then
          set_markdown_render_state(buf, false)
        end
      end

      local state = markdown_render_enabled and "enabled" or "disabled"
      vim.notify("Markdown rendering " .. state .. " (opencode_output unchanged)", vim.log.levels.INFO)
    end, { desc = "Toggle markdown rendering" })

    local markdown_render_group = vim.api.nvim_create_augroup("OpencodeMarkdownRender", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
      group = markdown_render_group,
      callback = function(args)
        vim.schedule(function()
          set_markdown_render_state(args.buf, true)
        end)
      end,
    })

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      vim.schedule(function()
        set_markdown_render_state(buf, true)
      end)
    end
  end,
}
