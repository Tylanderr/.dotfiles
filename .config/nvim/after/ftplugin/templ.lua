  vim.api.nvim_create_autocmd("FileType", {
    pattern = "templ",
    callback = function()
      vim.bo.commentstring = "// %s"
    end
  })

  vim.filetype.add({
    extension = {
      templ = "templ"
    }
  })
