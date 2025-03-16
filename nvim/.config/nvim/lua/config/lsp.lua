-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}

-- 缓存 LSP 客户端支持的方法，减少频繁查询
local function get_supported_lsp_methods(buf)
	local supported_methods = {}
	local clients = vim.lsp.get_clients({ bufnr = buf })
	if #clients > 0 then
		for _, client in ipairs(clients) do
			supported_methods.documentHighlight = supported_methods.documentHighlight
				or client:supports_method("textDocument/documentHighlight")
			supported_methods.foldingRange = supported_methods.foldingRange
				or client:supports_method("textDocument/foldingRange")
		end
	end
	return supported_methods
end

-- 设置诊断的全局配置
local function setup_global_diagnostics()
	local icons = require("config.utils").icons.diagnostic
	vim.diagnostic.config({
		-- virtual_text = { spacing = 4, source = "if_many", prefix = "■" },-- Could be '●', '▎', 'x'
		virtual_text = false,
		severity_sort = true,
		-- virtual_lines = { current_line = true },
		float = { source = "if_many", border = "shadow" }, -- 诊断浮窗设置
		-- signs = false,
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

	-- Can be one of the pre-defined styles: `"double"`, `"none"`, `"rounded"`, `"shadow"`, `"single"` or `"solid"`.
	-- hover UI
	local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
	---@diagnostic disable-next-line: duplicate-set-field
	function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
		opts = opts or {}
		opts.border = "rounded" -- Or any other border
		return orig_util_open_floating_preview(contents, syntax, opts, ...)
	end

	-- 插入模式下立刻更新诊断信息
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s" },
		desc = "Disable diagnostics in insert and select mode",
		callback = function()
			vim.diagnostic.enable(not vim.diagnostic.is_enabled())
		end,
	})
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = "i:n",
		desc = "Enable diagnostics when leaving insert mode",
		callback = function()
			vim.diagnostic.enable(not vim.diagnostic.is_enabled())
		end,
	})
end

-- 设置按键映射
local function set_keymaps(buf, _)
	local keymaps = {
		{ "<leader>ld", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
		{ "<leader>cl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" },
		{
			"<localleader>d",
			"<cmd>lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>",
			"打开/关闭LSP诊断",
		},
		{
			"<leader>lw",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
			"列出工作区文件夹",
		},
		{
			"<leader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
			"打开/关闭内联提示",
		},
	}
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { buffer = buf, noremap = true, silent = true, desc = map[3] })
	end
end

-- -- 设置高亮符号功能
-- local function setup_highlight_symbol(buf, supported_methods)
-- 	if not supported_methods.documentHighlight then
-- 		return
-- 	end
-- 	local group_name = "highlight_symbol"
-- 	local group = vim.api.nvim_create_augroup(group_name, { clear = false })
-- 	vim.api.nvim_clear_autocmds({ buffer = buf, group = group })
-- 	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
-- 		group = group,
-- 		buffer = buf,
-- 		callback = function()
-- 			vim.defer_fn(function()
-- 				local success, err = pcall(vim.lsp.buf.document_highlight)
-- 				if not success then
-- 					print("LSP document_highlight error: " .. err)
-- 				end
-- 			end, 50)
-- 		end,
-- 	})
-- 	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
-- 		group = group,
-- 		buffer = buf,
-- 		callback = function()
-- 			vim.defer_fn(function()
-- 				local success, err = pcall(vim.lsp.buf.clear_references)
-- 				if not success then
-- 					print("LSP clear_references error: " .. err)
-- 				end
-- 			end, 50)
-- 		end,
-- 	})
-- end

-- 设置折叠功能
local function setup_folding(buf, supported_methods)
	if supported_methods.foldingRange then
		local win_id = vim.fn.bufwinid(buf)
		if win_id ~= -1 then
			vim.api.nvim_set_option_value("foldmethod", "expr", { win = win_id })
			vim.api.nvim_set_option_value("foldexpr", "v:lua.vim.lsp.foldexpr()", { win = win_id })
		end
	end
end

-- LSP 主设置函数
M.lspSetup = function()
	setup_global_diagnostics()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
		callback = function(args)
			local buf = args.buf
			local supported_methods = get_supported_lsp_methods(buf)
			set_keymaps(buf, supported_methods)
			-- setup_highlight_symbol(buf, supported_methods)
			setup_folding(buf, supported_methods)
		end,
	})
end

return M
