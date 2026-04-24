-- dap-config/dap-extensions/ui/sign.lua

local Event = require("dap-config.dap-extensions.event")
local registry = require("dap-config.dap-extensions.registry")

local M = {}

---------------------------------------------------------------------
-- namespace
---------------------------------------------------------------------
local NS_LINE = vim.api.nvim_create_namespace("dap_ext_line")
local NS_HIT = vim.api.nvim_create_namespace("dap_ext_hit")

---------------------------------------------------------------------
-- 缓存
---------------------------------------------------------------------
local line_marks = {}

---------------------------------------------------------------------
-- sign 定义
---------------------------------------------------------------------
vim.fn.sign_define("DapExtBreakpointPending", { text = " ", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpoint", { text = "●", texthl = "DapBreakpoint" })
vim.fn.sign_define("DapExtBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition" })
vim.fn.sign_define("DapExtBreakpointRejected", { text = "✗", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpointHit", { text = "🔥", texthl = "DapStopped" })
vim.fn.sign_define("DapExtBreakpointDisabled", { text = "○", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpointHardware", { text = " ", texthl = "DapBreakpoint" })
vim.fn.sign_define("DapExtBreakpointHardwareCondition", { text = " ", texthl = "DapBreakpointCondition" })

---------------------------------------------------------------------
-- 高亮（更明显）
---------------------------------------------------------------------
vim.api.nvim_set_hl(0, "DapExtBreakpointLine", {
	bg = "#5a3c3c",
})

vim.api.nvim_set_hl(0, "DapExtStopped", {
	bg = "#4c4c19",
})

---------------------------------------------------------------------
-- utils
---------------------------------------------------------------------
local function sign_id(bp)
	if not bp or not bp.id then
		return math.random(100000, 999999)
	end

	local sum = 0
	for i = 1, #bp.id do
		sum = (sum + bp.id:byte(i)) % 1000000
	end

	return sum + 100000
end

local function is_valid_line(bufnr, line)
	if not bufnr or not vim.api.nvim_buf_is_loaded(bufnr) then
		return false
	end
	local lc = vim.api.nvim_buf_line_count(bufnr)
	return line >= 1 and line <= lc
end

---------------------------------------------------------------------
-- sign 类型
---------------------------------------------------------------------
function M.get_sign_type(bp)
	if bp.enabled == false then
		return "DapExtBreakpointDisabled"
	end

	if bp.status == "pending" then
		return "DapExtBreakpointPending"
	elseif bp.status == "rejected" then
		return "DapExtBreakpointRejected"
	end

	if bp.type == "instruction" then
		if bp.config and (bp.config.condition or bp.config.hitCondition) then
			return "DapExtBreakpointHardwareCondition"
		end
		return "DapExtBreakpointHardware"
	end

	if bp.config and (bp.config.condition or bp.config.hitCondition) then
		return "DapExtBreakpointCondition"
	end

	return "DapExtBreakpoint"
end

---------------------------------------------------------------------
-- 清理
---------------------------------------------------------------------
function M.clear_sign(bp)
	if not bp or not bp.config then
		return
	end

	local bufnr = bp.config.bufnr
	local line = bp.config.line

	if not is_valid_line(bufnr, line) then
		return
	end

	local id = sign_id(bp)

	pcall(vim.fn.sign_unplace, "dap_breakpoints", {
		buffer = bufnr,
		id = id,
	})

	if line_marks[bp.id] then
		pcall(vim.api.nvim_buf_del_extmark, bufnr, NS_LINE, line_marks[bp.id])
		line_marks[bp.id] = nil
	end
end

---------------------------------------------------------------------
-- 渲染
---------------------------------------------------------------------
function M.show_sign(bp)
	if not bp or not bp.config then
		return
	end

	local bufnr = bp.config.bufnr
	local line = bp.config.line

	if not is_valid_line(bufnr, line) then
		return
	end

	local id = sign_id(bp)

	-- clear old
	pcall(vim.fn.sign_unplace, "dap_breakpoints", {
		buffer = bufnr,
		id = id,
	})

	-- place sign
	vim.fn.sign_place(id, "dap_breakpoints", M.get_sign_type(bp), bufnr, {
		lnum = line,
		priority = 20,
	})

	-- clear old extmark
	if line_marks[bp.id] then
		pcall(vim.api.nvim_buf_del_extmark, bufnr, NS_LINE, line_marks[bp.id])
	end

	-- 🔥 正确高亮方式
	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, NS_LINE, line - 1, 0, {
		line_hl_group = "DapExtBreakpointLine",
		priority = 10000,
	})

	line_marks[bp.id] = extmark_id
end

---------------------------------------------------------------------
-- 渲染 ext + native（核心）
---------------------------------------------------------------------
function M.render_all()
	M.clear_all()

	-----------------------------------------------------------------
	-- 1. ext breakpoints
	-----------------------------------------------------------------
	for _, bp in pairs(registry.bps) do
		if bp.config and is_valid_line(bp.config.bufnr, bp.config.line) then
			M.show_sign(bp)
		end
	end

	-----------------------------------------------------------------
	-- 2. native breakpoints（来自 store）
	-----------------------------------------------------------------
	local ok, store_mod = pcall(require, "nvim-store3")
	if not ok then
		return
	end

	local store = store_mod.project()
	local data = store:get("dap_breakpoints") or {}

	for key, list in pairs(data) do
		if key ~= "custom_breakpoints" then
			local path = key:gsub("%%%.", "."):gsub("%%%%", "%%")
			local bufnr = vim.fn.bufnr(path, false)

			if bufnr ~= -1 then
				for _, bp in ipairs(list) do
					local fake_bp = {
						id = "native_" .. bufnr .. "_" .. bp.line,
						type = "source",
						enabled = true,
						status = "verified",
						config = {
							bufnr = bufnr,
							line = bp.line,
						},
					}
					M.show_sign(fake_bp)
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- 清空
---------------------------------------------------------------------
function M.clear_all()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			pcall(vim.api.nvim_buf_clear_namespace, buf, NS_LINE, 0, -1)
			pcall(vim.api.nvim_buf_clear_namespace, buf, NS_HIT, 0, -1)
		end
	end

	line_marks = {}
	pcall(vim.fn.sign_unplace, "dap_breakpoints")
end

---------------------------------------------------------------------
-- hit 高亮
---------------------------------------------------------------------
function M.show_hit(bp)
	if not bp or not bp.config then
		return
	end

	local bufnr = bp.config.bufnr
	local line = bp.config.line

	if not is_valid_line(bufnr, line) then
		return
	end

	local id = sign_id(bp) + 1000000

	vim.fn.sign_place(id, "dap_breakpoints", "DapExtBreakpointHit", bufnr, {
		lnum = line,
		priority = 30,
	})

	local ext_ns = vim.api.nvim_create_namespace("dap_ext_hit_temp")

	vim.api.nvim_buf_set_extmark(bufnr, ext_ns, line - 1, 0, {
		line_hl_group = "DapExtStopped",
		priority = 9999,
	})

	vim.defer_fn(function()
		pcall(vim.fn.sign_unplace, "dap_breakpoints", { id = id })
		if vim.api.nvim_buf_is_loaded(bufnr) then
			pcall(vim.api.nvim_buf_clear_namespace, bufnr, ext_ns, 0, -1)
		end
	end, 1500)
end

---------------------------------------------------------------------
-- 事件
---------------------------------------------------------------------
Event.on("bp_hit", function(bp)
	M.show_hit(bp)
end)

return M
