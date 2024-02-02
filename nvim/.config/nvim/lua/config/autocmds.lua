-- 光标自动定位到最后编辑的位置
vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = "*",
	callback = function()
		local last_cursor_line = vim.fn.line("'\"")
		local last_buffer_line = vim.fn.line("$")
		-- 检查光标位置是否保存并在文件内
		if last_cursor_line > 0 and last_cursor_line <= last_buffer_line then
			-- 恢复光标位置
			vim.fn.setpos(".", vim.fn.getpos("'\""))
			-- 静默打开折叠
			vim.cmd("silent! foldopen")
		end
	end,
})
-- 可选：添加错误处理
if vim.api.nvim_get_mode().mode == "n" then
	assert(vim.fn.exists("#BufReadPost"), "自动命令创建失败！")
end

--================
-- 创建高亮组并添加 TextYankPost 自动命令
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
-- 添加 TextYankPost 自动命令
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

--================
-- Toggle hlsearch based on specific keys in Normal mode
if vim.g.enabled_toggle_hlsearch then
	return
end
vim.g.enabled_toggle_hlsearch = true
local function toggle_hlsearch(char)
	-- Check if in Normal mode
	if vim.fn.mode() == "n" then
		local toggle_keys = { "<CR>", "n", "N", "*", "#", "?", "/" }
		local should_toggle = vim.tbl_contains(toggle_keys, vim.fn.keytrans(char))
		-- Toggle hlsearch if needed
		if vim.opt.hlsearch:get() ~= should_toggle then
			vim.opt.hlsearch = should_toggle
		end
	end
end
-- Register the key handler for toggling hlsearch
vim.on_key(toggle_hlsearch, vim.api.nvim_create_namespace("toggle_hlsearch"))
