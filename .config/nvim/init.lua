vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

require "options"
require "keymaps"
require "utils.filetypes"
require "utils.terminal"
require "lazy-bootstrap"
require "lazy-plugins"