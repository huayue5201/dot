-- 📝 Basic operations
vim.keymap.set("n", "c", '"_c', { desc = "Basic: change to blackhole" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "Basic: delete line (empty → blackhole)" })

vim.keymap.set("n", "<c-s>", "<cmd>w<cr>", { silent = true, desc = "Basic: save buffer" })

-- vim.keymap.set("n", "<c-esc>", ":bd<cr>", { silent = true, desc = "Basic: close buffer" })
vim.keymap.set("n", "<c-esc>", function()
	local current_buf = vim.api.nvim_get_current_buf() -- 获取当前缓冲区ID
	local filetype = vim.bo[current_buf].filetype -- 获取当前缓冲区的filetype
	local buftype = vim.bo[current_buf].buftype -- 获取当前缓冲区的buftype
	-- 检查 M.buf_keymaps 中是否有对应的关闭命令
	local conf = require("user.utils").buf_keymaps["q"]
	-- 查找命令：优先检查文件类型和缓冲区类型
	local command = conf[filetype] or conf[buftype] or conf[filetype] or conf[buftype]
	if command then
		-- 如果找到对应的命令，执行该命令
		if type(command.cmd) == "function" then
			command.cmd() -- 执行函数命令
		else
			vim.cmd(command.cmd) -- 执行字符串命令
		end
	else
		-- 如果没有找到对应的命令，执行默认的 bdelete 命令
		vim.cmd(":bd") -- 默认关闭缓冲区
	end
end, { silent = true, desc = "Close buffer using defined commands or default" })

-- vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { silent = true, desc = "更改为文件目录" })
vim.cmd("packadd nvim.undotree")
local function undotree()
	local close = require("undotree").open({
		title = "undotree",
		command = "topleft 48vnew",
	})
	if not close then
		vim.bo.filetype = "undotree"
	end
end

vim.keymap.set("n", "<leader>eu", undotree, { desc = "UndoTree: toggle undotree" })

-- 🏷 Tab operations
vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<cr>", { silent = true, desc = "Tab: new tab" })
vim.api.nvim_set_keymap("n", "<leader>tmh", ":-tabmove<CR>", {
	noremap = true,
	silent = true,
	desc = "Tab: 左移",
})
vim.keymap.set("n", "<leader>tml", ":+tabmove<CR>", {
	noremap = true,
	silent = true,
	desc = "Tab: 右移",
})
vim.keymap.set("n", "<leader>ct", "<cmd>tabclose<cr>", { silent = true, desc = "Tab: close tab" })
vim.keymap.set("n", "<leader>cat", "<cmd>tabonly<cr>", { silent = true, desc = "Tab: close other tabs" })

local function close_other_buffers_safely()
	local current_buf = vim.api.nvim_get_current_buf()
	local all_buffers = vim.api.nvim_list_bufs()

	for _, buf in ipairs(all_buffers) do
		if
			buf ~= current_buf
			and vim.api.nvim_buf_is_valid(buf)
			and vim.api.nvim_buf_is_loaded(buf)
			and vim.bo[buf].buftype == ""
		then
			-- 获取文件类型和缓冲区类型
			local filetype = vim.bo[buf].filetype
			local buftype = vim.bo[buf].buftype

			-- 从 M.buf_keymaps 中查找关闭命令
			local conf = require("user.utils").buf_keymaps["q"]
			local command = conf[filetype] or conf[buftype] or conf[filetype] or conf[buftype]

			if command then
				-- 如果找到命令，执行命令
				if type(command.cmd) == "function" then
					command.cmd() -- 执行函数命令
				else
					vim.cmd(command.cmd) -- 执行命令字符串
				end
			else
				-- 如果没有找到对应命令，执行默认的关闭命令
				vim.cmd("confirm bd " .. buf) -- 有未保存修改才交互确认，没修改直接关闭
			end
		end
	end
end

vim.keymap.set("n", "<leader>cab", close_other_buffers_safely, {
	noremap = true,
	silent = true,
	desc = "Safely close other buffers without breaking LSP",
})

-- 📜 Messages & reload
vim.keymap.set("n", "<leader>i", "<cmd>messages<cr>", { silent = true, desc = "Message: show messages" })
vim.keymap.set("n", "<leader>re", "<cmd>edit<cr>", { silent = true, desc = "Basic: reload buffer" })
vim.keymap.set("n", "<leader>rr", "<cmd>restart<cr>", { silent = true, desc = "Basic: restart Neovim" })

-- 🔍 Search
vim.keymap.set("x", "/", "<C-\\><C-n>`</\\%V", { desc = "Search: forward in visual range" })
vim.keymap.set("x", "?", "<C-\\><C-n>`>?\\%V", { desc = "Search: backward in visual range" })
vim.keymap.set(
	"n",
	"z/",
	'/\\%><C-r>=line("w0")-1<CR>l\\%<<C-r>=line("w$")+1<CR>l',
	{ silent = false, desc = "Search: within viewport" }
)

-- 📋 Copy path
vim.keymap.set("n", "<leader>yp", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
	print("Copied: " .. vim.fn.expand("%:p"))
end, { silent = true, desc = "Path: copy absolute" })

vim.keymap.set("n", "<leader>yf", function()
	vim.fn.setreg("+", vim.fn.expand("%:f"))
	print("Copied: " .. vim.fn.expand("%:f"))
end, { silent = true, desc = "Path: copy relative" })

vim.keymap.set("n", "<leader>yt", function()
	vim.fn.setreg("+", vim.fn.expand("%:t"))
	print("Copied: " .. vim.fn.expand("%:t"))
end, { silent = true, desc = "Path: copy filename" })

-- 🗂 Marks
vim.keymap.set("n", "<leader>cam", function()
	vim.cmd("delmarks a-z")
	vim.cmd("delmarks A-Z")
end, { desc = "Mark: delete all marks" })

-- 📌 TODO
local todo = require("user.todo")

vim.keymap.set("n", "<leader>tdo", function()
	todo.select_todo_file("current", function(choice)
		if choice then
			todo.open_todo_file(choice.path, true)
		end
	end)
end, { desc = "TODO: open list" })

vim.keymap.set("n", "<leader>tdc", function()
	todo.create_todo_file()
end, { desc = "TODO: create file" })

vim.keymap.set("n", "<leader>tdd", function()
	todo.select_todo_file("current", function(choice)
		if choice then
			todo.delete_todo_file(choice.path)
		end
	end)
end, { desc = "TODO: delete file" })

vim.api.nvim_set_keymap(
	"n",
	"<leader>fp",
	':lua require("user.ff_chain").open_project_chain()<CR>',
	{ noremap = true, silent = true }
)

-- 🪟 Window management
vim.keymap.set("n", "<Leader>caw", function()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_win_get_buf(current_win)
	local current_dir = vim.fn.fnamemodify(vim.fn.bufname(current_buf), ":p:h")

	local windows_to_close = {}
	for _, win_id in ipairs(vim.api.nvim_list_wins()) do
		if win_id ~= current_win then
			local buf_id = vim.api.nvim_win_get_buf(win_id)
			local buf_dir = vim.fn.fnamemodify(vim.fn.bufname(buf_id), ":p:h")
			-- 根据目录判断是否需要关闭
			if buf_dir ~= current_dir then
				table.insert(windows_to_close, win_id)
			end
		end
	end
	-- 查找关闭命令的逻辑
	local conf = require("user.utils").buf_keymaps["q"]
	for _, win_id in ipairs(windows_to_close) do
		if vim.api.nvim_win_is_valid(win_id) then
			local buf_id = vim.api.nvim_win_get_buf(win_id)
			local filetype = vim.bo[buf_id].filetype
			local buftype = vim.bo[buf_id].buftype
			-- 查找命令：优先匹配文件类型和缓冲区类型
			local command = conf[filetype] or conf[buftype] or conf[filetype] or conf[buftype]
			if command then
				-- 如果找到命令，执行该命令
				if type(command.cmd) == "function" then
					command.cmd() -- 执行函数命令
				else
					vim.cmd(command.cmd) -- 执行命令字符串
				end
			else
				-- 如果没有找到对应命令，执行默认的关闭命令
				vim.api.nvim_win_close(win_id, true) -- 默认关闭窗口
			end
		end
	end
	print("Deleted windows outside the current directory!")
end, { silent = true, desc = "Window: close outside windows" })
