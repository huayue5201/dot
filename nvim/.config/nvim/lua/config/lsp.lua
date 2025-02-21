local M = {}

-- 缓存 LSP 客户端支持的方法，减少频繁查询
local function get_supported_lsp_methods(buf)
	local supported_methods = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
		if client:supports_method("textDocument/documentHighlight") then
			supported_methods.documentHighlight = true
		end
		if client:supports_method("textDocument/foldingRange") then
			supported_methods.foldingRange = true
		end
	end
	return supported_methods
end

-- 设置诊断的全局配置
local function setup_global_diagnostics()
	vim.diagnostic.config({
		virtual_text = { spacing = 4, source = "if_many", prefix = "■" },
		severity_sort = true,
		virtual_lines = { current_line = true },
		float = { source = "if_many", border = "rounded" },
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "✘",
				[vim.diagnostic.severity.WARN] = "▲",
				[vim.diagnostic.severity.HINT] = "⚑",
				[vim.diagnostic.severity.INFO] = "»",
			},
			linehl = { [vim.diagnostic.severity.ERROR] = "ErrorMsg" },
			numhl = { [vim.diagnostic.severity.WARN] = "WarningMsg" },
		},
		underline = true,
		update_in_insert = false,
	})
end

-- 设置按键映射
local function set_keymaps(buf, supported_methods)
	local keymaps = {
		{ "<leader>od", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
		{ "<leader>cl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" },
		{
			"<leader>wl",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
			"列出工作区文件夹",
		},
		{
			"<leader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
			"开启/关闭内联提示",
		},
	}
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { buffer = buf, noremap = true, silent = true, desc = map[3] })
	end
end

-- 设置高亮符号功能
local function setup_highlight_symbol(buf, supported_methods)
	if not supported_methods.documentHighlight then
		return
	end
	local group_name = "highlight_symbol"
	local group = vim.api.nvim_create_augroup(group_name, { clear = false })
	vim.api.nvim_clear_autocmds({ buffer = buf, group = group })
	-- 高亮符号：光标停留时
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		buffer = buf,
		callback = function()
			vim.defer_fn(function()
				local success, err = pcall(vim.lsp.buf.document_highlight)
				if not success then
					print("LSP document_highlight error: " .. err)
				end
			end, 50)
		end,
	})
	-- 清除高亮：光标移动时
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			vim.defer_fn(function()
				local success, err = pcall(vim.lsp.buf.clear_references)
				if not success then
					print("LSP clear_references error: " .. err)
				end
			end, 50)
		end,
	})
end

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
	-- 创建 LspAttach 自动命令
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
		callback = function(args)
			-- vim.lsp.completion.enable(true, args.data.client_id, args.buf)
			local buf = args.buf
			local supported_methods = get_supported_lsp_methods(buf)
			-- 设置按键映射、符号高亮和折叠功能
			set_keymaps(buf, supported_methods)
			setup_highlight_symbol(buf, supported_methods)
			setup_folding(buf, supported_methods)
		end,
	})
end

return M
