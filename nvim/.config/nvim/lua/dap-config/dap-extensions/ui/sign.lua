local Event = require("dap-config.dap-extensions.event")
local registry = require("dap-config.dap-extensions.registry")

local M = {}

-- ✅ 固定 namespace（不要反复创建）
local NS_LINE = vim.api.nvim_create_namespace("dap_ext_line")
local NS_HIT = vim.api.nvim_create_namespace("dap_ext_hit")

-- sign 定义
vim.fn.sign_define("DapExtBreakpointPending", { text = "○", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpoint", { text = "●", texthl = "DapBreakpoint" })
vim.fn.sign_define("DapExtBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition" })
vim.fn.sign_define("DapExtBreakpointRejected", { text = "✗", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapExtBreakpointHit", { text = "🔥", texthl = "DapStopped" })

-- 每个 bp 固定 sign id（核心！！）
local function sign_id(bp)
	return tonumber(bp.id:sub(-6), 16) or math.random(100000)
end

-- ============================================================
-- sign 类型
-- ============================================================
function M.get_sign_type(bp)
	if bp.status == "pending" then
		return "DapExtBreakpointPending"
	elseif bp.status == "rejected" then
		return "DapExtBreakpointRejected"
	end

	if bp.config.condition or bp.config.hitCondition then
		return "DapExtBreakpointCondition"
	end

	return "DapExtBreakpoint"
end

-- ============================================================
-- 清理
-- ============================================================
function M.clear_sign(bp)
	if not bp.config.bufnr or not bp.config.line then
		return
	end

	pcall(vim.fn.sign_unplace, "dap_ext", {
		buffer = bp.config.bufnr,
		id = sign_id(bp),
	})

	-- 清行高亮
	pcall(vim.api.nvim_buf_clear_namespace, bp.config.bufnr, NS_LINE, 0, -1)
end

-- ============================================================
-- 渲染
-- ============================================================
function M.show_sign(bp)
	if not bp.config.bufnr or not bp.config.line then
		return
	end

	local id = sign_id(bp)

	-- 先清再放（避免重复）
	pcall(vim.fn.sign_unplace, "dap_ext", {
		buffer = bp.config.bufnr,
		id = id,
	})

	vim.fn.sign_place(id, "dap_ext", M.get_sign_type(bp), bp.config.bufnr, {
		lnum = bp.config.line,
		priority = 10,
	})

	-- 行高亮（只做一层）
	vim.api.nvim_buf_set_extmark(bp.config.bufnr, NS_LINE, bp.config.line - 1, 0, {
		hl_group = "DapBreakpointLine",
		hl_eol = true,
		priority = 5,
	})
end

-- ============================================================
-- hit marker（统一）
-- ============================================================
function M.show_hit(bp)
	if not bp.config.bufnr or not bp.config.line then
		return
	end

	local bufnr = bp.config.bufnr
	local line = bp.config.line

	-- 清空旧 hit
	vim.api.nvim_buf_clear_namespace(bufnr, NS_HIT, 0, -1)

	local id = sign_id(bp) + 9999

	vim.fn.sign_place(id, "dap_ext", "DapExtBreakpointHit", bufnr, {
		lnum = line,
		priority = 20,
	})

	vim.api.nvim_buf_set_extmark(bufnr, NS_HIT, line - 1, 0, {
		hl_group = "DapStopped",
		hl_eol = true,
		priority = 15,
	})

	-- 自动清理
	vim.defer_fn(function()
		pcall(vim.fn.sign_unplace, "dap_ext", { id = id })
		pcall(vim.api.nvim_buf_clear_namespace, bufnr, NS_HIT, 0, -1)
	end, 1500)
end

-- ============================================================
-- 全量刷新（关键 API）
-- ============================================================
function M.render_all()
	for _, bp in pairs(registry.bps) do
		M.show_sign(bp)
	end
end

function M.clear_all()
	for _, bp in pairs(registry.bps) do
		M.clear_sign(bp)
	end
end

-- ============================================================
-- 事件绑定（统一入口）
-- ============================================================
Event.on("bp_hit", function(bp)
	M.show_hit(bp)
end)

return M
