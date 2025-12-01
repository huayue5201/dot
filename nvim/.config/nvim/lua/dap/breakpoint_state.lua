-- lua/dap/breakpoint_state.lua
local M = {}
local breakpoints = require("dap.breakpoints")
local json_store = require("user.json_store")

-- 规范化文件路径
local function normalize_path(path)
	if not path or path == "" then
		return nil
	end
	return vim.fn.fnamemodify(path, ":p")
end

-- 1. 自动保存断点
function M.save_breakpoints()
	local breakpoints_by_buf = breakpoints.get()
	local serialized = {}
	local saved_count = 0

	for buf, buf_bps in pairs(breakpoints_by_buf) do
		local filepath = vim.api.nvim_buf_get_name(buf)
		local full_path = normalize_path(filepath)

		if full_path and vim.fn.filereadable(full_path) == 1 then
			serialized[full_path] = {}

			for _, bp in ipairs(buf_bps) do
				table.insert(serialized[full_path], {
					line = bp.line,
					condition = bp.condition,
					logMessage = bp.logMessage,
					hitCondition = bp.hitCondition,
				})
				saved_count = saved_count + 1
			end
		end
	end

	json_store.set("dap", "breakpoints", serialized)
	print("💾 保存了 " .. saved_count .. " 个断点到 JSON 存储")
	return true
end

-- 2. 自动恢复断点
function M.restore_breakpoints()
	local serialized = json_store.get("dap", "breakpoints") or {}
	local restored_count = 0

	-- 先检查所有已打开的缓冲区
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local filepath = vim.api.nvim_buf_get_name(bufnr)
			local full_path = normalize_path(filepath)

			if full_path and serialized[full_path] then
				for _, bp in ipairs(serialized[full_path]) do
					local opts = {}
					if bp.condition and bp.condition ~= "" then
						opts.condition = bp.condition
					end
					if bp.logMessage and bp.logMessage ~= "" then
						opts.log_message = bp.logMessage
					end
					if bp.hitCondition and bp.hitCondition ~= "" then
						opts.hit_condition = bp.hitCondition
					end

					-- 设置断点
					breakpoints.set(opts, bufnr, bp.line)
					restored_count = restored_count + 1
				end

				-- 从待恢复列表中移除
				serialized[full_path] = nil
			end
		end
	end

	-- 对于未打开的缓冲区，可以稍后在文件打开时恢复
	-- 这里可以保存下来，在文件打开时再恢复
	if restored_count > 0 then
		print("🔄 恢复了 " .. restored_count .. " 个断点")
	end

	return restored_count
end

-- 3. 调试函数：查看存储的断点数据
function M.debug_breakpoints()
	local serialized = json_store.get("dap", "breakpoints") or {}
	print("=== 存储的断点数据 ===")
	for filepath, bps in pairs(serialized) do
		print("文件: " .. vim.fn.fnamemodify(filepath, ":~"))
		print("  断点数量: " .. #bps)
		for i, bp in ipairs(bps) do
			print("    断点 " .. i .. ": 第 " .. bp.line .. " 行")
			if bp.condition then
				print("      条件: " .. bp.condition)
			end
		end
	end
	print("======================")
end

-- 4. 清除存储的断点数据
function M.clear_breakpoints()
	json_store.delete("dap", "breakpoints")
	print("🧹 已清除所有存储的断点")
	return true
end

-- 5. 设置自动保存和自动恢复
function M.setup()
	-- 退出时自动保存
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.save_breakpoints()
		end,
		desc = "DAP: 退出时自动保存断点",
	})

	-- 延迟更长时间等待 DAP 插件完全加载
	vim.api.nvim_create_autocmd("User", {
		pattern = "DapStarted", -- 如果 DAP 有启动事件
		callback = function()
			vim.defer_fn(function()
				local count = M.restore_breakpoints()
				if count > 0 then
					print("✅ 恢复了 " .. count .. " 个断点")
				end
			end, 500)
		end,
		desc = "DAP: 启动时恢复断点",
	})

	-- 如果没有 DapStarted 事件，使用更通用的延迟
	vim.defer_fn(function()
		-- 尝试恢复断点
		local count = M.restore_breakpoints()
		if count > 0 then
			print("✅ 恢复了 " .. count .. " 个断点")
		end

		-- 设置断点变化时的自动保存
		local group = vim.api.nvim_create_augroup("DapBreakpointAutoSave", { clear = true })
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "DapBreakpointChanged",
			callback = function()
				vim.defer_fn(M.save_breakpoints, 200)
			end,
			desc = "DAP: 断点变化时自动保存",
		})

		-- 文件打开时尝试恢复该文件的断点
		vim.api.nvim_create_autocmd("BufReadPost", {
			group = group,
			callback = function(args)
				vim.defer_fn(function()
					local filepath = vim.api.nvim_buf_get_name(args.buf)
					local full_path = normalize_path(filepath)
					local serialized = json_store.get("dap", "breakpoints") or {}

					if full_path and serialized[full_path] then
						local restored = 0
						for _, bp in ipairs(serialized[full_path]) do
							local opts = {}
							if bp.condition and bp.condition ~= "" then
								opts.condition = bp.condition
							end
							if bp.logMessage and bp.logMessage ~= "" then
								opts.log_message = bp.logMessage
							end
							if bp.hitCondition and bp.hitCondition ~= "" then
								opts.hit_condition = bp.hitCondition
							end

							breakpoints.set(opts, args.buf, bp.line)
							restored = restored + 1
						end

						if restored > 0 then
							print(
								"📁 为 "
									.. vim.fn.fnamemodify(filepath, ":t")
									.. " 恢复了 "
									.. restored
									.. " 个断点"
							)
						end
					end
				end, 100)
			end,
			desc = "DAP: 文件打开时恢复断点",
		})
	end, 2000) -- 延迟 2 秒，确保所有插件加载完成

	-- 添加调试命令
	vim.api.nvim_create_user_command("DapDebugBreakpoints", M.debug_breakpoints, {
		desc = "调试断点存储状态",
	})

	vim.api.nvim_create_user_command("DapSaveBreakpoints", M.save_breakpoints, {
		desc = "手动保存断点",
	})

	vim.api.nvim_create_user_command("DapRestoreBreakpoints", M.restore_breakpoints, {
		desc = "手动恢复断点",
	})

	vim.api.nvim_create_user_command("DapClearBreakpoints", M.clear_breakpoints, {
		desc = "清除存储的断点",
	})

	return true
end

return M
