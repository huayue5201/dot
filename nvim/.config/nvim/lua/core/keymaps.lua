-- 📝 Basic operations
vim.keymap.set("n", "c", '"_c', { desc = "Basic: change to blackhole" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "Basic: delete line (empty → blackhole)" })

vim.keymap.set("n", "<c-s>", "<cmd>w<cr>", { silent = true, desc = "Basic: save buffer" })
vim.keymap.set("n", "<Leader>q", ":bd<cr>", { silent = true, desc = "Basic: close buffer" })

-- 🏷 Tab operations
vim.keymap.set("n", "<leader>ttn", "<cmd>$tabnew<cr>", { silent = true, desc = "Tab: new tab" })
vim.keymap.set("n", "<leader>rt", "<cmd>tabclose<cr>", { silent = true, desc = "Tab: close tab" })
vim.keymap.set("n", "<leader>rat", "<cmd>tabonly<cr>", { silent = true, desc = "Tab: close other tabs" })

-- 📜 Messages & reload
vim.keymap.set("n", "<leader>i", "<cmd>messages<cr>", { silent = true, desc = "Message: show messages" })
vim.keymap.set("n", "<leader>toe", "<cmd>edit<cr>", { silent = true, desc = "Basic: reload buffer" })
vim.keymap.set("n", "<leader>tor", "<cmd>restart<cr>", { silent = true, desc = "Basic: restart Neovim" })

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
vim.keymap.set("n", "<leader>ram", function()
	vim.cmd("delmarks a-z")
	vim.cmd("delmarks A-Z")
end, { desc = "Mark: delete all marks" })

-- 🔢 Tools
vim.keymap.set("n", "<leader>ob", function()
	require("user.bitcalc").bitcalc()
end, { desc = "Tool: bit calculator" })

-- 📌 TODO
local todo = require("user.todo")

vim.keymap.set("n", "<leader>tdl", function()
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

-- 🪟 Window management
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
end, { silent = true, desc = "Window: close outside windows" })
