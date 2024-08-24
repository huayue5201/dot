-- :h lsp-defaults
--
-- NORMAL MODE
-- K        : hover
-- grn      : rename
-- gra      : code action
-- grr      : references
-- CTRL-]   : definition
-- CTRL-W_] : definition in new window
-- CTRL-W_} : definition in preview window
--
-- VISUAL MODE
-- gq : format
--
-- INSERT MODE
-- CTRL-S        : signature help
-- CTRL-X_CTRL-O : completion

---server configurations copied from <https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md>

-- lua/user/lsp_config.lua
-- 参考资料: https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/
-- https://github.com/neovim/nvim-lspconfig

-- 设置按键映射
-- 此函数定义了各种按键映射，用于与 LSP 功能和诊断功能交互。

-- @param buf number 当前缓冲区
local function setup_keymaps(buf)
	-- 定义按键映射表
	local mappings = {
		{ "n", "<leader>od", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
		{ "n", "grd", "<cmd>lua vim.lsp.buf.declaration()<cr>", "跳转到声明" },
		{ "n", "gri", "<cmd>lua vim.lsp.buf.implementation()<cr>", "跳转到实现" },
		{ "n", "grt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", "跳转到类型定义" },
		{ "n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<cr>", "显示函数签名帮助" },
		{
			"n",
			"<leader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable( not vim.lsp.inlay_hint.is_enabled())<cr>",
			"开启/关闭内联提示",
		},
		{
			-- TODO: 实现lsp关闭/启动命令 lsp开启命令：lua vim.lsp.start({cmd={"clangd"}})
			-- 实现逻辑：
			-- 1、判断当前buffer文件类型
			-- 2、根据文件类型匹配lsp名称
			-- 3、执行启动命令
			"n",
			"<leader>cl",
			"<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>",
			"关闭LSP客户端",
		},
		{ "n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<cr>", "添加工作区文件夹" },
		{ "n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<cr>", "移除工作区文件夹" },
		{
			"n",
			"<space>wl",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
			"列出工作区文件夹",
		},
	}

	-- 应用按键映射
	for _, map in ipairs(mappings) do
		local mode, lhs, rhs, desc = unpack(map)
		vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, buffer = buf, desc = desc })
	end
end

-- 设置诊断配置

-- 此函数配置了诊断显示方式和虚拟文本的设置。

local function setup_diagnostics()
	vim.diagnostic.config({
		virtual_text = {
			spacing = 4,
			source = "if_many",
			prefix = "■",
			-- severity = {
			-- 	min = vim.diagnostic.severity.ERROR,
			-- },
		},
		float = {
			source = "if_many",
			border = "rounded",
		},
		-- signs = true,
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

	-- 设置悬停信息和签名帮助的边框样式
	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
		-- Use a sharp border with `FloatBorder` highlights
		border = "single",
		-- add the title in hover float window
		title = "hover",
	})
	vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
		-- Use a sharp border with `FloatBorder` highlights
		border = "single",
	})
end

-- 进入插入模式立即更新诊断信息
--
-- 此函数在进入插入或可视模式时禁用诊断，其他模式下启用诊断。
--
local function setup_diagnostics_mode_change()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = "*",
		callback = function()
			local current_mode = vim.api.nvim_get_mode().mode
			if current_mode == "i" or current_mode == "v" then
				vim.diagnostic.enable(not vim.diagnostic.is_enabled())
			else
				vim.diagnostic.enable(not vim.diagnostic.is_enabled())
			end
		end,
	})
end

-- 辅助函数，用于从args中提取client_id，并检查client是否存在及其是否支持指定方法
local function get_and_check_lsp_client(args, method)
	local id = vim.tbl_get(args, "data", "client_id")
	local client = id and vim.lsp.get_client_by_id(id)
	if client == nil or not client.supports_method(method) then
		return nil
	end
	return client
end

-- 设置符号高亮
local function setup_highlight_symbol(args)
	local client = get_and_check_lsp_client(args, "textDocument/documentHighlight")
	if not client then
		return
	end

	-- 设置高亮
	local highlight_groups = { "LspReferenceRead", "LspReferenceText", "LspReferenceWrite" }
	for _, group in ipairs(highlight_groups) do
		vim.api.nvim_set_hl(0, group, { link = "Search" })
	end

	local group = vim.api.nvim_create_augroup("highlight_symbol", { clear = false })

	-- 清除之前的自动命令
	vim.api.nvim_clear_autocmds({ buffer = args.buf, group = group })

	-- 设置光标悬停时和移动时的高亮
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		buffer = args.buf,
		callback = vim.lsp.buf.document_highlight,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = args.buf,
		callback = vim.lsp.buf.clear_references,
	})
end

-- 开启内嵌提示
local function setup_inlay_hint(args)
	local client = get_and_check_lsp_client(args, "textDocument/inlayHint")
	if not client then
		return
	end
	-- warning: this api is not stable yet
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end

-- 开启codelens刷新
local function setup_codelen_refresh(args)
	local client = get_and_check_lsp_client(args, "textDocument/codeLens")
	if not client then
		return
	end

	vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
		buffer = args.buf,
		callback = function()
			vim.lsp.codelens.refresh({ bufnr = args.buf })
		end,
	})
end

local M = {}
-- LSP主设置函数
--
-- 此函数用于设置 LSP 的相关功能，包括按键映射、诊断配置、诊断模式改变和关键字高亮。
--
M.lspSetup = function()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
		callback = function(args)
			-- print(vim.inspect(args)) -- 这会打印 args 表格的内容
			-- vim.bo[args.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
			setup_keymaps(args.buf) -- 设置按键映射
			setup_diagnostics() -- 设置诊断配置
			setup_diagnostics_mode_change() -- 进入插入模式立即更新诊断信息
			setup_highlight_symbol(args) -- 设置关键字高亮
			setup_inlay_hint(args) -- 开启内嵌提示
			setup_codelen_refresh(args) -- 开启codelen
		end,
	})
end

return M
