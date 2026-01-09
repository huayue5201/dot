-- lua/dap-config/breakpoint_state.lua
-- DAP 断点状态管理（精简版，使用新架构）

local breakpoints = require("dap.breakpoints")
local M = {}
local NAMESPACE = "dap_breakpoints"

---------------------------------------------------------------------
-- 获取存储实例
---------------------------------------------------------------------
local function get_store()
	-- 使用新版本的 project 方法
	return require("nvim-store3").project()
end

---------------------------------------------------------------------
-- 安全的断点数据提取
---------------------------------------------------------------------
local function safe_breakpoint_data(bp)
	return {
		line = type(bp.line) == "number" and bp.line or nil,
		condition = type(bp.condition) == "string" and bp.condition or nil,
		log_message = type(bp.log_message) == "string" and bp.log_message or nil,
		hit_condition = type(bp.hit_condition) == "string" and bp.hit_condition or nil,
	}
end

---------------------------------------------------------------------
-- 同步当前 buffer 的断点状态
---------------------------------------------------------------------
function M.sync_breakpoints()
	local store = get_store()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	if not path or path == "" then
		return
	end

	local by_buf = breakpoints.get()
	local buf_bps = by_buf and by_buf[bufnr]

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
			-- 使用新的 API：store:set(key, value)
			store:set(NAMESPACE .. "." .. path, enriched)
		else
			-- 使用新的 API：store:delete(key)
			store:delete(NAMESPACE .. "." .. path)
		end
	else
		-- 使用新的 API：store:delete(key)
		store:delete(NAMESPACE .. "." .. path)
	end
end

---------------------------------------------------------------------
-- 恢复断点
---------------------------------------------------------------------
function M.load_breakpoints()
	local store = get_store()

	-- 使用新的 API：store:namespace_keys(namespace) 获取该命名空间下的所有键
	local keys = store:namespace_keys(NAMESPACE)

	for _, key in ipairs(keys) do
		-- key 是 path，不需要解码
		local path = key
		local buf_bps = store:get(NAMESPACE .. "." .. path)

		if type(buf_bps) == "table" then
			local bufnr = vim.fn.bufnr(path, true)

			if bufnr ~= -1 then
				for _, bp in ipairs(buf_bps) do
					if bp.line and type(bp.line) == "number" then
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
	end
end

---------------------------------------------------------------------
-- 清除当前 buffer 的断点
---------------------------------------------------------------------
function M.clear_breakpoints()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)

	if path and path ~= "" then
		breakpoints.clear(bufnr)
		get_store():delete(NAMESPACE .. "." .. path)
	end
end

---------------------------------------------------------------------
-- 清除所有断点
---------------------------------------------------------------------
function M.clear_all_breakpoints()
	breakpoints.clear()

	-- 删除整个命名空间的数据
	local store = get_store()
	local keys = store:namespace_keys(NAMESPACE)

	for _, key in ipairs(keys) do
		store:delete(NAMESPACE .. "." .. key)
	end
end

---------------------------------------------------------------------
-- 自动恢复和同步
---------------------------------------------------------------------
function M.setup_autoload()
	-- 打开文件时恢复断点
	vim.api.nvim_create_autocmd("BufReadPost", {
		callback = function(args)
			local store = get_store()
			local path = vim.api.nvim_buf_get_name(args.buf)

			if path and path ~= "" then
				local buf_bps = store:get(NAMESPACE .. "." .. path)

				if buf_bps then
					for _, bp in ipairs(buf_bps) do
						if bp.line and type(bp.line) == "number" then
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

	-- 编辑或保存时同步断点
	vim.api.nvim_create_autocmd({ "TextChanged", "BufWritePost" }, {
		callback = M.sync_breakpoints,
		desc = "同步并清理已删除行的断点",
	})
end

---------------------------------------------------------------------
-- 初始化
---------------------------------------------------------------------
function M.setup()
	M.setup_autoload()
	return M
end

return M
