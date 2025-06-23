-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

-- LSP 配置模块
local M = {}

-- 设置诊断的全局配置
local icons = require("utils.utils").icons.diagnostic
M.diagnostic_config = function()
	vim.diagnostic.config({
		virtual_text = {
			current_line = false,
		},
		virtual_lines = {
			current_line = true,
		},
		severity_sort = true,
		-- float = { source = "if_many", border = "shadow" },
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
	vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx)
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
		vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
	end
end

-- 插入/选择模式禁用/启用诊断
M.mode_changed_handler = function()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local diag_enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })
			if diag_enabled then
				-- 进入插入/选择模式时关闭诊断
				vim.diagnostic.enable(false, { bufnr = bufnr })
				-- 离开插入/选择模式后重新启用诊断，只启用一次自动命令
				vim.api.nvim_create_autocmd("ModeChanged", {
					pattern = { "i:n", "s:v" },
					once = true,
					desc = "离开插入/选择模式后重新启用诊断",
					callback = function()
						local current_buf = vim.api.nvim_get_current_buf()
						if vim.api.nvim_buf_is_valid(current_buf) then
							vim.diagnostic.enable(true, { bufnr = current_buf })
						end
					end,
				})
			end
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
local keymaps = {
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
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
M.set_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { noremap = true, silent = true, desc = map[3], buffer = bufnr })
	end
end

-- 删除按键映射
M.remove_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		pcall(vim.keymap.del, "n", map[1], { buffer = bufnr })
	end
end

-- 获取所有 lsp/*.lua 文件的名称（不带后缀）
function M.get_all_lsp_names()
	local configs = {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
		local name = vim.fn.fnamemodify(path, ":t:r")
		configs[name] = true
	end
	return vim.tbl_keys(configs)
end

-- 打开所有 buffer 的诊断（Quickfix 风格，适合全局排查）
function M.open_all_diagnostics()
	vim.diagnostic.setqflist({
		open = true,
		title = "Project Diagnostics",
		severity = { min = vim.diagnostic.severity.WARN },
		format = function(d)
			return string.format(
				"[%s] %s (%s:%d)",
				vim.diagnostic.severity[d.severity],
				d.message,
				d.source or "?",
				d.lnum + 1
			)
		end,
	})
end

-- 复制光标处的错误信息（包括错误代码）
function M.CopyErrorMessage()
	local row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
	local diag = vim.diagnostic.get(0, { lnum = row })
	if #diag > 0 then
		local messages = {}
		for _, diagnostic in ipairs(diag) do
			local code = diagnostic.code or "No code available"
			local message = diagnostic.message or "No message available"
			table.insert(messages, message .. " [" .. code .. "]")
		end
		local all_messages = table.concat(messages, "\n")
		vim.fn.setreg("+", all_messages)
		print("Error messages copied to clipboard:\n" .. all_messages)
	else
		print("No error at the cursor!")
	end
end

-- 仅当前 buffer 的诊断（Loclist 风格，适合局部修复）
function M.open_buffer_diagnostics()
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(d)
			return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
		end,
	})
end

-- 重启当前缓冲区的 LSP 客户端
function M.restart_lsp()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	-- 停止现有客户端
	for _, client in ipairs(clients) do
		vim.lsp.stop_client(client.id, true)
	end
	-- 创建一次性 autocmd，在成功 attach 后再设置状态
	local group = vim.api.nvim_create_augroup("RestartLspOnce", { clear = true })
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		once = true,
		callback = function(args)
			if args.buf == bufnr then
				vim.g.lsp_enabled = true
				require("utils.per_project_lsp").set_lsp_state(true)
			end
		end,
	})
	-- 启动 LSP
	vim.defer_fn(function()
		vim.lsp.enable(M.get_all_lsp_names())
	end, 100)
end

-- 关闭lsp
function M.stop_lsp()
	vim.lsp.stop_client(vim.lsp.get_clients(), true)
	vim.g.lsp_enabled = false
	require("utils.per_project_lsp").set_lsp_state(false)
	vim.schedule(function()
		vim.cmd.redrawstatus()
	end)
end

return M
