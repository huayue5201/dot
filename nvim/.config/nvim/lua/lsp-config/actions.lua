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
local WORKSPACE_QF_TITLE = "Project Diagnostics"

local function show_project_qflist(open)
	vim.diagnostic.setqflist({
		open = open,
		title = WORKSPACE_QF_TITLE,
		severity = { min = vim.diagnostic.severity.WARN },
	})
end

--- 显式请求 workspace 级诊断（默认不再于 LspAttach 时扫描）
--- rust-analyzer 的 workspace/diagnostic 会触发全项目检查，代价很高，
--- 所以改成只由 `grD` 触发；结果分批返回，在 8 秒窗口内随诊断变化刷新 quickfix，
--- 这样仍然是「一键看到项目诊断」，只是不再每次打开文件都扫一遍。
function M.open_all_diagnostics()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "workspace/diagnostic" })

	if #clients == 0 then
		show_project_qflist(true)
		return
	end

	for _, client in ipairs(clients) do
		vim.lsp.buf.workspace_diagnostics({ client_id = client.id })
	end

	local group = vim.api.nvim_create_augroup("UserWorkspaceDiagnosticsQf", { clear = true })
	local timer = vim.uv.new_timer()

	local function stop()
		if timer then
			timer:stop()
			if not timer:is_closing() then
				timer:close()
			end
			timer = nil
		end
		pcall(vim.api.nvim_del_augroup_by_id, group)
	end

	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function()
			vim.schedule(function()
				show_project_qflist(false)
			end)
		end,
	})

	timer:start(8000, 0, vim.schedule_wrap(stop))
	show_project_qflist(true)
	vim.notify("workspace diagnostics: scanning...", vim.log.levels.INFO)
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
