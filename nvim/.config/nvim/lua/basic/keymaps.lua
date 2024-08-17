-- 设置前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 代码块移动
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- vim.keymap.set("n", "J", "mzJ'z")

-- 指向黑洞寄存器
-- vim.keymap.set("n", "x", '"_x')
vim.keymap.set("n", "c", '"_c')

-- 更智能的dd删除
vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true })

-- 将绝对路径复制到剪贴板
vim.keymap.set("n", "<leader>yp", ':let @+ = expand("%:p")<CR>')
-- 将相对路径复制到剪贴板
vim.keymap.set("n", "<leader>yf", ':let @+ = expand("%:f")<CR>')
-- 将文件名复制到剪贴板
vim.keymap.set("n", "<leader>yt", ':let @+ = expand("%:t")<CR>')

-- 搜索与替换
vim.keymap.set("n", "crc", "*``cgn", { desc = "修改文本" })
vim.keymap.set("x", "crc", [[y<cmd>let @/ = escape(@", '/')<cr>"_cgn]])
vim.keymap.set("n", "crs", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<left><left><left>")

-- 保存
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "保存" })

-- 终端映射
-- vim.keymap.set("t", "<esc>", "<C-\\><C-n>", { noremap = true, silent = true })

-- tab操作
vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<CR>", { desc = "创建选项卡" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开" })
-- vim.keymap.set("n", "<TAB>", "<cmd>bn<CR>", { desc = "切换buffer" })
-- vim.keymap.set("n", "<S-TAB>", "<cmd>bp<CR>", { desc = "切换buffer" })
vim.keymap.set("n", "<leader>tq", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
vim.keymap.set("n", "<leader>q", '<cmd>lua require("user.keybindings").toggleQuickfix()<cr>')
vim.keymap.set("n", "]q", "<cmd>cprev<cr>")
vim.keymap.set("n", "[q", "<cmd>cnext<cr>")

-- 切换loclist窗口
vim.keymap.set("n", "<leader>l", '<cmd>lua require("user.keybindings").toggleLocationList()<cr>')
vim.keymap.set("n", "]l", "<cmd>lnext<cr>")
vim.keymap.set("n", "[l", "<cmd>lprev<cr>")

-- grep功能优化
vim.cmd([[command! -nargs=+ Grep execute 'silent grep! <args>' | copen]])
-- 定义快速修复映射函数
-- TODO: 加入loclist按键映射
-- 实现逻辑：
-- 1、判断当前buffer是loclist还是quickfix
-- 2、根据判断结果执行对应的按键映射
local function QuickfixMapping()
	-- to the previous location and stay in the quickfix window
	vim.keymap.set("n", "{", ":cprev<CR>zz<C-w>w", { buffer = true })
	-- to the next location and stay in the quickfix window
	vim.keymap.set("n", "}", ":cnext<CR>zz<C-w>w", { buffer = true })
	-- 使快速修复列表可修改
	vim.keymap.set("n", "<leader>ow", ":set modifiable<CR>", { buffer = true })
end
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("quickfix_group", { clear = true }),
	pattern = "qf",
	callback = QuickfixMapping,
})
