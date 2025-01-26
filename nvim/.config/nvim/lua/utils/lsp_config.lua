-- lua/user/lsp_config.lua

local M = {}

-- 设置全局按键映射（仅初始化一次）
local function setup_global_keymaps()
	local mappings = {
		{ "n", "<leader>od", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" }, -- 打开当前缓冲区的诊断信息列表
		{ "n", "<leader>ds", "<cmd>lua vim.diagnostic.setqflist()<cr>", "打开快速修复列表" }, -- 打开快速修复列表
		{ "n", "<leader>cl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" }, -- 停止所有LSP客户端
		{
			"n",
			"<leader>wl",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
			"列出工作区文件夹",
		}, -- 列出工作区文件夹
	}

	-- 设置全局快捷键映射
	for _, map in ipairs(mappings) do
		-- 这些映射只需要初始化一次，可以放在 LspAttach 之前设置
		vim.keymap.set(map[1], map[2], map[3], { noremap = true, silent = true, desc = map[4] })
	end
end

-- 设置每个缓冲区的按键映射
local function setup_keymaps(buf)
	local mappings = {
		-- LSP相关操作映射
		{ "n", "<leader>gd", "<cmd>lua vim.lsp.buf.definition()<cr>", "跳转到定义" }, -- 跳转到符号定义
		{ "n", "<leader>gr", "<cmd>lua vim.lsp.buf.references()<cr>", "跳转到引用" }, -- 跳转到符号引用
		{ "n", "<leader>gn", "<cmd>lua vim.lsp.buf.rename()<cr>", "重命名当前符号" }, -- 重命名符号
		{ "n", "<leader>ga", "<cmd>lua vim.lsp.buf.code_action()<cr>", "触发代码操作" }, -- 触发代码建议或修复
		{ "n", "<leader>gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", "跳转到实现" }, -- 跳转到符号实现
		{ "n", "<leader>gO", "<cmd>lua vim.lsp.buf.document_symbol()<cr>", "查看文档符号" }, -- 查看文档符号列表
		{ "n", "<leader>grt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", "跳转到类型定义" }, -- 跳转到类型定义
		{ "n", "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<cr>", "显示函数签名帮助" }, -- 显示函数签名帮助
		{
			"n",
			"<leader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
			"开启/关闭内联提示",
		}, -- 开启或关闭内联提示
	}

	-- 设置缓冲区的快捷键映射
	for _, map in ipairs(mappings) do
		-- 这些映射与缓冲区绑定，仅在 LSP 附加到缓冲区时设置
		vim.keymap.set(map[1], map[2], map[3], { noremap = true, silent = true, buffer = buf, desc = map[4] })
	end
end

-- 全局诊断配置（仅初始化一次）
local function setup_global_diagnostics()
	vim.diagnostic.config({
		virtual_text = {
			spacing = 4,
			source = "if_many",
			prefix = "■",
		},
		float = {
			source = "if_many",
			border = "rounded",
		},
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "✘",
				[vim.diagnostic.severity.WARN] = "▲",
				[vim.diagnostic.severity.HINT] = "⚑",
				[vim.diagnostic.severity.INFO] = "»",
			},
		},
		underline = true,
		update_in_insert = false,
		severity_sort = true,
	})

	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "single" })
	vim.lsp.handlers["textDocument/signatureHelp"] =
		vim.lsp.with(vim.lsp.handlers.signature_help, { border = "single" })
end

local function setup_highlight_symbol(buf)
	-- 获取当前活动缓冲区
	local current_buf = vim.api.nvim_get_current_buf()
	-- 只有在当前缓冲区内才设置高亮功能
	if buf ~= current_buf then
		return
	end
	local group_name = "highlight_symbol"
	-- 创建自动命令组
	local group = vim.api.nvim_create_augroup(group_name, { clear = false })
	-- 清除已有的自动命令
	vim.api.nvim_clear_autocmds({ buffer = buf, group = group })
	-- 设置光标停留时高亮符号
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		buffer = buf,
		callback = function()
			-- 直接调用 LSP 的高亮功能
			vim.defer_fn(function()
				vim.lsp.buf.document_highlight()
			end, 50) -- 适当延迟减少性能消耗
		end,
	})
	-- 设置光标移动时清除高亮
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			-- 清除高亮
			vim.lsp.buf.clear_references()
		end,
	})
end

-- 开启 CodeLens 刷新
local function setup_codelens_refresh(buf)
	-- 确保 buf 是有效的
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local group = vim.api.nvim_create_augroup("codelens_refresh", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
		group = group,
		buffer = buf,
		callback = function()
			vim.lsp.codelens.refresh({ bufnr = buf })
		end,
	})
end

-- 设置折叠功能
local function setup_folding(buf, client)
	if client and client.supports_method("textDocument/foldingRange") then
		local win_id = vim.fn.bufwinid(buf)
		if win_id ~= -1 then
			vim.api.nvim_set_option_value("foldmethod", "expr", { win = win_id })
			vim.api.nvim_set_option_value("foldexpr", "v:lua.vim.lsp.foldexpr()", { win = win_id })
		end
	end
end

-- LSP 主设置函数
M.lspSetup = function()
	setup_global_diagnostics() -- 全局诊断配置
	setup_global_keymaps() -- 设置全局按键映射

	-- 创建 LspAttach 自动命令
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
		callback = function(args)
			local buf = args.buf
			-- local client = vim.lsp.get_client_by_id(args.data.client_id)
			setup_keymaps(buf) -- 设置缓冲区特定的按键映射
			-- setup_highlight_symbol(buf) -- 高亮关键字
			setup_codelens_refresh(buf) -- 刷新 CodeLens
			-- setup_folding(buf, client)  -- 设置折叠功能
		end,
	})
end

return M
