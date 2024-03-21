-- 自动检查映射是否重复
local function uniqueKeymap(modes, lhs, rhs, opts)
	if not opts then
		opts = {}
	end
	if opts.unique == nil then
		opts.unique = true
	end
	vim.keymap.set(modes, lhs, rhs, opts)
end

-- 代码块缩进
vim.keymap.set("v", ">", ">gv")
vim.keymap.set("v", "<", "<gv")

--  指向黑洞寄存器
vim.keymap.set("n", "x", '"_x')
vim.keymap.set("n", "c", '"_c')
-- 更智能的dd删除
vim.keymap.set("n", "dd", function()
	if vim.fn.getline(".") == "" then
		return '"_dd'
	end
	return "dd"
end, { expr = true })

-- 修改光标下的word
vim.keymap.set({ "n" }, "<leader>rc", "*``cgn", { desc = "修改文本" })

-- 保存
vim.keymap.set({ "n" }, "<C-s>", "<cmd>w<cr>", { desc = "保存", noremap = true, silent = true })

-- 删除buffer
vim.keymap.set({ "n" }, "<leader>tq", "<cmd>bdelete<cr>", { desc = "删除buffer", noremap = true, silent = true })

-- 切换buffer
vim.keymap.set("n", "<TAB>", "<cmd>bnext<cr>", { desc = "下一个缓冲区", noremap = true, silent = true })
vim.keymap.set("n", "<S-TAB>", "<cmd>bprev<cr>", { desc = "上一个缓冲区", noremap = true, silent = true })

-- tab操作
vim.keymap.set("n", "<leader>ta", "<cmd>$tabnew<CR>", { desc = "创建选项卡", noremap = true })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡", noremap = true })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开", noremap = true })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
vim.keymap.set(
	"n",
	"<leader>qt",
	'<cmd>lua require("modules.Quickfix_Toggle").toggleQuickfix()<cr>',
	{ desc = "quickfix窗口", noremap = true, silent = true }
)

-- 切换loclist窗口
vim.keymap.set(
	"n",
	"<leader>lt",
	'<cmd>lua require("modules.Loclist_Toggle").toggleLocationList ()<cr>',
	{ desc = "loclist窗口", noremap = true, silent = true }
)
