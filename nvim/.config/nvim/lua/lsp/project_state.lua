-- lua/lsp/project_state.lua
local json_store = require("utils.json_store")

local M = {}

-- =============================================
-- 状态存储初始化
-- =============================================

-- 创建 JSON 存储实例（集成项目级和缓冲区级状态）
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
	auto_save = false,
})

-- 内存缓存
M._buffer_states_cache = {}

-- =============================================
-- 项目标识管理
-- =============================================

-- 获取当前项目唯一标识
function M.get_current_project_id()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 获取文件的绝对路径键
function M.get_file_key(file_path)
	if not file_path or file_path == "" then
		return nil
	end
	return vim.fn.fnamemodify(file_path, ":p")
end

-- =============================================
-- 状态存储操作
-- =============================================

-- 安全加载状态
function M.load_project_states()
	if state_store.get_all then
		return state_store:get_all()
	end
	return state_store:load()
end

-- 延迟保存状态
function M.save_project_states(states)
	state_store:save(states)
	vim.defer_fn(function()
		if state_store.flush then
			state_store:flush()
		end
	end, 100)
end

-- =============================================
-- 项目级 LSP 状态管理
-- =============================================

-- 检查特定 LSP 是否启用（支持缓冲区级覆盖）
function M.is_lsp_enabled(lsp_name, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- 1. 先检查缓冲区级状态（最高优先级）
	local buffer_enabled = M.get_buffer_lsp_state(bufnr, lsp_name)
	if buffer_enabled ~= nil then
		return buffer_enabled
	end

	-- 2. 再检查项目级状态
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id]

	if not project_states or not project_states.lsp_states or not project_states.lsp_states[lsp_name] then
		return true -- 默认启用
	end

	return project_states.lsp_states[lsp_name].enabled
end

-- 设置 LSP 启用状态（项目级）
function M.set_lsp_state(lsp_name, enabled)
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()

	states[project_id] = states[project_id] or {}
	states[project_id].lsp_states = states[project_id].lsp_states or {}
	states[project_id].lsp_states[lsp_name] = {
		enabled = enabled,
		timestamp = os.time(),
	}

	M.save_project_states(states)

	vim.notify(string.format("LSP %s: %s", lsp_name, enabled and "已启用" or "已禁用"), vim.log.levels.INFO)
end

-- 获取当前项目所有 LSP 状态
function M.get_project_lsp_states()
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id] or {}
	return project_states.lsp_states or {}
end

-- =============================================
-- 缓冲区级 LSP 状态管理
-- =============================================

-- 设置缓冲区级 LSP 状态
function M.set_buffer_lsp_state(bufnr, lsp_name, enabled)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local file_key = M.get_file_key(file_path)
	if not file_key then
		-- 无名缓冲区，只使用内存缓存
		M._buffer_states_cache[bufnr] = M._buffer_states_cache[bufnr] or {}
		M._buffer_states_cache[bufnr][lsp_name] = enabled
		return
	end

	-- 有名缓冲区，持久化存储
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()

	states[project_id] = states[project_id] or {}
	states[project_id].buffer_states = states[project_id].buffer_states or {}
	states[project_id].buffer_states[file_key] = states[project_id].buffer_states[file_key] or {}
	states[project_id].buffer_states[file_key][lsp_name] = enabled and true or false

	-- 同时更新内存缓存
	M._buffer_states_cache[bufnr] = M._buffer_states_cache[bufnr] or {}
	M._buffer_states_cache[bufnr][lsp_name] = enabled

	M.save_project_states(states)
end

-- 获取缓冲区级 LSP 状态
function M.get_buffer_lsp_state(bufnr, lsp_name)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- 先检查内存缓存
	if M._buffer_states_cache[bufnr] then
		local cached = M._buffer_states_cache[bufnr][lsp_name]
		if cached ~= nil then
			return cached
		end
	end

	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local file_key = M.get_file_key(file_path)
	if not file_key then
		return nil
	end

	-- 从持久化存储加载
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id] or {}
	local buffer_states = project_states.buffer_states or {}

	if not buffer_states[file_key] then
		return nil
	end

	local value = buffer_states[file_key][lsp_name]

	-- 更新内存缓存
	M._buffer_states_cache[bufnr] = M._buffer_states_cache[bufnr] or {}
	M._buffer_states_cache[bufnr][lsp_name] = value

	return value
end

-- 获取缓冲区的所有 LSP 状态
function M.get_all_buffer_states(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- 先检查内存缓存
	if M._buffer_states_cache[bufnr] then
		return vim.deepcopy(M._buffer_states_cache[bufnr])
	end

	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local file_key = M.get_file_key(file_path)
	if not file_key then
		return {}
	end

	-- 从持久化存储加载
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id] or {}
	local buffer_states = project_states.buffer_states or {}
	local file_states = buffer_states[file_key] or {}

	-- 更新内存缓存
	M._buffer_states_cache[bufnr] = vim.deepcopy(file_states)

	return file_states
end

-- 清理缓冲区状态（当缓冲区关闭时）
function M.cleanup_buffer_state(bufnr)
	-- 只清理内存缓存，持久化数据保留
	M._buffer_states_cache[bufnr] = nil
end

-- 获取当前缓冲区被禁用的 LSP 列表
function M.get_disabled_lsps_for_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local states = M.get_all_buffer_states(bufnr)
	local disabled = {}

	for lsp_name, enabled in pairs(states) do
		if enabled == false then
			table.insert(disabled, lsp_name)
		end
	end

	return disabled
end

-- =============================================
-- 工具函数
-- =============================================

-- 获取当前项目的所有缓冲区状态
function M.get_project_buffer_states()
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id] or {}
	return project_states.buffer_states or {}
end

-- 清理无效的缓冲区状态（文件不存在的）
function M.cleanup_invalid_buffer_states()
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id] or {}
	local buffer_states = project_states.buffer_states or {}

	local valid_states = {}
	local cleaned_count = 0

	for file_key, file_states in pairs(buffer_states) do
		-- 检查文件是否存在
		if vim.fn.filereadable(file_key) == 1 then
			valid_states[file_key] = file_states
		else
			cleaned_count = cleaned_count + 1
		end
	end

	if cleaned_count > 0 then
		project_states.buffer_states = valid_states
		states[project_id] = project_states
		M.save_project_states(states)
		vim.notify(string.format("清理了 %d 个无效的缓冲区状态", cleaned_count), vim.log.levels.INFO)
	end

	return cleaned_count
end

-- 显示项目状态统计
function M.show_project_stats()
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id] or {}

	local lsp_count = 0
	if project_states.lsp_states then
		lsp_count = vim.tbl_count(project_states.lsp_states)
	end

	local buffer_count = 0
	if project_states.buffer_states then
		buffer_count = vim.tbl_count(project_states.buffer_states)
	end

	print("=== 项目状态统计 ===")
	print(string.format("项目: %s", project_id))
	print(string.format("项目级 LSP 状态: %d 个", lsp_count))
	print(string.format("缓冲区级 LSP 状态: %d 个文件", buffer_count))

	if project_states.buffer_states then
		for file_key, file_states in pairs(project_states.buffer_states) do
			local file_name = vim.fn.fnamemodify(file_key, ":t")
			local state_count = vim.tbl_count(file_states)
			print(string.format("  %s: %d 个 LSP 状态", file_name, state_count))
		end
	end
end

return M
