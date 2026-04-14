-- dap-config/dap-extensions/ui/virtual_text.lua
local Event = require("dap-config.dap-extensions.event")
local registry = require("dap-config.dap-extensions.registry")

local M = {}

local NS = vim.api.nvim_create_namespace("dap_ext_virtual")

-- 存储每个断点对应的虚拟文本 extmark id
local virtual_text_marks = {}

--- 清理指定断点的虚拟文本
--- @param bp table
function M.clear_for_bp(bp)
	if not bp or not bp.id then
		return
	end

	local mark_info = virtual_text_marks[bp.id]
	if not mark_info then
		return
	end

	local buf = mark_info.bufnr
	local line = mark_info.line

	if vim.api.nvim_buf_is_loaded(buf) then
		pcall(vim.api.nvim_buf_clear_namespace, buf, NS, line, line + 1)
	end

	virtual_text_marks[bp.id] = nil
end

--- 清理指定 buffer 的虚拟文本
--- @param bufnr? integer
function M.clear(bufnr)
	if bufnr then
		vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
	else
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
			end
		end
	end

	-- 清空存储的标记
	virtual_text_marks = {}
end

--- 清理所有断点的虚拟文本（按断点遍历）
function M.clear_all_for_breakpoints()
	for _, bp in pairs(registry.bps) do
		M.clear_for_bp(bp)
	end
end

--- 显示断点的虚拟文本（持久化，跟随断点）
--- @param bp table
function M.show(bp)
	if not bp or not bp.config or not bp.config.bufnr or not bp.config.line then
		return
	end

	local buf = bp.config.bufnr
	if not vim.api.nvim_buf_is_loaded(buf) then
		return
	end

	local line = bp.config.line - 1
	if line < 0 then
		return
	end

	-- 先清理该断点之前的虚拟文本
	M.clear_for_bp(bp)

	local msg = bp.expression or bp.function_name or bp.type or "breakpoint"
	local info = "🔥 " .. msg

	if bp.config.condition and bp.config.condition ~= "" then
		info = info .. " [if: " .. bp.config.condition .. "]"
	end

	if bp.config.hitCondition and bp.config.hitCondition ~= "" then
		info = info .. " [hit: " .. bp.config.hitCondition .. "]"
	end

	-- 添加访问类型（数据断点）
	if bp.config.accessType and bp.config.accessType ~= "write" then
		info = info .. " [" .. bp.config.accessType .. "]"
	end

	-- 添加地址信息（硬件断点）
	if bp.config.instruction_reference then
		info = info .. " [addr: " .. bp.config.instruction_reference .. "]"
	end

	local extmark_id = vim.api.nvim_buf_set_extmark(buf, NS, line, 0, {
		virt_text = { { info, "WarningMsg" } },
		virt_text_pos = "eol",
	})

	-- 存储虚拟文本信息，用于后续清理
	virtual_text_marks[bp.id] = {
		bufnr = buf,
		line = line,
		extmark_id = extmark_id,
	}
end

--- 刷新所有断点的虚拟文本
function M.refresh_all()
	M.clear_all_for_breakpoints()
	for _, bp in pairs(registry.bps) do
		if bp.status == "verified" or bp.status == "hit" then
			M.show(bp)
		end
	end
end

-- 监听断点命中事件
Event.on("bp_hit", function(bp)
	if not bp or not bp.config or not bp.config.bufnr then
		return
	end
	M.show(bp)
end)

-- 监听断点删除事件（需要在 manager 中触发）
Event.on("breakpoint_deleted", function(bp)
	M.clear_for_bp(bp)
end)

return M
