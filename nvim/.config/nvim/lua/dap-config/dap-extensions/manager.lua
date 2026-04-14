local registry = require("dap-config.dap-extensions.registry")
local sync = require("dap-config.dap-extensions.sync")
local sign = require("dap-config.dap-extensions.ui.sign")
local Event = require("dap-config.dap-extensions.event")

local M = {}

M.session = nil
M.types = {}

-- 持久化断点位置
local breakpoint_locations = {}

function M.register_type(name, ctor)
	M.types[name] = ctor
end

-- ============================================================
-- 创建断点
-- ============================================================
function M.create(type, cfg)
	local bp = M.types[type]:new(cfg)
	registry.add(bp)

	-- 恢复历史位置
	if breakpoint_locations[bp.id] then
		local loc = breakpoint_locations[bp.id]
		bp.config.bufnr = loc.bufnr
		bp.config.line = loc.line
		bp.status = "verified"

		if M.session then
			sign.show_sign(bp)
		end
	end

	if M.session then
		sync.sync(M.session)
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

-- ============================================================
-- 查询 / 清理
-- ============================================================
function M.list_breakpoints()
	local result = {}
	for id, bp in pairs(registry.bps) do
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
	sign.clear_all()
	breakpoint_locations = {}
	registry.bps = {}
	registry.map = {}
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
-- 更新断点位置（核心）
-- ============================================================
local function update_breakpoint_location(session, bp)
	if not session then
		return
	end

	session:request("stackTrace", {
		threadId = session.current_thread_id,
		levels = 1,
	}, function(err, resp)
		if err or not resp or not resp.stackFrames or #resp.stackFrames == 0 then
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
		if not bufnr then
			return
		end

		-- 更新位置
		bp.config.bufnr = bufnr
		bp.config.line = frame.line
		bp.status = "verified"

		-- 持久化
		breakpoint_locations[bp.id] = {
			bufnr = bufnr,
			line = frame.line,
		}

		-- 更新 UI（只做一件事：render）
		sign.show_sign(bp)
	end)
end

-- ============================================================
-- session 初始化
-- ============================================================
function M.on_session(session)
	M.session = session

	for _, bp in pairs(registry.bps) do
		if bp.config.bufnr and bp.config.line then
			sign.show_sign(bp)
		end
	end

	sync.sync(session, nil)
end

-- ============================================================
-- 停止事件（断点命中）
-- ============================================================
function M.on_stopped(session, event)
	M.session = session
	session.current_thread_id = event.threadId

	-- 同步断点
	sync.sync(session, event)

	-- function breakpoint
	local hit_ids = event.hitBreakpointIds or {}
	for _, id in ipairs(hit_ids) do
		local bp = registry.resolve(tostring(id))
		if bp and bp.type == "function" then
			update_breakpoint_location(session, bp)

			-- ✅ 统一 UI 入口
			Event.emit("bp_hit", bp)
		end
	end

	-- data breakpoint
	if event.body and event.body.breakpoints then
		for _, hit_bp in ipairs(event.body.breakpoints) do
			if hit_bp.dataId then
				local bp = registry.resolve(hit_bp.dataId)
				if bp and bp.type == "data" then
					update_breakpoint_location(session, bp)

					-- ✅ 同样走事件
					Event.emit("bp_hit", bp)
				end
			end
		end
	end
end

return M
