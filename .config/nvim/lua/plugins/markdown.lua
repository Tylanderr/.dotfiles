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

    local function add_missing_task_checkboxes(buf)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local changed = false
      local added = 0

      for i, line in ipairs(lines) do
        local prefix = line:match("^(%s*%-%s+)")
          or line:match("^(%s*%*%s+)")
          or line:match("^(%s*%+%s+)")
          or line:match("^(%s*%d+[.)]%s+)")

        if prefix then
          local body = line:sub(#prefix + 1)
          local has_checkbox =
            body:match("^%[[ xX]%]%s") ~= nil
            or body:match("^%[[ xX]%]$") ~= nil

          if body:match("%S") and not has_checkbox then
            lines[i] = prefix .. "[ ] " .. body
            changed = true
            added = added + 1
          end
        end
      end

      if changed then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.notify("Added " .. added .. " checkbox(es)", vim.log.levels.INFO)
      else
        vim.notify("No unchecked list items found", vim.log.levels.INFO)
      end
    end

    local function set_markdown_render_state(buf)
      if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
        return
      end

      local ft = vim.bo[buf].filetype
      if ft ~= "markdown" and ft ~= "opencode_output" then
        return
      end

      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        vim.wo[win].wrap = true
        vim.wo[win].linebreak = true
        vim.wo[win].breakindent = true
      end

      if ft == "markdown" then
        vim.keymap.set("n", "<leader>mt", function()
          add_missing_task_checkboxes(buf)
        end, {
          buffer = buf,
          desc = "Add checkboxes to Markdown list items",
        })
      end

      vim.keymap.set("n", "j", "gj", { buffer = buf, desc = "Move down by display line" })
      vim.keymap.set("n", "k", "gk", { buffer = buf, desc = "Move up by display line" })

      local manager = require("render-markdown.core.manager")
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
          set_markdown_render_state(buf)
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
          set_markdown_render_state(args.buf)
        end)
      end,
    })

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      vim.schedule(function()
        set_markdown_render_state(buf)
      end)
    end
  end,
}

