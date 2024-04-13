-- lua/util/lsp_config.lua
-- 参考资料: https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/
local M = {}

-- 设置按键映射
local function setup_keymaps(buf)
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

	for _, map in ipairs(mappings) do
		local mode, lhs, rhs = unpack(map)
		vim.keymap.set(mode, lhs, rhs, { noremap = true, silent = true, buffer = buf })
	end
end

-- 设置诊断配置
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

	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
	vim.lsp.handlers["textDocument/signatureHelp"] =
		vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })
end

-- 进入插入模式立即更新诊断信息
local function setup_diagnostics_mode_change()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s" },
		desc = "Disable diagnostics in insert and select mode",
		callback = function(e)
			vim.diagnostic.disable(e.buf)
		end,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = "i:n",
		desc = "Enable diagnostics when leaving insert mode",
		callback = function(e)
			vim.diagnostic.enable(e.buf)
		end,
	})
end

-- 关键字高亮
local function setup_highlight_symbol(event)
	local id = vim.tbl_get(event, "data", "client_id")
	local client = id and vim.lsp.get_client_by_id(id)
	if client == nil or not client.supports_method("textDocument/documentHighlight") then
		return
	end

	-- 设置高亮组
	vim.api.nvim_set_hl(0, "LspReferenceRead", { link = "Search" })
	vim.api.nvim_set_hl(0, "LspReferenceText", { link = "Search" })
	vim.api.nvim_set_hl(0, "LspReferenceWrite", { link = "Search" })

	local group = vim.api.nvim_create_augroup("highlight_symbol", { clear = false })

	vim.api.nvim_clear_autocmds({ buffer = event.buf, group = group })

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
M.lspSetup = function()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", {}),
		callback = function(event)
			-- Enable completion triggered by <c-x><c-o>
			vim.bo[event.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
			setup_keymaps(event.buf) -- 按键映射
			setup_diagnostics() -- 诊断配置
			setup_diagnostics_mode_change() -- 进入插入模式立即更新诊断信息
			setup_highlight_symbol(event) -- 关键字高亮
		end,
		require("utils.lsp_progreess").setup_lsp_progress(), -- lsp加载进度通知
	})
end

return M
