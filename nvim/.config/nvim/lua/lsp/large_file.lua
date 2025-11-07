--- 大文件检测模块
-- 负责文件大小和行数检测，管理大文件相关的 LSP 状态
local M = {}

-- =============================================
-- 配置和状态
-- =============================================

-- 大文件检测配置
M.config = {
	-- 启用大文件检测的 LSP 列表
	enabled_lsps = {
		"vtsls", -- TypeScript/JavaScript 语言服务器
	},

	-- 默认文件大小阈值 (3MB)
	default_threshold = 3 * 1024 * 1024,

	-- 默认行数阈值 (50000 行)
	default_line_threshold = 50000,
}

-- 当前已检测到的大文件状态
M.state = {
	current_buffer = nil,
	large_files = {}, -- 存储已检测到的大文件路径和对应的 LSP 状态
}

-- =============================================
-- 阈值获取函数
-- =============================================

-- 获取行数阈值
function M.get_line_threshold()
	return M.config.default_line_threshold
end

-- 获取文件大小阈值
function M.get_file_threshold()
	return M.config.default_threshold
end

-- =============================================
-- 文件检测函数
-- =============================================

-- 检查当前缓冲区行数
function M.check_buffer_line_count(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end
	return vim.api.nvim_buf_line_count(bufnr)
end

-- 检查当前缓冲区文件大小
function M.check_buffer_file_size(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)

	if filename == "" or not vim.loop.fs_stat then
		return nil -- 新文件或无法获取文件信息
	end

	local stat = vim.loop.fs_stat(filename)
	return stat and stat.size or nil
end

-- =============================================
-- 大文件判断逻辑
-- =============================================

-- 检查特定 LSP 是否启用大文件检测
function M.should_check_file_size(lsp_name)
	return vim.tbl_contains(M.config.enabled_lsps, lsp_name)
end

-- 判断特定 LSP 是否因文件过大需要禁用（同时考虑大小和行数）
function M.should_disable_lsp_due_to_size(lsp_name, bufnr)
	local project_state = require("lsp.project_state")

	-- 首先检查该 LSP 是否在项目中被禁用
	if not project_state.is_lsp_enabled(lsp_name) then
		return false -- 已经在项目中被禁用，不需要大文件检测
	end

	-- 然后检查该 LSP 是否启用大文件检测
	if not M.should_check_file_size(lsp_name) then
		return false
	end

	local file_size = M.check_buffer_file_size(bufnr)
	local line_count = M.check_buffer_line_count(bufnr)

	-- 如果无法获取文件大小和行数，默认启用
	if not file_size and not line_count then
		return false
	end

	local size_threshold = M.get_file_threshold()
	local line_threshold = M.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	if is_large_file then
		local reasons = {}
		if is_large_by_size then
			table.insert(reasons, string.format("大小(%dMB)", math.floor(file_size / 1024 / 1024)))
		end
		if is_large_by_lines then
			table.insert(reasons, string.format("行数(%d行)", line_count))
		end

		vim.notify(
			string.format("检测到大文件 (%s)，已禁用 %s LSP", table.concat(reasons, ", "), lsp_name),
			vim.log.levels.WARN
		)
	end

	return is_large_file
end

-- =============================================
-- 状态查询函数
-- =============================================

-- 获取大文件状态信息
function M.get_large_file_status(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	local file_size = M.check_buffer_file_size(bufnr)
	local line_count = M.check_buffer_line_count(bufnr)

	if not file_size and not line_count then
		return { status = "unknown" }
	end

	local size_threshold = M.get_file_threshold()
	local line_threshold = M.get_line_threshold()

	local is_large_by_size = file_size and file_size > size_threshold
	local is_large_by_lines = line_count and line_count > line_threshold
	local is_large_file = is_large_by_size or is_large_by_lines

	local file_state = M.state.large_files[filename]
	local disabled_lsps = file_state and file_state.lsps_disabled or {}

	local status_details = {}
	if is_large_by_size then
		table.insert(status_details, "文件大小过大")
	end
	if is_large_by_lines then
		table.insert(status_details, "文件行数过多")
	end

	return {
		status = is_large_file and "large" or "normal",
		size = file_size,
		lines = line_count,
		size_mb = file_size and string.format("%.2fMB", file_size / 1024 / 1024) or "未知",
		lines_count = line_count and tostring(line_count) or "未知",
		threshold_mb = string.format("%.2fMB", size_threshold / 1024 / 1024),
		threshold_lines = tostring(line_threshold),
		disabled_lsps = disabled_lsps,
		is_large_file = is_large_file,
		status_details = status_details,
		is_large_by_size = is_large_by_size,
		is_large_by_lines = is_large_by_lines,
	}
end

return M -- 大文件检测功能
