-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

-- 设置诊断的全局配置
local icons = require("utils.utils").icons.diagnostic
vim.diagnostic.config({
	virtual_text = false,
	severity_sort = true,
	float = { source = "if_many", border = "shadow" },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = icons.ERROR,
			[vim.diagnostic.severity.WARN] = icons.WARN,
			[vim.diagnostic.severity.HINT] = icons.HINT,
			[vim.diagnostic.severity.INFO] = icons.INFO,
		},
		linehl = { [vim.diagnostic.severity.ERROR] = "ErrorMsg" },
		numhl = { [vim.diagnostic.severity.WARN] = "WarningMsg" },
	},
	underline = true,
	update_in_insert = false,
})

-- 修改浮动窗口的边框样式
local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
	opts = opts or {}
	opts.border = "rounded"
	return orig_util_open_floating_preview(contents, syntax, opts, ...)
end

-- 插入模式下禁用/启用诊断信息
vim.api.nvim_create_autocmd("ModeChanged", {
	pattern = { "n:i", "v:s", "i:n" },
	desc = "插入/选择模式禁用/启用诊断",
	callback = function()
		vim.diagnostic.enable(not vim.diagnostic.is_enabled())
	end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
	desc = "Disable lsp.inlay_hint when in insert mode",
	callback = function(args)
		local filter = { bufnr = args.buf }
		local inlay_hint = vim.lsp.inlay_hint
		if inlay_hint.is_enabled(filter) then
			inlay_hint.enable(false, filter)
			vim.api.nvim_create_autocmd("InsertLeave", {
				once = true,
				desc = "Re-enable lsp.inlay_hint when leaving insert mode",
				callback = function()
					inlay_hint.enable(true, filter)
				end,
			})
		end
	end,
})

vim.cmd([[
autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh({ bufnr = 0 })
]])

-- 设置按键映射
local keymaps = {
	{ "<leader>ld", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
	{ "<leader>rl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭 LSP 客户端" },
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
	{
		"<leader>yd",
		function()
			local bufnr = 0
			local cursor = vim.api.nvim_win_get_cursor(0)
			local row, col = cursor[1] - 1, cursor[2]
			local word = vim.fn.expand("<cword>")
			local diagnostics = vim.diagnostic.get(bufnr)

			local severity_map = {
				[vim.diagnostic.severity.ERROR] = "Error",
				[vim.diagnostic.severity.WARN] = "Warning",
				[vim.diagnostic.severity.INFO] = "Info",
				[vim.diagnostic.severity.HINT] = "Hint",
			}

			local function format(diag)
				local severity = severity_map[diag.severity] or "Unknown"
				local source = diag.source or "LSP"
				return string.format("[%s] %s (from %s)", severity, diag.message, source)
			end

			local matched = {}
			for _, diag in ipairs(diagnostics) do
				local s_row, s_col = diag.lnum, diag.col
				local e_row, e_col = diag.end_lnum or s_row, diag.end_col or s_col + 1
				local in_range = (row > s_row or (row == s_row and col >= s_col))
					and (row < e_row or (row == e_row and col < e_col))
				if in_range or diag.message:find(word, 1, true) then
					table.insert(matched, format(diag))
				end
			end

			if #matched > 0 then
				local content = table.concat(matched, "\n")
				vim.fn.setreg("+", content)
				vim.notify("诊断信息已复制到剪贴板!", vim.log.levels.INFO)
			else
				vim.notify("无诊断信息", vim.log.levels.INFO)
			end
		end,
		"复制光标词的诊断信息",
	},
	{
		"<leader>tol",
		function()
			for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
				vim.lsp.stop_client(client.id)
			end
			-- 重新加载当前缓冲区
			vim.defer_fn(function()
				vim.cmd("edit")
			end, 100)
		end,
		"重启 LSP",
	},
	{
		"<leader>tod",
		"<cmd>lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>",
		"打开/关闭 LSP 诊断",
	},
	{
		"<leader>lw",
		"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
		"列出工作区文件夹",
	},
	{
		"<leader>toi",
		"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
		"打开/关闭内联提示",
	},
}

for _, map in ipairs(keymaps) do
	vim.keymap.set("n", map[1], map[2], { noremap = true, silent = true, desc = map[3] })
end
