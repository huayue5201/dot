-- lua/user/lsp_config.lua
-- 参考资料: https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/

local M = {}

-- 设置按键映射
--
-- 此函数定义了各种按键映射，用于与 LSP 功能和诊断功能交互。
--
-- @param buf number 当前缓冲区
local function setup_keymaps(buf)
	-- 跳转到下一个占位符
	local function jump_next()
		if vim.snippet.jumpable(1) then
			return "<cmd>lua vim.snippet.jump(1)<cr>"
		else
			return "<C-f>"
		end
	end

	-- 跳转到上一个占位符
	local function jump_prev()
		if vim.snippet.jumpable(-1) then
			return "<cmd>lua vim.snippet.jump(-1)<cr>"
		else
			return "<C-b>"
		end
	end

	-- 退出当前代码片段
	local function exit_snippet()
		if vim.snippet.active() then
			return "<cmd>lua vim.snippet.exit()<cr>"
		else
			return "<C-l>"
		end
	end

	-- 定义按键映射表
	local mappings = {
		{ "n", "<leader>p", "<cmd>lua vim.diagnostic.open_float()<cr>", desc = "打开诊断浮动窗口" },
		{ "n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<cr>", desc = "跳转到前一个诊断" },
		{ "n", "]d", "<cmd>lua vim.diagnostic.goto_next()<cr>", desc = "跳转到下一个诊断" },
		{ "n", "<space>dq", "<cmd>lua vim.diagnostic.setloclist()<cr>", desc = "设置诊断位置列表" },
		{ "n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "显示悬停信息" },
		{ "n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", desc = "跳转到定义" },
		{ "n", "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>", desc = "跳转到声明" },
		{ "n", "gl", "<cmd>lua vim.lsp.buf.implementation()<cr>", desc = "跳转到实现" },
		{ "n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<cr>", desc = "跳转到类型定义" },
		{ "n", "gr", "<cmd>lua vim.lsp.buf.references()<cr>", desc = "查找引用" },
		{ "n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "显示函数签名帮助" },
		{
			"n",
			"<leader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable(0, not vim.lsp.inlay_hint.is_enabled(0))<cr>",
			desc = "开启/关闭内联提示",
		},
		{ "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "重命名符号" },
		{ "n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "代码操作" },
		{ "n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<cr>", desc = "添加工作区文件夹" },
		{ "n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<cr>", desc = "移除工作区文件夹" },
		{
			"n",
			"<space>wl",
			"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
			desc = "列出工作区文件夹",
		},
	}

	-- 应用按键映射
	for _, map in ipairs(mappings) do
		local mode, lhs, rhs, desc = unpack(map)
		vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, buffer = buf, desc = desc })
	end

	-- 单独设置占位符跳转的映射
	vim.keymap.set({ "i", "s" }, "<C-f>", jump_next, { expr = true })
	vim.keymap.set({ "i", "s" }, "<C-b>", jump_prev, { expr = true })
	vim.keymap.set({ "i", "s" }, "<C-l>", exit_snippet, { expr = true })
end

-- 设置诊断配置
--
-- 此函数配置了诊断显示方式和虚拟文本的设置。
--
local function setup_diagnostics()
	vim.diagnostic.config({
		virtual_text = {
			source = "always",
			prefix = "■",
			severity = {
				min = vim.diagnostic.severity.ERROR,
			},
		},
		float = {
			source = "always",
			border = "rounded",
		},
		signs = false,
		underline = true,
		update_in_insert = false,
		severity_sort = true,
	})

	-- 设置悬停信息和签名帮助的边框样式
	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
	vim.lsp.handlers["textDocument/signatureHelp"] =
		vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })
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
				vim.diagnostic.disable(0)
			else
				vim.diagnostic.enable(0)
			end
		end,
	})
end

-- 设置关键字高亮
--
-- 此函数设置了 LSP 的关键字高亮功能。
--
-- @param event table 包含事件数据的表
local function setup_highlight_symbol(event)
	local id = vim.tbl_get(event, "data", "client_id")
	local client = id and vim.lsp.get_client_by_id(id)
	if client == nil or not client.supports_method("textDocument/documentHighlight") then
		return
	end

	-- 设置高亮组
	local highlight_groups = { "LspReferenceRead", "LspReferenceText", "LspReferenceWrite" }
	for _, group in ipairs(highlight_groups) do
		vim.api.nvim_set_hl(0, group, { link = "Search" })
	end

	local group = vim.api.nvim_create_augroup("highlight_symbol", { clear = false })

	-- 清除之前的自动命令
	vim.api.nvim_clear_autocmds({ buffer = event.buf, group = group })

	-- 设置光标悬停时和移动时的高亮
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		buffer = event.buf,
		callback = vim.lsp.buf.document_highlight,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		buffer = event.buf,
		callback = vim.lsp.buf.clear_references,
	})
end

-- LSP主设置函数
--
-- 此函数用于设置 LSP 的相关功能，包括按键映射、诊断配置、诊断模式改变和关键字高亮。
--
M.lspSetup = function()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", {}),
		callback = function(event)
			-- 启用由 <c-x><c-o> 触发的补全
			vim.bo[event.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
			setup_keymaps(event.buf) -- 设置按键映射
			setup_diagnostics() -- 设置诊断配置
			setup_diagnostics_mode_change() -- 进入插入模式立即更新诊断信息
			setup_highlight_symbol(event) -- 设置关键字高亮
		end,
		-- 加载 LSP 进度通知
		require("user.lsp_progreess").setup_lsp_progress(),
	})
end

return M
