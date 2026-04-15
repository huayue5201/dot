-- lua/dap-config/dap-capabilities.lua
local M = {}

---------------------------------------------------------------------
-- 获取当前调试会话的 capabilities
---------------------------------------------------------------------
local function get_capabilities()
	local session = require("dap").session()
	return session and session.capabilities or nil
end

---------------------------------------------------------------------
-- 自动检测是否支持 inline breakpoint（column breakpoint）
-- 这是最关键的能力，DAP 标准字段 supportsColumnBreakpoint 很少被实现
-- 因此必须通过 setBreakpointsRequest 实测
---------------------------------------------------------------------
function M.supports_inline_breakpoints()
	local session = require("dap").session()
	if not session then
		return false, "No active debug session"
	end

	local test_bp = {
		source = { path = vim.api.nvim_buf_get_name(0) },
		line = 1,
		column = 5,
	}

	local resp = session:request_sync("setBreakpoints", {
		source = test_bp.source,
		breakpoints = { test_bp },
	}, 300)

	if not resp or not resp.body or not resp.body.breakpoints then
		return false, "Adapter did not return breakpoints"
	end

	local bp = resp.body.breakpoints[1]
	if not bp then
		return false, "Adapter returned no breakpoint"
	end

	if bp.column and bp.column > 0 then
		return true, nil
	end

	return false, "Adapter ignored column field"
end

---------------------------------------------------------------------
-- 通用能力查询函数
---------------------------------------------------------------------
local function has_cap(name)
	local caps = get_capabilities()
	return caps and caps[name] == true
end

---------------------------------------------------------------------
-- 断点相关能力
---------------------------------------------------------------------
function M.supports_function_breakpoints()
	return has_cap("supportsFunctionBreakpoints")
end

function M.supports_data_breakpoints()
	return has_cap("supportsDataBreakpoints")
end

function M.supports_instruction_breakpoints()
	return has_cap("supportsInstructionBreakpoints")
end

function M.supports_conditional_breakpoints()
	return has_cap("supportsConditionalBreakpoints")
end

function M.supports_hit_conditional_breakpoints()
	return has_cap("supportsHitConditionalBreakpoints")
end

function M.supports_log_points()
	return has_cap("supportsLogPoints")
end

function M.get_exception_filters()
	local caps = get_capabilities()
	return caps and caps.exceptionBreakpointFilters or {}
end

function M.supports_exception_options()
	return has_cap("supportsExceptionOptions")
end

---------------------------------------------------------------------
-- Stepping / 执行控制能力
---------------------------------------------------------------------
function M.supports_step_back()
	return has_cap("supportsStepBack")
end

function M.supports_stepping_granularity()
	return has_cap("supportsSteppingGranularity")
end

function M.supports_step_in_targets()
	return has_cap("supportsStepInTargetsRequest")
end

---------------------------------------------------------------------
-- 内存 / 数据访问能力
---------------------------------------------------------------------
function M.supports_read_memory()
	return has_cap("supportsReadMemoryRequest")
end

function M.supports_write_memory()
	return has_cap("supportsWriteMemoryRequest")
end

function M.supports_set_variable()
	return has_cap("supportsSetVariable")
end

---------------------------------------------------------------------
-- 其他能力
---------------------------------------------------------------------
function M.supports_goto_targets()
	return has_cap("supportsGotoTargetsRequest")
end

function M.supports_disassemble()
	return has_cap("supportsDisassembleRequest")
end

function M.supports_restart()
	return has_cap("supportsRestartRequest")
end

function M.supports_modules()
	return has_cap("supportsModulesRequest")
end

function M.supports_clipboard_context()
	return has_cap("supportsClipboardContext")
end

function M.supports_completions()
	return has_cap("supportsCompletionsRequest")
end

function M.supports_evaluate_for_hovers()
	return has_cap("supportsEvaluateForHovers")
end

function M.supports_cancel()
	return has_cap("supportsCancelRequest")
end

function M.supports_terminate_debuggee()
	return has_cap("supportTerminateDebuggee")
end

function M.supports_configuration_done()
	return has_cap("supportsConfigurationDoneRequest")
end

---------------------------------------------------------------------
-- 美化输出：显示所有能力（自动分类）
---------------------------------------------------------------------
function M.show()
	local caps = get_capabilities()
	if not caps then
		vim.notify("No active debug session", "warn")
		return
	end

	local lines = { "=== Debug Adapter Capabilities ===", "" }

	local groups = {
		Breakpoints = {},
		Stepping = {},
		Memory = {},
		Basic = {},
		Other = {},
	}

	for k, v in pairs(caps) do
		if type(v) == "boolean" then
			local line = string.format("  %-35s : %s", k, v and "✓" or "✗")

			if k:match("Breakpoint") then
				table.insert(groups.Breakpoints, line)
			elseif k:match("Step") or k:match("Stepping") then
				table.insert(groups.Stepping, line)
			elseif k:match("Memory") or k:match("Variable") then
				table.insert(groups.Memory, line)
			elseif k:match("Configuration") or k:match("Terminate") or k:match("Initialize") then
				table.insert(groups.Basic, line)
			else
				table.insert(groups.Other, line)
			end
		end
	end

	-- Exception filters
	if caps.exceptionBreakpointFilters then
		local filters = {}
		for _, f in ipairs(caps.exceptionBreakpointFilters) do
			table.insert(filters, f.filter or "unknown")
		end
		table.insert(lines, string.format("  %-35s : %s", "exceptionBreakpointFilters", table.concat(filters, ", ")))
	end

	for name, list in pairs(groups) do
		table.insert(lines, "")
		table.insert(lines, "  --- " .. name .. " ---")
		for _, line in ipairs(list) do
			table.insert(lines, line)
		end
	end

	vim.notify(table.concat(lines, "\n"), "info", { title = "DAP Capabilities", timeout = 8000 })
end

return M
