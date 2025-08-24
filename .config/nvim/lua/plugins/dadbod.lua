return {
  'kristijanhusak/vim-dadbod-ui',
  lazy = true,
  dependencies = {
    { 'tpope/vim-dadbod' },
    { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' } },
  },
  cmd = {
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
  },
  init = function()
    -- Your DBUI configuration
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.omni_sql_no_default_maps = 1
    vim.g.db_ui_save_location = '~/connections/'

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "dbout",
      callback = function()
        vim.cmd("resize 50")
      end
    })
  end,
}
