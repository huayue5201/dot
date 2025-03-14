vim.keymap.set("v", "J", ":m '>+1<cr>gv=gv", { noremap = true, silent = true, desc = "向下移动选中的代码块" })
vim.keymap.set("v", "K", ":m '<-2<cr>gv=gv", { noremap = true, silent = true, desc = "向上移动选中的代码块" })

vim.keymap.set("n", "c", '"_c', { desc = "修改并丢弃到黑洞寄存器" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "删除当前行（空行使用黑洞寄存器）" })

-- 将绝对路径复制到剪贴板
vim.keymap.set("n", "<leader>ya", ':let @+ = expand("%:p")<CR>')
-- 将相对路径复制到剪贴板
vim.keymap.set("n", "<leader>yr", ':let @+ = expand("%:f")<CR>')
-- 将文件名复制到剪贴板
vim.keymap.set("n", "<leader>yf", ':let @+ = expand("%:t")<CR>')

vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { noremap = true, silent = true, desc = "更改为文件目录" })

vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { noremap = true, silent = true, desc = "保存当前buffer" })

vim.keymap.set("n", "<leader>q", "<cmd>bdelete<cr>", { noremap = true, silent = true, desc = "保存当前buffer" })

vim.keymap.set("n", "<leader>tn", "<cmd>$tabnew<cr>", { noremap = true, silent = true, desc = "创建新的标签页" })
vim.keymap.set(
	"n",
	"<leader>tc",
	"<cmd>tabclose<cr>",
	{ noremap = true, silent = true, desc = "关闭当前标签页" }
)
vim.keymap.set(
	"n",
	"<leader>to",
	"<cmd>tabonly<cr>",
	{ noremap = true, silent = true, desc = "仅保留当前标签页" }
)

-- vim.keymap.set("n", "<localleader>q", "<cmd>ToggleQuickfix<cr>", { desc = "切换 Quickfix 窗口" })

-- vim.keymap.set("n", "<localleader>l", "<cmd>ToggleLoclist<cr>", { desc = "切换 Loclist 窗口" })

vim.keymap.set("n", "<leader>lm", "<cmd>Messages<cr>", { noremap = true, silent = true, desc = "查看历史消息" })

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
