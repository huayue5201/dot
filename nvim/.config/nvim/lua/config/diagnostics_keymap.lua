-- 文件: lua/my/diagnostics.lua
local M = {}

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

-- 复制光标词相关的诊断信息到剪贴板
function M.copy_diagnostics_under_cursor()
	local bufnr = 0
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
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
	local matched = {}
	for _, diag in ipairs(diagnostics) do
		local s_row, s_col = diag.lnum, diag.col
		local e_row, e_col = diag.end_lnum or s_row, diag.end_col or s_col + 1
		local in_range = (row > s_row or (row == s_row and col >= s_col))
			and (row < e_row or (row == e_row and col < e_col))
		if in_range or diag.message:find(word, 1, true) then
			table.insert(matched, format(diag))
		end
	end
	if #matched > 0 then
		local content = table.concat(matched, "\n")
		vim.fn.setreg("+", content)
		vim.notify("诊断信息已复制到剪贴板!", vim.log.levels.INFO)
	else
		vim.notify("无诊断信息", vim.log.levels.INFO)
	end
end

-- 重启当前缓冲区的 LSP 客户端
function M.restart_lsp()
	for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
		vim.lsp.stop_client(client.id)
	end
	vim.defer_fn(function()
		vim.cmd("edit")
	end, 100)
end

return M
