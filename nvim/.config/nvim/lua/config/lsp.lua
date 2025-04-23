-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}

-- 设置诊断的全局配置
function M.setup_global_diagnostics()
	local icons = require("config.utils").icons.diagnostic
	vim.diagnostic.config({
		-- virtual_text = { spacing = 4, source = "if_many", prefix = "■" }, -- 可选: '●', '▎', 'x'
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

	-- 可以选择以下几种边框样式: `"double"`, `"none"`, `"rounded"`, `"shadow"`, `"single"`, `"solid"`
	-- hover UI
	local orig_util_open_floating_preview = vim.lsp.util.open_floating_preview
	---@diagnostic disable-next-line: duplicate-set-field
	function vim.lsp.util.open_floating_preview(contents, syntax, opts, ...)
		opts = opts or {}
		opts.border = "rounded" -- 设置边框样式
		return orig_util_open_floating_preview(contents, syntax, opts, ...)
	end

	-- 插入模式下立刻更新诊断信息
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s" },
		desc = "插入/选择模式禁用诊断",
		callback = function()
			vim.diagnostic.enable(not vim.diagnostic.is_enabled())
		end,
	})
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = "i:n",
		desc = "离开插入模式时启用诊断",
		callback = function()
			vim.diagnostic.enable(not vim.diagnostic.is_enabled())
		end,
	})
end

-- 设置按键映射
function M.set_keymaps(buf, client)
	local keymaps = {
		{ "<leader>ld", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
		{ "<leader>rl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭 LSP 客户端" },
		{ "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
		{
			"<leader>yd",
			function()
				local bufnr = 0
				local cursor = vim.api.nvim_win_get_cursor(0)
				local row = cursor[1] - 1
				local col = cursor[2]
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

				local matched_by_word = {}
				local matched_by_line = {}

				for _, diag in ipairs(diagnostics) do
					local s_row = diag.lnum
					local s_col = diag.col
					local e_row = diag.end_lnum or s_row
					local e_col = diag.end_col or (s_col + 1)

					local in_range = (row > s_row or (row == s_row and col >= s_col))
						and (row < e_row or (row == e_row and col < e_col))

					local word_in_msg = diag.message:find(word, 1, true)

					if in_range or word_in_msg then
						table.insert(matched_by_word, format(diag))
					end

					if s_row == row then
						table.insert(matched_by_line, format(diag))
					end
				end

				if #matched_by_word > 0 then
					local content = table.concat(matched_by_word, "\n")
					vim.fn.setreg("+", content)
					vim.notify("光标词诊断信息已复制到剪贴板!", vim.log.levels.INFO)
				elseif #matched_by_line > 0 then
					local content = table.concat(matched_by_line, "\n")
					vim.fn.setreg("+", content)
					vim.notify("当前行诊断信息已复制到剪贴板!", vim.log.levels.INFO)
				else
					vim.notify("光标下词及当前行无诊断信息", vim.log.levels.INFO)
				end
			end,
			"复制光标词的诊断（无则退回整行）",
		},
		{
			"<localleader>d",
			"<cmd>lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>",
			"打开/关闭 LSP 诊断",
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

-- 自动刷新 CodeLens
function M.setup_codelens_autocmd(bufnr, client)
	if client:supports_method("textDocument/codeLens") then
		local group = vim.api.nvim_create_augroup("LspCodeLensRefresh", { clear = false })
		vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
			group = group,
			buffer = bufnr,
			callback = function()
				vim.lsp.codelens.refresh()
			end,
		})
		-- 可选：attach 后立刻刷新一次
		vim.schedule(vim.lsp.codelens.refresh)
	end
end
return M
