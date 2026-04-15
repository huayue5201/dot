-- lua/dap-config/breakpoint_state.lua
-- DAP 断点状态管理（支持原生断点 + dap-extensions 自定义断点）

local breakpoints = require("dap.breakpoints")
local M = {}

local NAMESPACE = "dap_breakpoints"
local EXT_NAMESPACE = "dap_ext_breakpoints"

---------------------------------------------------------------------
-- 工具：安全 key（避免路径中的 . 影响 namespace）
---------------------------------------------------------------------
local function encode_key(path)
	-- 简单可读的编码：替换 . 为 %.
	return (path or ""):gsub("%%", "%%%%"):gsub("%.", "%%.")
end

local function decode_key(key)
	return (key or ""):gsub("%%%.", "."):gsub("%%%%", "%%")
end

---------------------------------------------------------------------
-- 获取存储实例
---------------------------------------------------------------------
local function get_store()
	local ok, store = pcall(function()
		return require("nvim-store3").project()
	end)
	if not ok then
		return nil
	end
	return store
end

---------------------------------------------------------------------
-- 安全的断点数据提取（原生断点）
---------------------------------------------------------------------
local function safe_breakpoint_data(bp)
	return {
		line = type(bp.line) == "number" and bp.line or nil,
		condition = type(bp.condition) == "string" and bp.condition or nil,
		log_message = type(bp.log_message) == "string" and bp.log_message or nil,
		hit_condition = type(bp.hit_condition) == "string" and bp.hit_condition or nil,
		status = bp.status, -- 尽量保留状态信息
	}
end

---------------------------------------------------------------------
-- 同步当前 buffer 的原生断点（带轻微节流）
---------------------------------------------------------------------
local sync_timer

function M.sync_breakpoints()
	local store = get_store()
	if not store then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if not path or path == "" then
		return
	end

	local by_buf = breakpoints.get()
	local buf_bps = by_buf and by_buf[bufnr]

	local key = NAMESPACE .. "." .. encode_key(path)

	if buf_bps and #buf_bps > 0 then
		local enriched = {}
		local line_count = vim.api.nvim_buf_line_count(bufnr)

		for _, bp in ipairs(buf_bps) do
			if bp.line and type(bp.line) == "number" and bp.line <= line_count then
				local safe_bp = safe_breakpoint_data(bp)
				if safe_bp.line then
					table.insert(enriched, safe_bp)
				end
			elseif bp.line then
				breakpoints.clear(bufnr, bp.line)
			end
		end

		if #enriched > 0 then
			store:set(key, enriched)
		else
			store:delete(key)
		end
	else
		store:delete(key)
	end
end

local function schedule_sync_breakpoints()
	if sync_timer then
		sync_timer:stop()
		sync_timer:close()
		sync_timer = nil
	end
	sync_timer = vim.loop.new_timer()
	sync_timer:start(100, 0, function()
		vim.schedule(function()
			M.sync_breakpoints()
		end)
	end)
end

---------------------------------------------------------------------
-- 同步所有自定义断点
---------------------------------------------------------------------
function M.sync_ext_breakpoints()
	local store = get_store()
	if not store then
		return
	end

	local ok, dap_ext = pcall(require, "dap-config.dap-extensions.manager")
	if not ok then
		return
	end

	local bps = dap_ext.list_breakpoints()
	if not bps or #bps == 0 then
		store:delete(EXT_NAMESPACE)
		return
	end

	local to_save = {}
	for _, bp in ipairs(bps) do
		local save_bp = {
			type = bp.type,
			status = bp.status,
			config = {},
		}

		if bp.type == "function" then
			save_bp.config.function_name = bp.config.function_name
			save_bp.config.condition = bp.config.condition
			save_bp.config.hitCondition = bp.config.hitCondition
			if bp.config.bufnr and bp.config.line then
				save_bp.config.bufnr = bp.config.bufnr
				save_bp.config.line = bp.config.line
			end
		elseif bp.type == "data" then
			save_bp.config.expression = bp.config.expression
			save_bp.config.accessType = bp.config.accessType
			save_bp.config.condition = bp.config.condition
			save_bp.config.hitCondition = bp.config.hitCondition
			if bp.config.bufnr and bp.config.line then
				save_bp.config.bufnr = bp.config.bufnr
				save_bp.config.line = bp.config.line
			end
		elseif bp.type == "instruction" then
			save_bp.config.instruction_reference = bp.config.instruction_reference
			save_bp.config.offset = bp.config.offset
			save_bp.config.accessType = bp.config.accessType
			save_bp.config.size = bp.config.size
			save_bp.config.condition = bp.config.condition
			save_bp.config.hitCondition = bp.config.hitCondition
		end

		table.insert(to_save, save_bp)
	end

	if #to_save > 0 then
		store:set(EXT_NAMESPACE, to_save)
	else
		store:delete(EXT_NAMESPACE)
	end
end

---------------------------------------------------------------------
-- 同步所有断点
---------------------------------------------------------------------
function M.sync_all()
	M.sync_breakpoints()
	M.sync_ext_breakpoints()
end

---------------------------------------------------------------------
-- 恢复原生断点
---------------------------------------------------------------------
function M.load_breakpoints()
	local store = get_store()
	if not store then
		return
	end

	local keys = store:namespace_keys(NAMESPACE)
	for _, key in ipairs(keys) do
		local path = decode_key(key)
		local full_key = NAMESPACE .. "." .. key
		local buf_bps = store:get(full_key)

		if type(buf_bps) == "table" then
			if vim.fn.filereadable(path) == 0 then
				-- 文件不存在，跳过
				goto continue
			end

			local bufnr = vim.fn.bufnr(path, true)
			if bufnr ~= -1 then
				local line_count = vim.api.nvim_buf_line_count(bufnr)
				for _, bp in ipairs(buf_bps) do
					if bp.line and type(bp.line) == "number" and bp.line <= line_count then
						local bp_config = {}
						if bp.condition then
							bp_config.condition = bp.condition
						end
						if bp.log_message then
							bp_config.log_message = bp.log_message
						end
						if bp.hit_condition then
							bp_config.hit_condition = bp.hit_condition
						end
						breakpoints.set(bp_config, bufnr, bp.line)
					end
				end
			end
		end
		::continue::
	end
end

---------------------------------------------------------------------
-- 恢复自定义断点
---------------------------------------------------------------------
function M.load_ext_breakpoints()
	local store = get_store()
	if not store then
		return
	end

	local saved = store:get(EXT_NAMESPACE)
	if not saved or type(saved) ~= "table" then
		return
	end

	local ok, dap_ext = pcall(require, "dap-config.dap-extensions.manager")
	if not ok then
		return
	end

	for _, saved_bp in ipairs(saved) do
		local bp = nil
		if saved_bp.type == "function" then
			bp = dap_ext.add_function_breakpoint(saved_bp.config.function_name, {
				condition = saved_bp.config.condition,
				hitCondition = saved_bp.config.hitCondition,
				bufnr = saved_bp.config.bufnr,
				line = saved_bp.config.line,
			})
			-- 不强行覆盖 status，由调试器重新决定
		elseif saved_bp.type == "data" then
			bp = dap_ext.add_data_breakpoint(saved_bp.config.expression, {
				accessType = saved_bp.config.accessType,
				condition = saved_bp.config.condition,
				hitCondition = saved_bp.config.hitCondition,
				bufnr = saved_bp.config.bufnr,
				line = saved_bp.config.line,
			})
		elseif saved_bp.type == "instruction" then
			local access = saved_bp.config.accessType or "execute"
			local addr = saved_bp.config.instruction_reference
			if access == "execute" then
				bp = dap_ext.add_hardware_execute_breakpoint(addr, {
					offset = saved_bp.config.offset,
					condition = saved_bp.config.condition,
					hitCondition = saved_bp.config.hitCondition,
				})
			elseif access == "read" then
				bp = dap_ext.add_hardware_read_breakpoint(addr, saved_bp.config.size or 1, {
					condition = saved_bp.config.condition,
					hitCondition = saved_bp.config.hitCondition,
				})
			elseif access == "write" then
				bp = dap_ext.add_hardware_write_breakpoint(addr, saved_bp.config.size or 1, {
					condition = saved_bp.config.condition,
					hitCondition = saved_bp.config.hitCondition,
				})
			elseif access == "readWrite" then
				bp = dap_ext.add_hardware_access_breakpoint(addr, saved_bp.config.size or 1, {
					condition = saved_bp.config.condition,
					hitCondition = saved_bp.config.hitCondition,
				})
			end
		end

		if bp and bp.config.bufnr and bp.config.line then
			local ok_sign, sign = pcall(require, "dap-config.dap-extensions.ui.sign")
			if ok_sign then
				sign.show_sign(bp)
			end
		end
	end
end

---------------------------------------------------------------------
-- 恢复所有断点
---------------------------------------------------------------------
function M.load_all()
	M.load_breakpoints()
	M.load_ext_breakpoints()
end

---------------------------------------------------------------------
-- 清除当前 buffer 的原生断点
---------------------------------------------------------------------
function M.clear_breakpoints()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)

	if path and path ~= "" then
		breakpoints.clear(bufnr)
		local store = get_store()
		if store then
			store:delete(NAMESPACE .. "." .. encode_key(path))
		end
	end
end

---------------------------------------------------------------------
-- 清除所有断点（原生 + 自定义）
---------------------------------------------------------------------
function M.clear_all_breakpoints()
	breakpoints.clear()

	local store = get_store()
	if store then
		local keys = store:namespace_keys(NAMESPACE)
		for _, key in ipairs(keys) do
			store:delete(NAMESPACE .. "." .. key)
		end
		store:delete(EXT_NAMESPACE)
	end

	local ok, dap_ext = pcall(require, "dap-config.dap-extensions.manager")
	if ok then
		dap_ext.clear_breakpoints()
	end
end

---------------------------------------------------------------------
-- 手动保存/加载命令
---------------------------------------------------------------------
function M.save()
	M.sync_all()
	vim.notify("Breakpoints saved", vim.log.levels.INFO)
end

function M.load()
	M.load_all()
	vim.notify("Breakpoints loaded", vim.log.levels.INFO)
end

---------------------------------------------------------------------
-- 自动恢复和同步
---------------------------------------------------------------------
function M.setup_autoload()
	-- 打开文件时恢复原生断点
	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			local store = get_store()
			if not store then
				return
			end
			local path = vim.api.nvim_buf_get_name(args.buf)
			if path and path ~= "" then
				local key = NAMESPACE .. "." .. encode_key(path)
				local buf_bps = store:get(key)
				if buf_bps then
					local line_count = vim.api.nvim_buf_line_count(args.buf)
					for _, bp in ipairs(buf_bps) do
						if bp.line and type(bp.line) == "number" and bp.line <= line_count then
							local bp_config = {}
							if bp.condition then
								bp_config.condition = bp.condition
							end
							if bp.log_message then
								bp_config.log_message = bp.log_message
							end
							if bp.hit_condition then
								bp_config.hit_condition = bp.hit_condition
							end
							breakpoints.set(bp_config, args.buf, bp.line)
						end
					end
				end
			end
		end,
		desc = "自动恢复 DAP 断点",
	})

	-- 编辑或保存时同步原生断点（带轻微节流）
	vim.api.nvim_create_autocmd({ "TextChanged", "BufWritePost" }, {
		callback = function()
			schedule_sync_breakpoints()
		end,
		desc = "同步原生断点",
	})

	-- 监听自定义断点事件
	local ok, event = pcall(require, "dap-config.dap-extensions.event")
	if ok then
		local function delayed_sync()
			vim.defer_fn(M.sync_ext_breakpoints, 100)
		end
		event.on("breakpoint_created", delayed_sync)
		event.on("breakpoint_deleted", delayed_sync)
		event.on("breakpoint_status_changed", delayed_sync)
		event.on("breakpoint_location_updated", delayed_sync)
		event.on("breakpoint_changed", delayed_sync)
		event.on("breakpoints_cleared", delayed_sync)
		event.on("bp_hit", delayed_sync)
	end
end

---------------------------------------------------------------------
-- 初始化
---------------------------------------------------------------------
function M.setup()
	M.setup_autoload()
	-- 不在这里调用 load_all，避免与 BufReadPost 重复
	return M
end

return M
