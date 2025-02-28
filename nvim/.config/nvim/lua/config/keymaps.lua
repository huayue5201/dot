vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { desc = "向下移动选中的代码块" })
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { desc = "向上移动选中的代码块" })

vim.keymap.set("n", "c", '"_c', { desc = "修改并丢弃到黑洞寄存器" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "删除当前行（空行使用黑洞寄存器）" })

vim.keymap.set("n", "<leader>yp", function()
	local path = vim.fn.expand("%:p")
	vim.notify("绝对路径: " .. path, vim.log.levels.INFO)
	vim.fn.setreg("+", path)
end, { desc = "复制文件的绝对路径" })

vim.keymap.set("n", "<leader>yf", function()
	local path = vim.fn.expand("%:f")
	vim.notify("相对路径: " .. path, vim.log.levels.INFO)
	vim.fn.setreg("+", path)
end, { desc = "复制文件的相对路径" })

vim.keymap.set("n", "<leader>yt", function()
	local path = vim.fn.expand("%:t")
	vim.notify("文件名: " .. path, vim.log.levels.INFO)
	vim.fn.setreg("+", path)
end, { desc = "复制文件名" })

vim.keymap.set("n", "crc", "*``cgn", { desc = "修改当前选中文本" })

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "保存当前buffer" })

vim.keymap.set("n", "<leader>q", "<cmd>DeleteBuffer<cr>", { desc = "保存当前buffer" })

vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<cr>", { desc = "创建新的标签页" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<cr>", { desc = "关闭当前标签页" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<cr>", { desc = "仅保留当前标签页" })

vim.keymap.set("n", "dm", "<cmd>DelMarks<cr>", { desc = "删除当前标记" })
vim.keymap.set("n", "dam", "<cmd>DelAllMarks<cr>", { desc = "删除所有标记" })

vim.keymap.set("n", "<localleader>q", "<cmd>ToggleQuickfix<cr>", { desc = "切换 Quickfix 窗口" })

vim.keymap.set("n", "<localleader>l", "<cmd>ToggleLoclist<cr>", { desc = "切换 Loclist 窗口" })

vim.keymap.set("n", "<leader>lm", "<cmd>Messages<cr>", { desc = "查看历史消息" })

-- vim.keymap.set("i", "<Tab>", function()
--   local cursor = vim.api.nvim_win_get_cursor(0)
--   local line = vim.api.nvim_get_current_line()
--   local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
--   if next_char == nil then
--     return "<Tab>"
--   end
--   if not vim.tbl_contains({ '"', "'", ")", "]", "}" }, next_char) then
--     return "<Tab>"
--   end
--   return "<Right>"
-- end, { expr = true, desc = "插入模式下跳出括号或引号" })
