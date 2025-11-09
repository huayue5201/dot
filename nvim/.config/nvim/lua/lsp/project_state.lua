-- lua/lsp/project_state.lua
local json_store = require("utils.json_store")

local M = {}

-- =============================================
-- 统一状态存储初始化
-- =============================================

-- 单一存储文件
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/lsp_states.json",
	default_data = {},
	auto_save = true,
})

-- =============================================
-- 项目标识管理
-- =============================================

function M.get_current_project_id()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

function M.get_buffer_key(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)

	if file_path and file_path ~= "" then
		return vim.fn.fnamemodify(file_path, ":p")
	else
		return "buffer_" .. tostring(bufnr)
	end
end

-- =============================================
-- 统一存储结构设计
-- =============================================

local function get_project_data(project_id)
	local all_data = state_store:load()
	all_data[project_id] = all_data[project_id]
		or {
			project_states = {}, -- 项目级状态 {lsp_name: true/false}
			buffer_states = {}, -- 缓冲区级状态 {buffer_key: {lsp_name: true/false}}
		}
	return all_data[project_id]
end

local function save_project_data(project_id, project_data)
	local all_data = state_store:load()
	all_data[project_id] = project_data
	state_store:set(project_id, all_data[project_id])
end

-- =============================================
-- 项目级 LSP 状态管理
-- =============================================

function M.is_lsp_enabled(lsp_name)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)

	local state = project_data.project_states[lsp_name]
	if state ~= nil then
		return state
	end

	return true -- 默认启用
end

function M.set_lsp_state(lsp_name, enabled)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)

	project_data.project_states[lsp_name] = enabled

	save_project_data(project_id, project_data)

	if enabled then
		vim.notify(string.format("LSP %s: 项目级启用", lsp_name), vim.log.levels.INFO)
	else
		vim.notify(string.format("LSP %s: 项目级禁用", lsp_name), vim.log.levels.WARN)
	end
end

function M.get_project_lsp_states()
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)
	return project_data.project_states or {}
end

-- =============================================
-- 缓冲区级 LSP 状态管理
-- =============================================

function M.set_buffer_lsp_state(bufnr, lsp_name, enabled)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer_key = M.get_buffer_key(bufnr)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)

	project_data.buffer_states = project_data.buffer_states or {}
	project_data.buffer_states[buffer_key] = project_data.buffer_states[buffer_key] or {}
	project_data.buffer_states[buffer_key][lsp_name] = enabled

	save_project_data(project_id, project_data)

	if enabled then
		vim.notify(string.format("LSP %s: 缓冲区级启用", lsp_name), vim.log.levels.INFO)
	else
		vim.notify(string.format("LSP %s: 缓冲区级禁用", lsp_name), vim.log.levels.WARN)
	end
end

function M.get_buffer_lsp_state(bufnr, lsp_name)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer_key = M.get_buffer_key(bufnr)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)

	local buffer_states = project_data.buffer_states or {}
	local buffer_state = buffer_states[buffer_key] or {}

	return buffer_state[lsp_name] -- 直接返回 true/false，如果没有记录则返回 nil
end

function M.get_all_buffer_states(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer_key = M.get_buffer_key(bufnr)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)

	local buffer_states = project_data.buffer_states or {}
	return buffer_states[buffer_key] or {}
end

function M.cleanup_buffer_state(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer_key = M.get_buffer_key(bufnr)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)

	if project_data.buffer_states then
		project_data.buffer_states[buffer_key] = nil
		save_project_data(project_id, project_data)
	end
end

function M.get_disabled_lsps_for_buffer(bufnr)
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
-- 组合状态检查（缓冲区级优先级更高）
-- =============================================

function M.is_lsp_enabled_for_buffer(lsp_name, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	-- 1. 先检查缓冲区级状态（最高优先级）
	local buffer_enabled = M.get_buffer_lsp_state(bufnr, lsp_name)
	if buffer_enabled ~= nil then
		return buffer_enabled
	end

	-- 2. 再检查项目级状态
	return M.is_lsp_enabled(lsp_name)
end

-- =============================================
-- 项目级操作工具函数
-- =============================================

-- 获取需要应用项目级操作的缓冲区列表
function M.get_buffers_for_project_operation(lsp_name, project_enabled)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)
	local buffer_states = project_data.buffer_states or {}
	local eligible_buffers = {}

	for buffer_key, buffer_lsp_states in pairs(buffer_states) do
		local buffer_enabled = buffer_lsp_states[lsp_name]

		-- 如果缓冲区没有该 LSP 的状态记录，或者状态与项目操作一致，则符合条件
		if buffer_enabled == nil or buffer_enabled == project_enabled then
			table.insert(eligible_buffers, buffer_key)
		end
		-- 如果 buffer_enabled 与 project_enabled 相反，则排除该缓冲区
	end

	return eligible_buffers
end

-- 获取所有缓冲区的状态统计
function M.get_buffer_stats_for_lsp(lsp_name)
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)
	local buffer_states = project_data.buffer_states or {}

	local stats = {
		total = 0,
		enabled = 0,
		disabled = 0,
		no_override = 0,
	}

	for buffer_key, buffer_lsp_states in pairs(buffer_states) do
		stats.total = stats.total + 1
		local buffer_enabled = buffer_lsp_states[lsp_name]

		if buffer_enabled == true then
			stats.enabled = stats.enabled + 1
		elseif buffer_enabled == false then
			stats.disabled = stats.disabled + 1
		else
			stats.no_override = stats.no_override + 1
		end
	end

	return stats
end

-- =============================================
-- 工具函数
-- =============================================

function M.get_project_buffer_states()
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)
	return project_data.buffer_states or {}
end

function M.cleanup_invalid_buffer_states()
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)
	local buffer_states = project_data.buffer_states or {}
	local valid_states = {}
	local cleaned_count = 0

	for buffer_key, lsp_states in pairs(buffer_states) do
		local is_valid = false

		if buffer_key:match("^buffer_%d+$") then
			-- 临时缓冲区状态，检查缓冲区是否仍然有效
			local bufnr = tonumber(buffer_key:match("buffer_(%d+)"))
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				is_valid = true
			end
		else
			-- 文件路径状态，检查文件是否存在
			if vim.fn.filereadable(buffer_key) == 1 then
				is_valid = true
			end
		end

		if is_valid then
			valid_states[buffer_key] = lsp_states
		else
			cleaned_count = cleaned_count + 1
		end
	end

	if cleaned_count > 0 then
		project_data.buffer_states = valid_states
		save_project_data(project_id, project_data)
		vim.notify(string.format("清理了 %d 个无效的缓冲区状态", cleaned_count), vim.log.levels.INFO)
	end

	return cleaned_count
end

function M.show_project_stats()
	local project_id = M.get_current_project_id()
	local project_data = get_project_data(project_id)
	local project_states = project_data.project_states or {}
	local buffer_states = project_data.buffer_states or {}

	print("=== LSP 状态统计 ===")
	print(string.format("项目: %s", project_id))
	print(string.format("项目级 LSP 状态: %d 个", vim.tbl_count(project_states)))
	print(string.format("缓冲区级状态: %d 个文件/缓冲区", vim.tbl_count(buffer_states)))

	-- 显示项目级状态
	if not vim.tbl_isempty(project_states) then
		print("\n项目级 LSP 状态:")
		for lsp_name, enabled in pairs(project_states) do
			local status = enabled and "启用" or "禁用"
			print(string.format("  %s: %s", lsp_name, status))

			-- 显示该 LSP 的缓冲区统计
			local stats = M.get_buffer_stats_for_lsp(lsp_name)
			if stats.total > 0 then
				print(
					string.format(
						"    缓冲区: %d启用 %d禁用 %d无覆盖",
						stats.enabled,
						stats.disabled,
						stats.no_override
					)
				)
			end
		end
	end

	-- 显示有缓冲区级状态的 LSP
	local lsp_with_buffer_states = {}
	for buffer_key, lsp_states in pairs(buffer_states) do
		for lsp_name, enabled in pairs(lsp_states) do
			if not lsp_with_buffer_states[lsp_name] then
				lsp_with_buffer_states[lsp_name] = { enabled = 0, disabled = 0 }
			end
			if enabled then
				lsp_with_buffer_states[lsp_name].enabled = lsp_with_buffer_states[lsp_name].enabled + 1
			else
				lsp_with_buffer_states[lsp_name].disabled = lsp_with_buffer_states[lsp_name].disabled + 1
			end
		end
	end

	if not vim.tbl_isempty(lsp_with_buffer_states) then
		print("\n有缓冲区级状态的 LSP:")
		for lsp_name, stats in pairs(lsp_with_buffer_states) do
			local project_enabled = M.is_lsp_enabled(lsp_name)
			local project_status = project_enabled and "（项目启用）" or "（项目禁用）"
			print(string.format("  %s%s: %d启用 %d禁用", lsp_name, project_status, stats.enabled, stats.disabled))
		end
	end
end

return M
