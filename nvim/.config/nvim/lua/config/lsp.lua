-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

-- LSP 配置模块
local M = {}

-- 设置诊断的全局配置
local icons = require("utils.utils").icons.diagnostic
M.diagnostic_config = function()
	vim.diagnostic.config({
		-- virtual_text = false,
		virtual_text = {
			current_line = false,
		},
		virtual_lines = {
			current_line = true,
		},
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
		update_in_insert = true,
	})
end

-- 高级诊断处理器：过滤掉非法（超出 buffer 行数）的诊断信息
M.diagnostic_handler = function()
	vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
		if not result then
			return
		end

		local uri = result.uri
		local bufnr = vim.uri_to_bufnr(uri)

		if not vim.api.nvim_buf_is_loaded(bufnr) then
			return -- buffer 未加载，跳过处理
		end

		local max_line = vim.api.nvim_buf_line_count(bufnr)

		-- 过滤出合法的诊断（行号不超过 buffer 最大行数）
		local valid_diagnostics = vim.tbl_filter(function(diag)
			local line = diag.range and diag.range.start and diag.range.start.line
			return type(line) == "number" and line < max_line
		end, result.diagnostics or {})
		-- 替换原始诊断结果
		result.diagnostics = valid_diagnostics
		-- 调用 Neovim 默认处理器
		vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
	end
end

-- 插入/选择模式禁用/启用诊断
M.mode_changed_handler = function()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			vim.diagnostic.enable(not vim.diagnostic.is_enabled())
		end,
	})
end

-- 插入模式下禁用内联提示，离开插入模式重新启用
M.inlay_hint_handler = function()
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
end

-- 按键映射
local diagnostics = require("config.diagnostics_keymap")
local keymaps = {
	{ "<leader>lq", diagnostics.open_all_diagnostics, "打开所有诊断（Quickfix）" },
	{ "<leader>ll", diagnostics.open_buffer_diagnostics, "打开当前 buffer 诊断（Loclist）" },
	-- { "<leader>ld", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
	{ "<leader>rl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭 LSP 客户端" },
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
	{ "<leader>yd", diagnostics.copy_diagnostics_under_cursor, "复制光标词的诊断信息" },
	{ "<leader>tol", diagnostics.restart_lsp, "重启 LSP" },
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

-- 设置按键映射
M.set_keymaps = function()
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { noremap = true, silent = true, desc = map[3] })
	end
end

-- 删除按键映射
M.remove_keymaps = function()
	for _, map in ipairs(keymaps) do
		vim.keymap.del("n", map[1])
	end
end

-- 导出模块
return M
