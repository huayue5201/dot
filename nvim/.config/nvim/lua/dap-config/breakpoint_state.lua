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
		local line_count = vim.api.nvim_buf_line_count(bufnr)

		for _, bp in ipairs(buf_bps) do
			if bp.line <= line_count then
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
			else
				breakpoints.clear(bufnr, bp.line)
			end
		end

		if #enriched > 0 then
			store.set(NAMESPACE, path, enriched)
		else
			store.delete(NAMESPACE, path)
		end
	else
		store.delete(NAMESPACE, path)
	end

	-- 新版本自动保存，不需要手动调用 store.save()
end

-- 恢复断点
function M.load_breakpoints()
	local all_bps = store.get_all(NAMESPACE)

	if not all_bps then
		return
	end

	for path, buf_bps in pairs(all_bps) do
		local bufnr = vim.fn.bufnr(path, true)
		if bufnr ~= -1 then
			local line_count = vim.api.nvim_buf_line_count(bufnr)
			local valid_bps = {}

			for _, bp in ipairs(buf_bps) do
				if bp.line <= line_count then
					breakpoints.set({
						condition = bp.condition,
						log_message = bp.log_message,
						hit_condition = bp.hit_condition,
					}, bufnr, bp.line)

					table.insert(valid_bps, bp)
				end
			end

			if #valid_bps > 0 then
				store.set(NAMESPACE, path, valid_bps)
			else
				store.delete(NAMESPACE, path)
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
	end
end

-- 清除所有断点
function M.clear_all_breakpoints()
	breakpoints.clear()
	-- 清空整个命名空间
	local all = store.get_all(NAMESPACE)
	if all then
		for path, _ in pairs(all) do
			store.delete(NAMESPACE, path)
		end
	end
end

-- 自动恢复 + 自动同步
function M.setup_autoload()
	-- 打开文件时恢复断点
	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			local path = vim.api.nvim_buf_get_name(args.buf)
			if path and path ~= "" then
				local buf_bps = store.get(NAMESPACE, path)
				if buf_bps then
					local line_count = vim.api.nvim_buf_line_count(args.buf)
					local valid_bps = {}

					for _, bp in ipairs(buf_bps) do
						if bp.line <= line_count then
							breakpoints.set({
								condition = bp.condition,
								log_message = bp.log_message,
								hit_condition = bp.hit_condition,
							}, args.buf, bp.line)
							table.insert(valid_bps, bp)
						end
					end

					if #valid_bps > 0 then
						store.set(NAMESPACE, path, valid_bps)
					else
						store.delete(NAMESPACE, path)
					end
				end
			end
		end,
		desc = "自动恢复 DAP 断点",
	})

	-- 编辑或保存时同步断点状态
	vim.api.nvim_create_autocmd({ "TextChanged", "BufWritePost" }, {
		callback = function()
			M.sync_breakpoints()
		end,
		desc = "同步并清理已删除行的断点",
	})

	-- 提供手动命令 :DapSyncBreakpoints
	vim.api.nvim_create_user_command("DapSyncBreakpoints", function()
		M.sync_breakpoints()
		vim.notify("断点已同步并清理", vim.log.levels.INFO)
	end, { desc = "手动同步并清理断点" })
end

return M
