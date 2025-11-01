vim.keymap.set("n", "<A-k>", ":move .-2<CR>==", { noremap = true, silent = true })
vim.keymap.set("x", "<A-k>", ":move '<-2<CR>gv=gv", { noremap = true, silent = true })

vim.keymap.set("n", "<A-j>", ":move .+1<CR>==", { noremap = true, silent = true })
vim.keymap.set("x", "<A-j>", ":move '>+1<CR>gv=gv", { noremap = true, silent = true })

vim.keymap.set("n", "c", '"_c', { desc = "修改并丢弃到黑洞寄存器" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "删除当前行（空行使用黑洞寄存器）" })

vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { silent = true, desc = "更改为文件目录" })

vim.keymap.set("n", "<c-s>", "<cmd>w<cr>", { silent = true, desc = "保存buffer" })

vim.keymap.set("n", "<Leader>q", ":bd<cr>", { silent = true, desc = "退出buffer" })

vim.keymap.set("n", "<leader>ttn", "<cmd>$tabnew<cr>", { silent = true, desc = "创建新的标签页" })

vim.keymap.set("n", "<leader>rt", "<cmd>tabclose<cr>", { silent = true, desc = "关闭当前标签页" })

vim.keymap.set("n", "<leader>rat", "<cmd>tabonly<cr>", { silent = true, desc = "仅保留当前标签页" })

vim.keymap.set("n", "<leader>lm", "<cmd>messages<cr>", { silent = true, desc = "查看历史消息" })

vim.keymap.set("n", "<a-q>", "<cmd>Toggle quickfix<cr>", { desc = "Toggle Quickfix" })

vim.keymap.set("n", "<a-l>", "<cmd>Toggle loclist<cr>", { desc = "Toggle Loclist" })

local lsp = require("config.lsp")
vim.keymap.set("n", "<leader>tol", lsp.restart_lsp, { silent = true, desc = "重启 LSP" })
vim.keymap.set("n", "<leader>rl", lsp.stop_lsp, { silent = true, desc = "关闭 LSP" })
vim.keymap.set("n", "<leader>ll", lsp.open_buffer_diagnostics, { desc = "查看 buffer 诊断（Loclist）" })
vim.keymap.set("n", "<leader>lq", lsp.open_all_diagnostics, { desc = "打开所有诊断（Quickfix）" })
vim.keymap.set("n", "<leader>yd", lsp.CopyErrorMessage, { desc = "复制诊断信息" })

vim.keymap.set(
	"n",
	"<leader>tod",
	"<cmd>lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>",
	{ desc = "打开/关闭 LSP 诊断" }
)

vim.keymap.set("n", "<leader>toe", "<cmd>edit<cr>", { silent = true, desc = "重新加载当前buffer" })
vim.keymap.set("n", "<leader>tor", "<cmd>restart<cr>", { silent = true, desc = "热重启nvim" })

-- 在可视选区内正向搜索
vim.keymap.set("x", "/", "<C-\\><C-n>`</\\%V", { desc = "在可视选区中正向搜索" })

-- 在可视选区内反向搜索
vim.keymap.set("x", "?", "<C-\\><C-n>`>?\\%V", { desc = "在可视选区中反向搜索" })

-- 在当前窗口可见区域中搜索
vim.keymap.set(
	"n",
	"z/",
	'/\\%><C-r>=line("w0")-1<CR>l\\%<<C-r>=line("w$")+1<CR>l',
	{ silent = false, desc = "在当前视口中搜索" }
)

-- 加载 undotree 插件
vim.cmd("packadd nvim.undotree")
vim.keymap.set("n", "<leader>eu", function()
	require("undotree").open({
		command = "set nosplitright | 40vnew | set splitright<",
	})
end, { desc = "打开撤销树" })

vim.keymap.set("n", "<leader>eo", function()
	require("utils.cross_config").choose_chip()
end, { desc = "配置切换" })

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

vim.keymap.set("n", "<leader>ram", function()
	vim.cmd("delmarks a-z")
	vim.cmd("delmarks A-Z")
end, { desc = "Delete all marks (lowercase and uppercase)" })

vim.keymap.set("n", "<leader>ob", function()
	require("utils.bitcalc").bitcalc()
end, { desc = "打开位运算计算器" })

local todo = require("utils.todo")
vim.keymap.set("n", "<leader>tdl", function()
	todo.select_todo_file("current", function(choice)
		if choice then
			todo.open_todo_file(choice.path, true) -- 浮窗打开
		end
	end)
end, { desc = "打开todo列表" })

-- 创建新 TODO 文件
vim.keymap.set("n", "<leader>tdc", function()
	todo.create_todo_file()
end, { desc = "创建新 TODO 文件" })

-- 删除 TODO 文件
vim.keymap.set("n", "<leader>tdd", function()
	todo.select_todo_file("current", function(choice)
		if choice then
			todo.delete_todo_file(choice.path)
		end
	end)
end, { desc = "删除 TODO 文件" })

vim.keymap.set("n", "<Leader>raw", function()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)
	local current_dir = vim.fn.fnamemodify(vim.fn.bufname(current_buf), ":p:h") -- 获取当前缓冲区的目录
	-- 收集所有要删除的窗口ID
	local windows_to_close = {}
	-- 遍历所有窗口
	for _, win_id in ipairs(vim.api.nvim_list_wins()) do
		if win_id ~= current_win then
			local buf_id = vim.api.nvim_win_get_buf(win_id)
			local buf_dir = vim.fn.fnamemodify(vim.fn.bufname(buf_id), ":p:h") -- 获取窗口缓冲区的目录
			-- 如果缓冲区不在当前目录，则将该窗口标记为待删除
			if buf_dir ~= current_dir then
				table.insert(windows_to_close, win_id)
			end
		end
	end
	-- 删除待删除的窗口（确保每个窗口 ID 是有效的）
	for _, win_id in ipairs(windows_to_close) do
		if vim.api.nvim_win_is_valid(win_id) then
			vim.api.nvim_win_close(win_id, true) -- 关闭该窗口
		end
	end
	print("Deleted windows outside the current directory!")
end, { silent = true, desc = "删除当前窗口外的所有窗口" })
