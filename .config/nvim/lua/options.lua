vim.opt.guicursor = ""

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.cmdheight = 0

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv 'HOME' .. '/.vim/undodir'
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 10
vim.opt.signcolumn = 'yes'
vim.opt.isfname:append '@-@'

vim.opt.updatetime = 50

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "*" },
	callback = function()
		vim.opt_local.formatoptions:remove({ 'o' })
	end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Debug unexpected yanks to register x",
	group = vim.api.nvim_create_augroup("debug-yank-x", { clear = true }),
	callback = function(event)
		if event.data and event.data.regname == "x" then
			local stack = debug.traceback("Yank to register x detected", 2)
			vim.notify(stack, vim.log.levels.WARN)
		end
	end,
})
