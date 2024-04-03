-- 按键映射简化及设置模块
_G.keymap = require("util.key_map").setKeymap
-- 设置前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = " "
-- 代码块缩进
keymap("v", ">", ">gv")
keymap("v", "<", "<gv")

--  指向黑洞寄存器
keymap("n", "x", '"_x')
keymap("n", "c", '"_c')

-- 更智能的dd删除
keymap("n", "dd", function()
	if vim.fn.getline(".") == "" then
		return '"_dd'
	end
	return "dd"
end, { expr = true })

-- 修改光标下的word
keymap({ "n" }, "<leader>rc", "*``cgn", { desc = "修改文本" })

-- 保存
keymap({ "n" }, "<C-s>", "<cmd>w<cr>", { desc = "保存" })

-- 删除buffer
keymap({ "n" }, "<leader>tq", "<cmd>bdelete<cr>", { desc = "删除buffer" })

-- 切换buffer
-- keymap("n", "<TAB>", "<cmd>bnext<cr>", { desc = "下一个缓冲区" })
-- keymap("n", "<S-TAB>", "<cmd>bprev<cr>", { desc = "上一个缓冲区" })

-- tab操作
keymap("n", "<leader>tn", "<cmd>$tabnew<CR>", { desc = "创建选项卡" })
keymap("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "关闭选项卡" })
keymap("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "仅保留当前标签页打开" })

-- 删除标记
keymap("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 退出终端
-- map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- 切换quickfix窗口
keymap("n", "<leader>q", '<cmd>lua require("util.quickfix_toggle").toggleQuickfix()<cr>', { desc = "quickfix窗口" })

-- 切换loclist窗口
keymap(
	"n",
	"<leader>l",
	'<cmd>lua require("util.loclist_toggle").toggleLocationList ()<cr>',
	{ desc = "loclist窗口" }
)
