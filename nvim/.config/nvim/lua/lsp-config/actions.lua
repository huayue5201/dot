-- lua/lsp-config/actions.lua
---@brief 可复用的 LSP 动作（供 keymaps / 命令调用，不含按键绑定）
local M = {}

local state = require("lsp-config.state")

local d = vim.diagnostic

local severity_order = {
	d.severity.ERROR,
	d.severity.WARN,
	d.severity.INFO,
	d.severity.HINT,
}

local function get_highest_severity(bufnr)
	bufnr = bufnr or 0
	local count = d.count(bufnr)

	for _, s in ipairs(severity_order) do
		if count[s] and count[s] > 0 then
			return s
		end
	end

	return nil
end

---------------------------------------------------------
-- 诊断跳转
---------------------------------------------------------
function M.jump_next()
	d.jump({
		count = vim.v.count1,
		severity = get_highest_severity(0), -- nil = all severities
	})
end

function M.jump_prev()
	d.jump({
		count = -vim.v.count1,
		severity = get_highest_severity(0),
	})
end

---------------------------------------------------------
-- 诊断 Quickfix / Loclist
---------------------------------------------------------
function M.open_all_diagnostics()
	vim.diagnostic.setqflist({
		open = true,
		title = "Project Diagnostics",
		severity = { min = vim.diagnostic.severity.WARN },
	})
end

function M.open_buffer_diagnostics()
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
	})
end

---------------------------------------------------------
-- 诊断 / 内联提示 开关（项目级持久化）
---------------------------------------------------------
function M.toggle_diagnostics()
	local enabled = state.toggle("lsp.diagnostics")
	vim.diagnostic.enable(enabled)
end

function M.toggle_inlay_hints()
	local enabled = state.toggle("lsp.inlay_hints")
	vim.lsp.inlay_hint.enable(enabled)
end

---------------------------------------------------------
-- 文档 / 复制 / 日志 / code lens
---------------------------------------------------------
function M.open_docs()
	require("lsp-config.external_docs").open_docs()
end

function M.copy_diagnostics()
	require("lsp-config.copy_diagnostics").copy_error_message()
end

function M.open_lsp_log()
	vim.cmd("tabnew " .. vim.lsp.log.get_filename())
end

---运行光标处 code lens（处理 lens 文字渲染在函数上方一行的偏移）
function M.run_code_lens()
	local bufnr = 0
	local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
	local lenses = vim.lsp.codelens.get(bufnr) or {}

	local at_current, at_next = false, false
	for _, lens in pairs(lenses) do
		if lens.range then
			local fn_line = lens.range.start.line + 1 -- 1-based 函数行
			if fn_line == row then
				at_current = true
			elseif fn_line == row + 1 then
				at_next = true
			end
		end
	end

	-- lens 文字渲染在函数上方一行；若光标停在文字行，下移到函数行再执行
	if not at_current and at_next then
		vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
	end
	vim.lsp.codelens.run()
end

return M
