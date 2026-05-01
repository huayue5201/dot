-- dap-config/dap-extensions/manager.lua
local registry = require("dap-config.dap-extensions.registry")
local sign = require("dap-config.dap-extensions.ui.sign")
local Event = require("dap-config.dap-extensions.event")
local resolver = require("dap-config.dap-extensions.resolver")
local sync = require("dap-config.dap-extensions.sync")

local M = {}

M.session = nil
M.types = {}

function M.register_type(name, ctor)
	M.types[name] = ctor
end

function M.create(type, cfg)
	local ctor = M.types[type]
	if not ctor then
		error("unknown breakpoint type: " .. tostring(type))
	end

	local bp = ctor:new(cfg)
	registry.add(bp)

	Event.emit("breakpoint_created", bp)

	if M.session then
		sign.show_sign(bp)
	end

	return bp
end

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

function M.add_column_breakpoint(line, column, opts)
	opts = opts or {}
	return M.create("column", {
		line = line,
		column = column,
		condition = opts.condition,
		hitCondition = opts.hitCondition,
		bufnr = vim.api.nvim_get_current_buf(),
	})
end

function M.add_inline_breakpoint(line, column, opts)
	vim.notify("add_inline_breakpoint is deprecated, use add_column_breakpoint", vim.log.levels.WARN)
	return M.add_column_breakpoint(line, column, opts)
end

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

function M.clear_breakpoints()
	for _, bp in pairs(registry.bps) do
		Event.emit("breakpoint_deleted", bp)
	end

	sign.clear_all()

	local ok, column_vt = pcall(require, "dap-config.dap-extensions.ui.column_virtual_text")
	if ok and column_vt and column_vt.clear_all then
		column_vt.clear_all()
	end

	registry.clear()

	if M.session then
		pcall(sync.sync, M.session, nil)
	end

	Event.emit("breakpoints_cleared")
end

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

	Event.emit("breakpoint_changed", bp)
end

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

	if old_bufnr ~= bufnr or old_line ~= frame.line then
		sign.show_sign(bp)
		local virtual_text = require("dap-config.dap-extensions.ui.virtual_text")
		virtual_text.show(bp)
		Event.emit("breakpoint_location_updated", bp)
	end

	if old_status ~= bp.status then
		Event.emit("breakpoint_status_changed", bp)
	end

	Event.emit("breakpoint_changed", bp)
end

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
