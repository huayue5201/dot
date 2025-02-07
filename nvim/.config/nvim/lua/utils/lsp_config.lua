-- lua/user/lsp_config.lua
local M = {}

-- 缓存 LSP 客户端支持的方法，减少频繁查询
local function get_supported_lsp_methods(buf)
	local supported_methods = {}
	local clients = vim.lsp.get_clients({ bufnr = buf })
	for _, client in ipairs(clients) do
		if client:supports_method("textDocument/documentHighlight") then
			supported_methods.documentHighlight = true
		end
		if client:supports_method("textDocument/foldingRange") then
			supported_methods.foldingRange = true
		end
	end
	return supported_methods
end

-- 设置按键映射的通用函数
local function set_keymaps(mappings, opts)
	opts = opts or { noremap = true, silent = true }
	for _, map in ipairs(mappings) do
		vim.keymap.set(map[1], map[2], map[3], vim.tbl_extend("force", opts, { desc = map[4] }))
	end
end

-- 设置全局按键映射
local function setup_global_keymaps()
	local mappings = {
		{ "n", "<leader>od", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
		{ "n", "<leader>ds", "<cmd>lua vim.diagnostic.setqflist()<cr>", "打开快速修复列表" },
		{ "n", "<leader>cl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" },
		{
			"n",
			"<leader>wl",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
			"列出工作区文件夹",
		},
	}
	set_keymaps(mappings)
end

-- 设置缓冲区特定的按键映射
local function setup_keymaps(buf)
	local mappings = {
		{
			"n",
			"<leader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
			"开启/关闭内联提示",
		},
	}
	set_keymaps(mappings, { buffer = buf })
end

-- 设置诊断的全局配置
local function setup_global_diagnostics()
	vim.diagnostic.config({
		virtual_text = { spacing = 4, source = "if_many", prefix = "■" },
		float = { source = "if_many", border = "rounded" },
		signs = {
			text = {
				-- 错误（ERROR）的标志文本为空
				[vim.diagnostic.severity.ERROR] = "",
				-- 警告（WARN）的标志文本为空
				[vim.diagnostic.severity.WARN] = "",
			},
			linehl = {
				-- 错误的行高亮使用 'ErrorMsg' 样式
				[vim.diagnostic.severity.ERROR] = "ErrorMsg",
			},
			numhl = {
				-- 警告的行号高亮使用 'WarningMsg' 样式
				[vim.diagnostic.severity.WARN] = "WarningMsg",
			},
		},
	})
	-- vim.diagnostic.config({
	-- 	virtual_text = { spacing = 4, source = "if_many", prefix = "■" },
	-- 	float = { source = "if_many", border = "rounded" },
	-- 	signs = {
	-- 		text = {
	-- 			[vim.diagnostic.severity.ERROR] = "✘",
	-- 			[vim.diagnostic.severity.WARN] = "▲",
	-- 			[vim.diagnostic.severity.HINT] = "⚑",
	-- 			[vim.diagnostic.severity.INFO] = "»",
	-- 		},
	-- 	},
	-- 	underline = true,
	-- 	update_in_insert = false,
	-- 	severity_sort = true,
	-- })
end

-- 高亮符号设置
local function setup_highlight_symbol(buf)
	local supported_methods = get_supported_lsp_methods(buf)
	if not supported_methods.documentHighlight then
		return
	end
	local group_name = "highlight_symbol"
	local group = vim.api.nvim_create_augroup(group_name, { clear = false })
	vim.api.nvim_clear_autocmds({ buffer = buf, group = group })
	-- 光标停留时高亮
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		buffer = buf,
		callback = function()
			if supported_methods.documentHighlight then
				vim.defer_fn(function()
					local success, err = pcall(vim.lsp.buf.document_highlight)
					if not success then
						print("LSP document_highlight error: " .. err)
					end
				end, 50)
			end
		end,
	})
	-- 光标移动时清除高亮
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			if supported_methods.documentHighlight then
				vim.defer_fn(function()
					local success, err = pcall(vim.lsp.buf.clear_references)
					if not success then
						print("LSP clear_references error: " .. err)
					end
				end, 50)
			end
		end,
	})
end

-- 设置折叠功能
local function setup_folding(buf, _)
	local supported_methods = get_supported_lsp_methods(buf)
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
	setup_global_keymaps()

	-- 创建 LspAttach 自动命令
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
		callback = function(args)
			local buf = args.buf
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			setup_keymaps(buf)
			setup_highlight_symbol(buf)
			setup_folding(buf, client)
		end,
	})
end

return M
