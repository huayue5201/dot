vim.keymap.set("n", "<localleader>elf", "<cmd>echo &filetype<cr>", { silent = true, desc = "调试: file类型" })
vim.keymap.set("n", "<localleader>elb", "<cmd>echo &buftype<cr>", { silent = true, desc = "调试: buffer类型" })

-- vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
local mc_ns = vim.api.nvim_create_namespace("nvim.multicursor")
vim.keymap.set("n", "<Esc>", function()
	-- 1. 清除 multicursor 的视觉标记
	vim.api.nvim_buf_clear_namespace(0, mc_ns, 0, -1)
	-- 2. 清除搜索高亮
	vim.cmd("nohlsearch")
end)

-- 📝 Basic operations
vim.keymap.set("n", "c", '"_c', { desc = "Basic: change to blackhole" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "Basic: delete line (empty → blackhole)" })

vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

vim.keymap.set("x", "i", function()
	if #vim.fn.getline(".") == 0 then
		return [["_cc]]
	else
		return "i"
	end
end, { expr = true })

vim.keymap.set("n", "p", "p`[v`]=")

vim.keymap.set("x", "y", function()
	local save = vim.fn.getpos(".")
	vim.cmd("normal! y")
	vim.fn.setpos(".", save)
end, { desc = "Yank: 保持光标位置" })

vim.keymap.set("n", "<localleader>s", "<cmd>w<cr>", { silent = true, desc = "Basic: save buffer" })

vim.keymap.set("n", "<localleader>as", function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd.write()
			end)
		end
	end
end, { silent = true, desc = "Save all modified buffers" })

vim.keymap.set("n", "<c-esc>", ":bp | bd #<cr>", { silent = true, desc = "Basic: close buffer" })

-- vim.keymap.set("n", "<leader>cab", function()
-- 	local current = vim.api.nvim_get_current_buf()
--
-- 	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
-- 		if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
-- 			local win = vim.fn.bufwinid(buf)
-- 			if win ~= -1 then
-- 				-- 直接关闭窗口，跳过 smart_close 的复杂逻辑
-- 				pcall(vim.api.nvim_win_close, win, { force = true })
-- 			else
-- 				-- 如果没有窗口显示该buffer，直接删除buffer
-- 				pcall(vim.api.nvim_buf_delete, buf, { force = false })
-- 			end
-- 		end
-- 	end
-- end, { silent = true, desc = "Close other buffers safely" })

-- vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { silent = true, desc = "更改为文件目录" })
-- local function undotree()
-- 	local close = require("undotree").open({
-- 		title = "undotree",
-- 		command = "topleft 48vnew",
-- 	})
-- 	if not close then
-- 		vim.bo.filetype = "undotree"
-- 	end
-- end
--
-- vim.keymap.set("n", "<leader>eu", undotree, { desc = "UndoTree: toggle undotree" })

vim.keymap.set("n", "<leader>rtw", function()
	local new_wrap = not vim.wo.wrap
	vim.wo.wrap = new_wrap
	print("Wrap " .. (new_wrap and "enabled" or "disabled"))
end, { desc = "Toggle line wrap" })

-- 🏷 Tab operaions
vim.keymap.set("n", "<leader>jtn", "<cmd>$tabnew<cr>", { silent = true, desc = "Tab: new tab" })
vim.keymap.set("n", "<leader>jth", ":-tabmove<CR>", {
	silent = true,
	desc = "Tab: 左移",
})
vim.keymap.set("n", "<leader>jtl", ":+tabmove<CR>", {
	noremap = true,
	silent = true,
	desc = "Tab: 右移",
})

vim.keymap.set("n", "<leader>ct", "<cmd>tabclose<cr>", { silent = true, desc = "Tab: close tab" })
vim.keymap.set("n", "<leader>cat", "<cmd>tabonly<cr>", { silent = true, desc = "Tab: close other tabs" })

-- 📜 Messages & reload
vim.keymap.set("n", "<leader>rte", "<cmd>edit<cr>", { silent = true, desc = "Basic: reload buffer" })

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

-- 🪟 Window management
-- vim.keymap.set("n", "<Leader>caw", function()
-- 	local nav = require("user.navigation")
-- 	local cur_win = vim.api.nvim_get_current_win()
-- 	local cur_buf = vim.api.nvim_win_get_buf(cur_win)
-- 	local cur_dir = vim.fn.fnamemodify(vim.fn.bufname(cur_buf), ":p:h")
--
-- 	for _, win in ipairs(vim.api.nvim_list_wins()) do
-- 		if win ~= cur_win then
-- 			local buf = vim.api.nvim_win_get_buf(win)
-- 			local dir = vim.fn.fnamemodify(vim.fn.bufname(buf), ":p:h")
-- 			if dir ~= cur_dir then
-- 				nav.smart_close(win)
-- 			end
-- 		end
-- 	end
--
-- 	print("Deleted windows outside the current directory!")
-- end, { silent = true, desc = "Window: close outside windows" })
