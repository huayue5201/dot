-- dap-config/dap-extensions/ui/virtual_text.lua

local Event = require("dap-config.dap-extensions.event")
local registry = require("dap-config.dap-extensions.registry")

local M = {}

local NS = vim.api.nvim_create_namespace("dap_ext_virtual")

-- id -> {bufnr, extmark_id}
local marks = {}

---------------------------------------------------------------------
-- utils
---------------------------------------------------------------------
local function valid(buf, line)
	return buf and vim.api.nvim_buf_is_loaded(buf) and line >= 0 and line < vim.api.nvim_buf_line_count(buf)
end

local function del_mark(id)
	local m = marks[id]
	if not m then
		return
	end

	if vim.api.nvim_buf_is_loaded(m.bufnr) then
		pcall(vim.api.nvim_buf_del_extmark, m.bufnr, NS, m.extmark_id)
	end

	marks[id] = nil
end

---------------------------------------------------------------------
-- clear
---------------------------------------------------------------------
function M.clear_for_bp(bp)
	if not bp or not bp.id then
		return
	end
	del_mark(bp.id)
end

function M.clear_all()
	for id, _ in pairs(marks) do
		del_mark(id)
	end
end

---------------------------------------------------------------------
-- render
---------------------------------------------------------------------
local function build_text(bp)
	local msg = bp.expression or bp.function_name or bp.type or "bp"
	local info = "🔥 " .. msg

	if bp.config then
		if bp.config.condition and bp.config.condition ~= "" then
			info = info .. " [if: " .. bp.config.condition .. "]"
		end

		if bp.config.hitCondition and bp.config.hitCondition ~= "" then
			info = info .. " [hit: " .. bp.config.hitCondition .. "]"
		end

		if bp.config.accessType and bp.config.accessType ~= "write" then
			info = info .. " [" .. bp.config.accessType .. "]"
		end

		if bp.config.instruction_reference then
			info = info .. " [addr: " .. bp.config.instruction_reference .. "]"
		end
	end

	return info
end

function M.show(bp)
	if not bp or not bp.config then
		return
	end

	local buf = bp.config.bufnr
	local line = bp.config.line - 1

	if not valid(buf, line) then
		return
	end

	del_mark(bp.id)

	local text = build_text(bp)

	local id = vim.api.nvim_buf_set_extmark(buf, NS, line, 0, {
		virt_text = { { text, "WarningMsg" } },
		virt_text_pos = "eol", -- 🔥 不再用 overlay
		priority = 200,
	})

	marks[bp.id] = {
		bufnr = buf,
		extmark_id = id,
	}
end

---------------------------------------------------------------------
-- render_all（核心）
---------------------------------------------------------------------
function M.refresh_all()
	M.clear_all()

	-----------------------------------------------------------------
	-- 1. ext breakpoints
	-----------------------------------------------------------------
	for _, bp in pairs(registry.bps) do
		if bp.status == "verified" or bp.status == "hit" then
			M.show(bp)
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
						status = "verified",
						config = {
							bufnr = bufnr,
							line = bp.line,
							condition = bp.condition,
							hitCondition = bp.hit_condition,
						},
					}

					M.show(fake_bp)
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- events
---------------------------------------------------------------------
Event.on("bp_hit", function(bp)
	M.show(bp)
end)

Event.on("breakpoint_deleted", function(bp)
	M.clear_for_bp(bp)
end)

return M
