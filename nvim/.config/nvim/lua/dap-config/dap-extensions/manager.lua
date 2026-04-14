-- dap-config/dap-extensions/manager.lua
-- DAP Extensions 核心管理器
local registry = require("dap-config.dap-extensions.registry")
local sign = require("dap-config.dap-extensions.ui.sign")
local Event = require("dap-config.dap-extensions.event")
local resolver = require("dap-config.dap-extensions.resolver")
local sync = require("dap-config.dap-extensions.sync")

local M = {}

-- 当前调试 session
M.session = nil
-- 断点类型注册表：name -> ctor
M.types = {}

-- 持久化断点位置（仅在当前 Neovim 会话内）
local breakpoint_locations = {}

--- 注册断点类型
--- @param name string
--- @param ctor table 带 new(cfg) 的构造器
function M.register_type(name, ctor)
	M.types[name] = ctor
end

-- ============================================================
-- 创建断点
-- ============================================================

--- 内部创建断点
--- @param type string
--- @param cfg table
--- @return table bp
function M.create(type, cfg)
	local ctor = M.types[type]
	if not ctor then
		error("unknown breakpoint type: " .. tostring(type))
	end

	local bp = ctor:new(cfg)
	registry.add(bp)

	-- 触发断点创建事件
	Event.emit("breakpoint_created", bp)

	-- 如果有历史位置（当前会话内），恢复之
	local loc = breakpoint_locations[bp.id]
	if loc and loc.bufnr and loc.line then
		if vim.api.nvim_buf_is_loaded(loc.bufnr) then
			bp.config.bufnr = loc.bufnr
			bp.config.line = loc.line
			bp.status = bp.status or "verified"
			if M.session then
				sign.show_sign(bp)
			end
		end
	end

	return bp
end

--- 添加函数断点
--- @param function_name string
--- @param opts table|nil
--- @return table
function M.add_function_breakpoint(function_name, opts)
	opts = opts or {}
	return M.create("function", {
		function_name = function_name,
		condition = opts.condition,
		hitCondition = opts.hitCondition,
		bufnr = opts.bufnr,
		line = opts.line,
	})
end

--- 添加数据断点
--- @param expression string
--- @param opts table|nil
--- @return table
function M.add_data_breakpoint(expression, opts)
	opts = opts or {}
	return M.create("data", {
		expression = expression,
		accessType = opts.accessType or "write",
		condition = opts.condition,
		hitCondition = opts.hitCondition,
		bufnr = opts.bufnr,
		line = opts.line,
	})
end

--- 添加硬件执行断点
function M.add_hardware_execute_breakpoint(address, opts)
	opts = opts or {}
	return M.create("instruction", {
		instruction_reference = address,
		offset = opts.offset or 0,
		accessType = "execute",
		condition = opts.condition,
		hitCondition = opts.hitCondition,
	})
end

--- 添加硬件读断点
function M.add_hardware_read_breakpoint(address, size, opts)
	opts = opts or {}
	return M.create("instruction", {
		instruction_reference = address,
		offset = 0,
		accessType = "read",
		size = size or 1,
		condition = opts.condition,
		hitCondition = opts.hitCondition,
	})
end

--- 添加硬件写断点
function M.add_hardware_write_breakpoint(address, size, opts)
	opts = opts or {}
	return M.create("instruction", {
		instruction_reference = address,
		offset = 0,
		accessType = "write",
		size = size or 1,
		condition = opts.condition,
		hitCondition = opts.hitCondition,
	})
end

--- 添加硬件读写断点
function M.add_hardware_access_breakpoint(address, size, opts)
	opts = opts or {}
	return M.create("instruction", {
		instruction_reference = address,
		offset = 0,
		accessType = "readWrite",
		size = size or 1,
		condition = opts.condition,
		hitCondition = opts.hitCondition,
	})
end

-- ============================================================
-- 查询 / 清理
-- ============================================================

--- 列出所有断点
function M.list_breakpoints()
	local result = {}
	for _, bp in pairs(registry.bps) do
		table.insert(result, {
			id = bp.id,
			type = bp.type,
			status = bp.status,
			config = bp.config,
		})
	end
	return result
end

--- 清除所有断点
function M.clear_breakpoints()
	-- 触发每个断点的删除事件
	for _, bp in pairs(registry.bps) do
		Event.emit("breakpoint_deleted", bp)
	end

	sign.clear_all()
	breakpoint_locations = {}
	registry.clear()

	if M.session then
		pcall(sync.sync, M.session, nil)
	end

	Event.emit("breakpoints_cleared")
end

--- 删除单个断点
--- @param bp_id string
function M.remove_breakpoint(bp_id)
	local bp = registry.resolve(bp_id)
	if not bp then
		return
	end

	Event.emit("breakpoint_deleted", bp)
	registry.remove(bp_id)
	sign.clear_sign(bp)

	if M.session then
		pcall(sync.sync, M.session, nil)
	end

	Event.emit("breakpoint_changed")
end

-- ============================================================
-- path -> bufnr
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
-- 更新断点位置
-- ============================================================

local function update_breakpoint_location(session, bp)
	if not session or not bp then
		return
	end

	local threadId = session.current_thread_id or resolver.get_main_thread_id(session)
	if not threadId then
		return
	end

	local ok, resp = pcall(function()
		return session:request_sync("stackTrace", {
			threadId = threadId,
			levels = 1,
			startFrame = 0,
		})
	end)

	if not ok or not resp or not resp.stackFrames or #resp.stackFrames == 0 then
		return
	end

	local frame = resp.stackFrames[1]
	if not frame or not frame.source or not frame.line then
		return
	end

	local file_path = frame.source.path or frame.source.name
	if not file_path then
		return
	end

	local bufnr = path_to_bufnr(file_path)
	if not bufnr or not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local old_bufnr = bp.config.bufnr
	local old_line = bp.config.line
	local old_status = bp.status

	bp.config.bufnr = bufnr
	bp.config.line = frame.line
	bp.status = bp.status or "verified"

	breakpoint_locations[bp.id] = {
		bufnr = bufnr,
		line = frame.line,
	}

	-- 位置变化时更新 UI
	if old_bufnr ~= bufnr or old_line ~= frame.line then
		sign.show_sign(bp)
		local virtual_text = require("dap-config.dap-extensions.ui.virtual_text")
		virtual_text.show(bp)
		Event.emit("breakpoint_location_updated", bp)
	end

	-- 状态变化时触发事件
	if old_status ~= bp.status then
		Event.emit("breakpoint_status_changed", bp)
	end

	Event.emit("breakpoint_changed", bp)
end

-- ============================================================
-- session 初始化
-- ============================================================

function M.on_session(session)
	M.session = session
	session.current_thread_id = session.current_thread_id or resolver.get_main_thread_id(session)

	for _, bp in pairs(registry.bps) do
		if bp.config and bp.config.bufnr and bp.config.line then
			sign.show_sign(bp)
		end
	end

	pcall(sync.sync, session, nil)
end

-- ============================================================
-- 停止事件（断点命中）
-- ============================================================

function M.on_stopped(session, event)
	M.session = session

	if event and event.threadId then
		session.current_thread_id = event.threadId
	else
		session.current_thread_id = session.current_thread_id or resolver.get_main_thread_id(session)
	end

	pcall(sync.sync, session, event)

	local hit_ids = (event and event.hitBreakpointIds) or {}
	for _, id in ipairs(hit_ids) do
		local bp = registry.resolve(id)
		if bp and bp.type == "function" then
			update_breakpoint_location(session, bp)
			Event.emit("bp_hit", bp)
		end
	end

	if event and event.body and event.body.breakpoints then
		for _, hit_bp in ipairs(event.body.breakpoints) do
			if hit_bp.dataId then
				local bp = registry.resolve(hit_bp.dataId)
				if bp and bp.type == "data" then
					update_breakpoint_location(session, bp)
					Event.emit("bp_hit", bp)
				end
			end
		end
	end
end

return M
