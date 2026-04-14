local Event = require("dap-config.dap-extensions.event")

local M = {}

local NS = vim.api.nvim_create_namespace("dap_ext_virtual")

function M.clear(bufnr)
	if bufnr then
		vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
	else
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
		end
	end
end

function M.show(bp)
	if not bp.config.bufnr or not bp.config.line then
		return
	end

	local buf = bp.config.bufnr
	local line = bp.config.line - 1

	local msg = bp.expression or bp.function_name or bp.type

	local info = "🔥 " .. msg

	if bp.config.condition and bp.config.condition ~= "" then
		info = info .. " [if: " .. bp.config.condition .. "]"
	end

	if bp.config.hitCondition and bp.config.hitCondition ~= "" then
		info = info .. " [hit: " .. bp.config.hitCondition .. "]"
	end

	vim.api.nvim_buf_set_extmark(buf, NS, line, 0, {
		virt_text = { { info, "WarningMsg" } },
		virt_text_pos = "eol",
	})

	-- 自动清除
	vim.defer_fn(function()
		vim.api.nvim_buf_clear_namespace(buf, NS, line, line + 1)
	end, 1500)
end

Event.on("bp_hit", function(bp)
	M.clear(bp.config.bufnr)
	M.show(bp)
end)

return M
