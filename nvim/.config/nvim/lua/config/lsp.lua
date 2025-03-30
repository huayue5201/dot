-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}

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
	local copy_lsp_diagnostics = function()
		local line = vim.fn.line(".") - 1 -- 获取当前光标所在的行号（Lua 索引从 0 开始）
		local diagnostics = vim.diagnostic.get(0, { lnum = line }) -- 获取当前行的诊断信息
		local diagnostic_msgs = {}
		for _, diag in ipairs(diagnostics) do
			table.insert(diagnostic_msgs, diag.message) -- 提取报错信息
		end
		if #diagnostic_msgs > 0 then
			local message = table.concat(diagnostic_msgs, "\n") -- 将报错信息合并为字符串
			vim.fn.setreg("+", message)
			print("LSP Diagnostic at cursor copied to clipboard!")
		else
			print("No LSP Diagnostics at cursor!")
		end
	end

	local keymaps = {
		{ "<leader>ld", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
		{ "<leader>rl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" },
		{ "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
		{
			"<leader>yd",
			function()
				copy_lsp_diagnostics()
			end,
			"Copy LSP Diagnostic at cursor",
		},
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
			"<localleader>i",
			"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
			"打开/关闭内联提示",
		},
	}
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { buffer = buf, noremap = true, silent = true, desc = map[3] })
	end
end

-- LSP 主设置函数
M.lspSetup = function()
	setup_global_diagnostics()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
		callback = function(args)
			set_keymaps()
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client:supports_method("textDocument/foldingRange") then
				local win = vim.api.nvim_get_current_win()
				vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
			end
		end,
	})
end

return M
