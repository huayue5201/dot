local M = {}

local lsp_get = require("lsp.lsp_utils")

-- 重启当前缓冲区的 LSP 客户端
local function restart_lsp()
	-- 获取所有已启动的 LSP 客户端
	local clients = vim.lsp.get_clients()
	-- 遍历所有 LSP 客户端并请求停止
	for _, client in ipairs(clients) do
		client:stop(true) -- 使用 `true` 表示强制停止客户端
	end
	-- 延迟启动 LSP
	vim.defer_fn(function()
		local lsp_name = lsp_get.get_lsp_name()
		-- 假设 lsp.enable() 已经处理了启动逻辑
		vim.lsp.enable(lsp_name, true)
	end, 500)
end

-- 关闭 LSP
function M.stop_lsp()
	vim.lsp.enable(lsp_get.get_lsp_name(), false)
	-- 刷新状态
	vim.schedule(function()
		vim.cmd.redrawstatus()
	end)
end

-- 打开所有 buffer 的诊断（Quickfix 风格，适合全局排查）
local function open_all_diagnostics()
	---@diagnostic disable-next-line: param-type-mismatch
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

-- 仅当前 buffer 的诊断（Loclist 风格，适合局部修复）
local function open_buffer_diagnostics()
	---@diagnostic disable-next-line: param-type-mismatch
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(d)
			return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
		end,
	})
end

-- 复制光标处的错误信息（包括错误代码）
local function CopyErrorMessage()
	local row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
	local diag = vim.diagnostic.get(0, { lnum = row })
	if #diag > 0 then
		local messages = {}
		for _, diagnostic in ipairs(diag) do
			local code = diagnostic.code or "No code available"
			local message = diagnostic.message or "No message available"
			-- 可选：附加上诊断来源，便于排查
			local source = diagnostic.source or "unknown"
			table.insert(messages, message .. " [" .. code .. "] - " .. source)
		end
		local all_messages = table.concat(messages, "\n")
		vim.fn.setreg("+", all_messages)
		print("Error messages copied to clipboard:\n" .. all_messages)
	else
		-- 更详细的提示
		print("No diagnostics found at cursor position. Ensure a language server or linter is running.")
	end
end

-- 按键映射
local keymaps = {
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },

	{
		"<s-a-d>",
		"<cmd>lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>",
		"LSP: toggle diagnostics",
	},
	{
		"<leader>cl",
		function()
			M.stop_lsp()
		end,
		"LSP: 关闭lsp",
	},
	{
		"<leader>rl",
		function()
			restart_lsp()
		end,
		"LSP: 重启lsp",
	},
	{
		"<leader>ld",
		function()
			open_buffer_diagnostics()
		end,
		"LSP: buffer diagnostics",
	},

	{
		"<leader>lD",
		function()
			open_all_diagnostics()
		end,
		"LSP: workspace diagnostics",
	},

	{
		"<leader>yd",
		function()
			CopyErrorMessage()
		end,
		"LSP: copy diagnostic message",
	},

	{
		"<s-a-i>",
		"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
		"LSP: toggle inlay hints",
	},

	{
		"<leader>lw",
		"<cmd>LspListActive<cr>",
		"LSP: list workspace folders",
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

return M
