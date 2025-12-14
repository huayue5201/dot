-- lua/dap-config/breakpoint_state.lua
local breakpoints = require("dap.breakpoints")
local store = require("user.json_store")

local M = {}
local NAMESPACE = "dap_breakpoints"

-- 同步当前 buffer 的断点状态到 json_store
function M.sync_breakpoints()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if not path or path == "" then
		return
	end

	local by_buf = breakpoints.get()
	local buf_bps = by_buf[bufnr]

	if buf_bps and #buf_bps > 0 then
		local enriched = {}
		for _, bp in ipairs(buf_bps) do
			local condition = bp.condition
			local log_message = bp.log_message or bp.logMessage
			local hit_condition = bp.hit_condition or bp.hitCondition

			local bp_type = "normal"
			if condition and condition ~= "" then
				bp_type = "condition"
			elseif log_message and log_message ~= "" then
				bp_type = "log"
			elseif hit_condition and hit_condition ~= "" then
				bp_type = "hit"
			end

			table.insert(enriched, {
				line = bp.line,
				condition = condition,
				log_message = log_message,
				hit_condition = hit_condition,
				type = bp_type,
			})
		end
		store.set(NAMESPACE, path, enriched)
	else
		store.delete(NAMESPACE, path)
	end

	store.save()
end

-- 恢复断点
function M.load_breakpoints()
	local all_bps = store.get_all(NAMESPACE)
	for path, buf_bps in pairs(all_bps) do
		local bufnr = vim.fn.bufnr(path, true)
		if bufnr ~= -1 then
			for _, bp in pairs(buf_bps) do
				breakpoints.set({
					condition = bp.condition,
					log_message = bp.log_message,
					hit_condition = bp.hit_condition,
				}, bufnr, bp.line)
			end
		end
	end
end

-- 清除当前 buffer 的断点
function M.clear_breakpoints()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path and path ~= "" then
		breakpoints.clear(bufnr)
		store.delete(NAMESPACE, path)
		store.save()
	end
end

-- 清除所有断点
function M.clear_all_breakpoints()
	breakpoints.clear()
	store.delete(NAMESPACE)
	store.save()
end

-- 自动恢复
function M.setup_autoload()
	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			local path = vim.api.nvim_buf_get_name(args.buf)
			if path and path ~= "" then
				local all_bps = store.get_all(NAMESPACE)
				local buf_bps = all_bps[path]
				if buf_bps then
					for _, bp in pairs(buf_bps) do
						breakpoints.set({
							condition = bp.condition,
							log_message = bp.log_message,
							hit_condition = bp.hit_condition,
						}, args.buf, bp.line)
					end
				end
			end
		end,
		desc = "自动恢复 DAP 断点",
	})
end

return M
