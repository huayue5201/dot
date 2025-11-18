-- 📝 基础操作
vim.keymap.set("n", "c", '"_c', { desc = "修改并丢弃到黑洞寄存器" })
vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "删除当前行（空行使用黑洞寄存器）" })
vim.keymap.set("n", "<c-s>", "<cmd>w<cr>", { silent = true, desc = "保存 buffer" })
vim.keymap.set("n", "<Leader>q", ":bd<cr>", { silent = true, desc = "退出 buffer" })

-- 🏷 标签页操作
vim.keymap.set("n", "<leader>ttn", "<cmd>$tabnew<cr>", { silent = true, desc = "创建新的标签页" })
vim.keymap.set("n", "<leader>rt", "<cmd>tabclose<cr>", { silent = true, desc = "关闭当前标签页" })
vim.keymap.set("n", "<leader>rat", "<cmd>tabonly<cr>", { silent = true, desc = "仅保留当前标签页" })

-- 📜 消息与重载
vim.keymap.set("n", "<leader>i", "<cmd>messages<cr>", { silent = true, desc = "查看历史消息" })
vim.keymap.set("n", "<leader>toe", "<cmd>edit<cr>", { silent = true, desc = "重新加载当前 buffer" })
vim.keymap.set("n", "<leader>tor", "<cmd>restart<cr>", { silent = true, desc = "热重启 Neovim" })

-- 🔍 搜索
vim.keymap.set("x", "/", "<C-\\><C-n>`</\\%V", { desc = "在可视选区中正向搜索" })
vim.keymap.set("x", "?", "<C-\\><C-n>`>?\\%V", { desc = "在可视选区中反向搜索" })
vim.keymap.set(
	"n",
	"z/",
	'/\\%><C-r>=line("w0")-1<CR>l\\%<<C-r>=line("w$")+1<CR>l',
	{ silent = false, desc = "在当前视口中搜索" }
)

-- 📋 复制路径
vim.keymap.set("n", "<leader>yp", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
	print("Copied: " .. vim.fn.expand("%:p"))
end, { silent = true, desc = "复制绝对路径" })
vim.keymap.set("n", "<leader>yf", function()
	vim.fn.setreg("+", vim.fn.expand("%:f"))
	print("Copied: " .. vim.fn.expand("%:f"))
end, { silent = true, desc = "复制相对路径" })
vim.keymap.set("n", "<leader>yt", function()
	vim.fn.setreg("+", vim.fn.expand("%:t"))
	print("Copied: " .. vim.fn.expand("%:t"))
end, { silent = true, desc = "复制文件名" })

-- 🗂 标记操作
vim.keymap.set("n", "<leader>ram", function()
	vim.cmd("delmarks a-z")
	vim.cmd("delmarks A-Z")
end, { desc = "删除所有标记（大小写）" })

-- 🔢 工具
vim.keymap.set("n", "<leader>ob", function()
	require("user.bitcalc").bitcalc()
end, { desc = "打开位运算计算器" })

-- 📌 TODO 文件
local todo = require("user.todo")
vim.keymap.set("n", "<leader>tdl", function()
	todo.select_todo_file("current", function(choice)
		if choice then
			todo.open_todo_file(choice.path, true) -- 浮窗打开
		end
	end)
end, { desc = "打开 TODO 列表" })
vim.keymap.set("n", "<leader>tdc", function()
	todo.create_todo_file()
end, { desc = "创建新 TODO 文件" })
vim.keymap.set("n", "<leader>tdd", function()
	todo.select_todo_file("current", function(choice)
		if choice then
			todo.delete_todo_file(choice.path)
		end
	end)
end, { desc = "删除 TODO 文件" })

-- 🪟 窗口管理
vim.keymap.set("n", "<Leader>raw", function()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)
	local current_dir = vim.fn.fnamemodify(vim.fn.bufname(current_buf), ":p:h")
	local windows_to_close = {}
	for _, win_id in ipairs(vim.api.nvim_list_wins()) do
		if win_id ~= current_win then
			local buf_id = vim.api.nvim_win_get_buf(win_id)
			local buf_dir = vim.fn.fnamemodify(vim.fn.bufname(buf_id), ":p:h")
			if buf_dir ~= current_dir then
				table.insert(windows_to_close, win_id)
			end
		end
	end
	for _, win_id in ipairs(windows_to_close) do
		if vim.api.nvim_win_is_valid(win_id) then
			vim.api.nvim_win_close(win_id, true)
		end
	end
	print("Deleted windows outside the current directory!")
end, { silent = true, desc = "删除当前窗口外的所有窗口" })
