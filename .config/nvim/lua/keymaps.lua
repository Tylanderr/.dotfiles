vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<CR>")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

vim.keymap.set("n", "z", "zz")

vim.keymap.set('v', '<Tab>', '>gv')
vim.keymap.set('v', '<S-Tab>', '<gv')

vim.keymap.set("x", "<leader>p", [["_dP]])
vim.keymap.set("n", "<leader>Y", [["+Y]])
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]])

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "q", "<nop>")
vim.keymap.set("n", "<leader>qu", "<cmd>q<CR>")
vim.keymap.set("n", "<leader>QU", "<cmd>qa!<CR>")

vim.keymap.set({ "n", "v" }, "<leader>cf", vim.lsp.buf.format, bufopts)

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set("n", "<leader>nh", "<cmd>noh<CR>")
vim.keymap.set("n", "<leader>wv", "<cmd>vsplit<CR>")

vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<CR>")
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>")
vim.keymap.set("n", "<leader>tl", "<cmd>tabnext<CR>")
vim.keymap.set("n", "<leader>th", "<cmd>tabprev<CR>")

vim.keymap.set("n", "<leader>sft", "<cmd>lua print(vim.bo.filetype)<CR>")
