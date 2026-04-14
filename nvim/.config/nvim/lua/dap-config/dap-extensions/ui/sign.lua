-- dap-config/dap-extensions/ui/sign.lua
local Event = require("dap-config.dap-extensions.event")
local registry = require("dap-config.dap-extensions.registry")
local virtual_text = require("dap-config.dap-extensions.ui.virtual_text")

local M = {}

-- 固定 namespace
local NS_LINE = vim.api.nvim_create_namespace("dap_ext_line")
local NS_HIT = vim.api.nvim_create_namespace("dap_ext_hit")

-- 存储每个断点的 extmark id，用于单独管理
local line_marks = {}

-- sign 定义
vim.fn.sign_define("DapExtBreakpointPending", { text = "○", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpoint", { text = "●", texthl = "DapBreakpoint" })
vim.fn.sign_define("DapExtBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition" })
vim.fn.sign_define("DapExtBreakpointRejected", { text = "✗", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpointHit", { text = "🔥", texthl = "DapStopped" })
-- 硬件断点图标
vim.fn.sign_define("DapExtBreakpointHardware", { text = "⚡", texthl = "DapBreakpoint" })
vim.fn.sign_define("DapExtBreakpointHardwareCondition", { text = "⚡", texthl = "DapBreakpointCondition" })

-- 自定义高亮组（不与 nvim-dap 冲突）
vim.api.nvim_set_hl(0, "DapExtBreakpointLine", {
	bg = "#3c3836",
	default = false,
})

vim.api.nvim_set_hl(0, "DapExtStopped", {
	bg = "#4c4c19",
	default = false,
})

--- 为每个 bp 生成稳定的 sign id
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

--- 获取 sign 类型
function M.get_sign_type(bp)
	if bp.status == "pending" then
		return "DapExtBreakpointPending"
	elseif bp.status == "rejected" then
		return "DapExtBreakpointRejected"
	end

	-- 硬件断点特殊图标
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

--- 清理单个断点的 sign 和行高亮
function M.clear_sign(bp)
	if not bp or not bp.config or not bp.config.bufnr or not bp.config.line then
		return
	end

	local bufnr = bp.config.bufnr
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local id = sign_id(bp)

	-- 清除 sign
	pcall(vim.fn.sign_unplace, "dap_ext", {
		buffer = bufnr,
		id = id,
	})

	-- 清除行高亮（单独清除该断点的 extmark）
	if line_marks[bp.id] then
		pcall(vim.api.nvim_buf_del_extmark, bufnr, NS_LINE, line_marks[bp.id])
		line_marks[bp.id] = nil
	end

	-- 清除虚拟文本
	if virtual_text and virtual_text.clear_for_bp then
		virtual_text.clear_for_bp(bp)
	end
end

--- 渲染单个断点的 sign + 行高亮
function M.show_sign(bp)
	if not bp or not bp.config or not bp.config.bufnr or not bp.config.line then
		return
	end

	local bufnr = bp.config.bufnr
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local id = sign_id(bp)

	-- 先清除旧的（但不清除整个 namespace）
	pcall(vim.fn.sign_unplace, "dap_ext", {
		buffer = bufnr,
		id = id,
	})

	-- 放置 sign
	vim.fn.sign_place(id, "dap_ext", M.get_sign_type(bp), bufnr, {
		lnum = bp.config.line,
		priority = 10,
	})

	-- 清除该断点之前的行高亮
	if line_marks[bp.id] then
		pcall(vim.api.nvim_buf_del_extmark, bufnr, NS_LINE, line_marks[bp.id])
		line_marks[bp.id] = nil
	end

	-- 添加新的行高亮（保存 extmark id）
	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, NS_LINE, bp.config.line - 1, 0, {
		hl_group = "DapExtBreakpointLine",
		hl_eol = true,
		priority = 2000,
		strict = false,
	})

	line_marks[bp.id] = extmark_id
end

--- 显示命中断点的 hit 标记
function M.show_hit(bp)
	if not bp or not bp.config or not bp.config.bufnr or not bp.config.line then
		return
	end

	local bufnr = bp.config.bufnr
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local line = bp.config.line
	local hit_ns = vim.api.nvim_create_namespace("dap_ext_hit_temp")

	-- 清除之前的临时 hit 标记（只清除临时 namespace）
	pcall(vim.api.nvim_buf_clear_namespace, bufnr, hit_ns, 0, -1)

	local id = sign_id(bp) + 1000000

	-- 临时 sign
	vim.fn.sign_place(id, "dap_ext", "DapExtBreakpointHit", bufnr, {
		lnum = line,
		priority = 20,
	})

	-- 临时行高亮
	vim.api.nvim_buf_set_extmark(bufnr, hit_ns, line - 1, 0, {
		hl_group = "DapExtStopped",
		hl_eol = true,
		priority = 1500,
	})

	-- 3秒后清除临时标记
	vim.defer_fn(function()
		pcall(vim.fn.sign_unplace, "dap_ext", { id = id })
		if vim.api.nvim_buf_is_loaded(bufnr) then
			pcall(vim.api.nvim_buf_clear_namespace, bufnr, hit_ns, 0, -1)
		end
	end, 1500)
end

--- 全量刷新
function M.render_all()
	for _, bp in pairs(registry.bps) do
		M.show_sign(bp)
	end
end

--- 清空所有 sign 和行高亮
function M.clear_all()
	for _, bp in pairs(registry.bps) do
		M.clear_sign(bp)
	end

	-- 清空所有 namespace
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			pcall(vim.api.nvim_buf_clear_namespace, buf, NS_LINE, 0, -1)
			pcall(vim.api.nvim_buf_clear_namespace, buf, NS_HIT, 0, -1)
		end
	end

	line_marks = {}
	pcall(vim.fn.sign_unplace, "dap_ext")
end

Event.on("bp_hit", function(bp)
	M.show_hit(bp)
end)

return M
