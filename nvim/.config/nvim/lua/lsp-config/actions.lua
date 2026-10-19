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
function M.toggle_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local enabled = state.toggle("lsp.diagnostics", bufnr)
	vim.diagnostic.enable(enabled)
end

function M.toggle_inlay_hints(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local enabled = state.toggle("lsp.inlay_hints", bufnr)
	vim.lsp.inlay_hint.enable(enabled)
end

---------------------------------------------------------
-- 文档 / 复制 / 日志 / code lens
---------------------------------------------------------
function M.open_docs()
	require("lsp-config.features.external_docs").open_docs()
end

function M.copy_diagnostics()
	require("lsp-config.copy_diagnostics").copy_error_message()
end

function M.open_lsp_log()
	vim.cmd("tabnew " .. vim.lsp.log.get_filename())
end

---运行光标处 code lens（透镜由 features/code_lens.lua 自己渲染，直接执行它记录的那条命令）
function M.run_code_lens()
	if require("lsp-config.features.code_lens").run_at_cursor() then
		return
	end
	-- 不退回 vim.lsp.codelens.run()：内置缓存会拿到 server 给的「空命令」透镜，
	-- 送进 Client:exec_cmd 就报 `does not support command ``` 且什么也不做。
	-- 服务器本来就不提供透镜（如 lua-language-server 的 codeLens 永远返回 null）时，
	-- 只提示一句，不自作主张用 references 之类去补。
	local bufnr = vim.api.nvim_get_current_buf()
	local names = {}
	for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		names[#names + 1] = c.name
	end
	vim.notify(
		string.format(
			"No runnable code lens on this line (%s)",
			#names > 0 and ("server: " .. table.concat(names, ", ")) or "no LSP client attached"
		),
		vim.log.levels.INFO
	)
end

return M
