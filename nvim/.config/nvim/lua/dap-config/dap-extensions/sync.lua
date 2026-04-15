-- dap-config/dap-extensions/sync.lua
-- DAP 断点同步模块
local registry = require("dap-config.dap-extensions.registry")
local resolver = require("dap-config.dap-extensions.resolver")
local sign = require("dap-config.dap-extensions.ui.sign")
local Event = require("dap-config.dap-extensions.event")

local M = {}

-- 兼容层
if sign then
	if not sign.update_sign then
		sign.update_sign = sign.show_sign or function() end
	end
end

-- 断点同步处理器注册表
local sync_handlers = {}

function M.register_handler(breakpoint_type, handler)
	sync_handlers[breakpoint_type] = handler
end

-- ============================================================
-- path -> bufnr 辅助函数
-- ============================================================
local function path_to_bufnr(path)
	if not path then
		return nil
	end
	if path:sub(1, 1) == "/" then
		return vim.fn.bufadd(path)
	end
	if path:match("^file://") then
		return vim.uri_to_bufnr(path)
	end
	local bufnr = vim.fn.bufadd(path)
	if bufnr and bufnr > 0 then
		return bufnr
	end
	local ok, result = pcall(vim.uri_to_bufnr, path)
	if ok and result then
		return result
	end
	return nil
end

-- ============================================================
-- function breakpoint sync
-- ============================================================
local function sync_function_breakpoints(session, function_bps)
	if #function_bps == 0 then
		return
	end

	local breakpoints = {}
	for _, bp_item in ipairs(function_bps) do
		local bp_def = { name = bp_item.name }
		if bp_item.condition then
			bp_def.condition = bp_item.condition
		end
		if bp_item.hitCondition then
			bp_def.hitCondition = bp_item.hitCondition
		end
		table.insert(breakpoints, bp_def)
	end

	session:request("setFunctionBreakpoints", {
		breakpoints = breakpoints,
	}, function(err, resp)
		if err then
			for _, bp_item in ipairs(function_bps) do
				bp_item._bp.status = "rejected"
				sign.update_sign(bp_item._bp)
				Event.emit("breakpoint_status_changed", bp_item._bp)
			end
			return
		end

		if resp and resp.breakpoints then
			for i, bp_resp in ipairs(resp.breakpoints) do
				if function_bps[i] then
					local bp = function_bps[i]._bp
					local old_status = bp.status
					if bp_resp.verified then
						bp.status = "verified"
						if bp_resp.id then
							registry.link(bp_resp.id, bp)
						end
					else
						bp.status = "rejected"
					end
					sign.update_sign(bp)

					if old_status ~= bp.status then
						Event.emit("breakpoint_status_changed", bp)
					end
					Event.emit("breakpoint_changed", bp)
				end
			end
		end
	end)
end

M.register_handler("function", function(session, bps)
	local function_bps = {}
	for _, bp in ipairs(bps) do
		table.insert(function_bps, {
			name = bp.function_name,
			_bp = bp,
			condition = bp.config.condition,
			hitCondition = bp.config.hitCondition,
		})
	end
	sync_function_breakpoints(session, function_bps)
end)

-- ============================================================
-- data breakpoint sync
-- ============================================================
local function sync_data_breakpoints(session, event, data_bps)
	if #data_bps == 0 then
		return
	end

	local frame = resolver.get_current_frame(session, event)
	if not frame then
		for _, bp in ipairs(data_bps) do
			bp.status = "rejected"
			sign.update_sign(bp)
			Event.emit("breakpoint_status_changed", bp)
		end
		return
	end

	local frameId = frame.id
	local pending = #data_bps
	local data_breakpoints = {}

	for _, bp in ipairs(data_bps) do
		if bp.status ~= "pending" then
			pending = pending - 1
			goto continue
		end

		session:request("dataBreakpointInfo", {
			name = bp.expression,
			frameId = frameId,
		}, function(err, resp)
			if err or not resp or not resp.dataId then
				bp.status = "rejected"
				sign.update_sign(bp)
				Event.emit("breakpoint_status_changed", bp)
			else
				local dataId = resp.dataId
				bp.dataId = dataId
				registry.link(dataId, bp)

				local bp_def = {
					dataId = dataId,
					accessType = bp.accessType or "write",
				}
				if bp.condition then
					bp_def.condition = bp.condition
				end
				if bp.hitCondition then
					bp_def.hitCondition = bp.hitCondition
				end
				table.insert(data_breakpoints, bp_def)
			end

			pending = pending - 1
			if pending == 0 then
				if #data_breakpoints > 0 then
					session:request("setDataBreakpoints", {
						breakpoints = data_breakpoints,
					}, function(err2, resp2)
						if err2 then
							for _, bp in ipairs(data_bps) do
								if bp.status == "pending" then
									bp.status = "rejected"
									sign.update_sign(bp)
									Event.emit("breakpoint_status_changed", bp)
								end
							end
							return
						end

						if resp2 and resp2.breakpoints then
							for i, bp_resp in ipairs(resp2.breakpoints) do
								if data_breakpoints[i] then
									local bp = registry.resolve(data_breakpoints[i].dataId)
									if bp and bp.status == "pending" then
										local old_status = bp.status
										bp.status = bp_resp.verified and "verified" or "rejected"
										sign.update_sign(bp)
										if old_status ~= bp.status then
											Event.emit("breakpoint_status_changed", bp)
										end
										Event.emit("breakpoint_changed", bp)
									end
								end
							end
						end
					end)
				else
					for _, bp in ipairs(data_bps) do
						if bp.status == "pending" then
							bp.status = "rejected"
							sign.update_sign(bp)
							Event.emit("breakpoint_status_changed", bp)
						end
					end
				end
			end
		end)

		::continue::
	end
end

M.register_handler("data", function(session, bps, event)
	sync_data_breakpoints(session, event, bps)
end)

-- ============================================================
-- instruction breakpoint (硬件断点)
-- ============================================================
M.register_handler("instruction", function(session, bps)
	if #bps == 0 then
		return
	end

	local breakpoints = {}
	for _, bp in ipairs(bps) do
		local bp_def = {
			instructionReference = bp.instruction_reference,
			offset = bp.offset or 0,
		}
		if bp.config.condition and bp.config.condition ~= "" then
			bp_def.condition = bp.config.condition
		end
		if bp.config.hitCondition and bp.config.hitCondition ~= "" then
			bp_def.hitCondition = bp.config.hitCondition
		end
		if bp.accessType then
			bp_def.accessType = bp.accessType
		end
		if bp.size then
			bp_def.size = bp.size
		end
		table.insert(breakpoints, bp_def)
	end

	session:request("setInstructionBreakpoints", {
		breakpoints = breakpoints,
	}, function(err, resp)
		if err then
			for _, bp in ipairs(bps) do
				bp.status = "rejected"
				sign.update_sign(bp)
				Event.emit("breakpoint_status_changed", bp)
			end
			return
		end

		if resp and resp.breakpoints then
			for i, bp_resp in ipairs(resp.breakpoints) do
				if bps[i] then
					local bp = bps[i]
					local old_status = bp.status
					if bp_resp.verified then
						bp.status = "verified"
						if bp_resp.id then
							registry.link(bp_resp.id, bp)
						end
						if bp_resp.source and bp_resp.line then
							local bufnr = path_to_bufnr(bp_resp.source.path)
							if bufnr then
								bp.config.bufnr = bufnr
								bp.config.line = bp_resp.line
							end
						end
					else
						bp.status = "rejected"
					end
					sign.update_sign(bp)

					if old_status ~= bp.status then
						Event.emit("breakpoint_status_changed", bp)
					end
					Event.emit("breakpoint_changed", bp)
				end
			end
		end
	end)
end)

-- ============================================================
-- inline breakpoint (内联断点)
-- ============================================================
M.register_handler("inline", function(session, bps, event)
	-- 内联断点通过 nvim-dap 原生管理，这里只需标记状态
	for _, bp in ipairs(bps) do
		local old_status = bp.status
		bp.status = "verified"
		if sign.update_sign then
			sign.update_sign(bp)
		end
		if old_status ~= bp.status then
			Event.emit("breakpoint_status_changed", bp)
		end
		Event.emit("breakpoint_changed", bp)
	end
end)

-- ============================================================
-- core sync
-- ============================================================
function M.sync(session, event)
	if not session then
		return
	end

	local grouped = {}
	for _, bp in pairs(registry.bps) do
		-- 只同步启用状态的断点
		if bp.status == "pending" and bp.enabled ~= false then
			grouped[bp.type] = grouped[bp.type] or {}
			table.insert(grouped[bp.type], bp)
		end
	end

	for bp_type, bps in pairs(grouped) do
		local handler = sync_handlers[bp_type]
		if handler then
			handler(session, bps, event)
		else
			for _, bp in ipairs(bps) do
				bp.status = "rejected"
				sign.update_sign(bp)
				Event.emit("breakpoint_status_changed", bp)
			end
			vim.notify("Unknown breakpoint type: " .. bp_type, vim.log.levels.WARN)
		end
	end
end

function M.resync(session, event)
	if not session then
		return
	end
	for _, bp in pairs(registry.bps) do
		if bp.status == "verified" or bp.status == "hit" then
			bp.status = "pending"
		end
	end
	M.sync(session, event)
end

function M.clear_all(session)
	if not session then
		registry.bps = {}
		registry.map = {}
		return
	end
	for bp_type, _ in pairs(sync_handlers) do
		if bp_type == "function" then
			session:request("setFunctionBreakpoints", { breakpoints = {} }, function() end)
		elseif bp_type == "data" then
			session:request("setDataBreakpoints", { breakpoints = {} }, function() end)
		elseif bp_type == "instruction" then
			session:request("setInstructionBreakpoints", { breakpoints = {} }, function() end)
		end
	end
	registry.bps = {}
	registry.map = {}
end

function M.get_registered_types()
	local types = {}
	for t, _ in pairs(sync_handlers) do
		table.insert(types, t)
	end
	return types
end

return M
