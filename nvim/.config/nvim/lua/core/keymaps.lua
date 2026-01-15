-- 📝 Basic operations
vim.keymap.set("n", "c", '"_c', { desc = "Basic: change to blackhole" })

-- TODO:ref:4bb713
-- vim.keymap.set("n", "dd", function()
-- 	return vim.fn.getline(".") == "" and '"_dd' or "dd"
-- end, { expr = true, desc = "Basic: delete line (empty → blackhole)" })

vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { silent = true, desc = "Basic: save buffer" })

vim.keymap.set("n", "<C-S-s>", function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd.write()
			end)
		end
	end
end, { silent = true, desc = "Save all modified buffers" })

-- https://github.com/elijah-potter/tatum
-- cargo install --git https://github.com/elijah-potter/tatum --locked
vim.keymap.set("n", "<leader>oo", function()
	vim.fn.jobstart({ "tatum", "serve", "--open", vim.fn.expand("%") }, { noremap = true, silent = true })
end)

-- vim.keymap.set("n", "<c-esc>", ":bd<cr>", { silent = true, desc = "Basic: close buffer" })
vim.keymap.set("n", "<c-esc>", function()
	require("user.utils").smart_close()
end, { silent = true, desc = "Smart close buffer/window" })

vim.keymap.set("n", "<leader>cab", function()
	local utils = require("user.utils")
	local current = vim.api.nvim_get_current_buf()

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
			local win = vim.fn.bufwinid(buf)
			if win ~= -1 then
				utils.smart_close(win)
			end
		end
	end
end, { silent = true, desc = "Close other buffers safely" })

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

-- 📜 Messages & reload
vim.keymap.set("n", "<leader>re", "<cmd>edit<cr>", { silent = true, desc = "Basic: reload buffer" })
vim.keymap.set("n", "<leader>rn", "<cmd>restart<cr>", { silent = true, desc = "Basic: restart Neovim" })

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

vim.api.nvim_set_keymap(
	"n",
	"<leader>fp",
	':lua require("user.ff_chain").open_project_chain()<CR>',
	{ noremap = true, silent = true }
)

-- 🪟 Window management
vim.keymap.set("n", "<Leader>caw", function()
	local utils = require("user.utils")
	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_win_get_buf(cur_win)
	local cur_dir = vim.fn.fnamemodify(vim.fn.bufname(cur_buf), ":p:h")

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= cur_win then
			local buf = vim.api.nvim_win_get_buf(win)
			local dir = vim.fn.fnamemodify(vim.fn.bufname(buf), ":p:h")
			if dir ~= cur_dir then
				utils.smart_close(win)
			end
		end
	end

	print("Deleted windows outside the current directory!")
end, { silent = true, desc = "Window: close outside windows" })
