-- 设置前置按键
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 代码块移动
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ'z")

-- 指向黑洞寄存器
vim.keymap.set("n", "x", '"_x')
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
vim.keymap.set("n", "<c-q>", "<cmd>BufferDelete<cr>", { desc = "删除buffer" })

-- 删除标记
vim.keymap.set("n", "dm", "<cmd>delmarks!<cr>", { desc = "删除标记" })

-- 切换quickfix窗口
vim.keymap.set(
	"n",
	"<leader>q",
	'<cmd>lua require("user.keybindings").toggleQuickfix()<cr>',
	{ desc = " QuickfixToggle" }
)
vim.keymap.set("n", "]q", "<cmd>cprev<cr>")
vim.keymap.set("n", "[q", "<cmd>cnext<cr>")

-- 切换loclist窗口
vim.keymap.set(
	"n",
	"<leader>l",
	'<cmd>lua require("user.keybindings").toggleLocationList()<cr>',
	{ desc = " LoclistToggle" }
)
vim.keymap.set("n", "]l", "<cmd>lnext<cr>")
vim.keymap.set("n", "[l", "<cmd>lprev<cr>")

-- snippet片段占位符跳转
vim.keymap.set({ "i", "s" }, "<Tab>", function()
	if vim.snippet.active({ direction = 1 }) then
		return "<cmd>lua vim.snippet.jump(1)<cr>"
	else
		return "<Tab>"
	end
end, { expr = true })

vim.keymap.set({ "i", "s" }, "<S-Tab>", function()
	if vim.snippet.active({ direction = -1 }) then
		return "<cmd>lua vim.snippet.jump(-1)<cr>"
	else
		return "<S-Tab>"
	end
end, { expr = true })

-- 插入模式下TAB可以跳出()[]....
vim.keymap.set("i", "<Tab>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
	local special_chars = { '"', "'", ")", "]", "}", ">" }
	return next_char == "" or not vim.tbl_contains(special_chars, next_char) and "<Tab>" or "<Right>"
end, { expr = true })

-- 自动关闭？/搜索匹配高亮
vim.on_key(function(char)
	if vim.fn.mode() == "n" then
		local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
		if vim.opt.hlsearch:get() ~= new_hlsearch then
			vim.opt.hlsearch = new_hlsearch
		end
	end
end, vim.api.nvim_create_namespace("auto_hlsearch"))
