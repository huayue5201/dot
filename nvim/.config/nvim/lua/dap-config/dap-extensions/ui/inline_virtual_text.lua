-- dap-config/dap-extensions/ui/inline_virtual_text.lua
local Event = require("dap-config.dap-extensions.event")
local registry = require("dap-config.dap-extensions.registry")

local M = {}

local NS = vim.api.nvim_create_namespace("dap_ext_inline")
local inline_marks = {}

-- 获取光标下的标识符边界
local function get_identifier_at_cursor(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return nil
	end

	-- 查找标识符边界（支持中文、字母、数字、下划线）
	local start_pos = col
	local end_pos = col

	while start_pos > 0 and line:sub(start_pos, start_pos):match("[%w_%a\u{4e00}-\u{9fff}]") do
		start_pos = start_pos - 1
	end
	if start_pos < col then
		start_pos = start_pos + 1
	else
		return nil
	end

	while end_pos <= #line and line:sub(end_pos, end_pos):match("[%w_%a\u{4e00}-\u{9fff}]") do
		end_pos = end_pos + 1
	end
	end_pos = end_pos - 1

	if start_pos <= end_pos then
		return {
			start = start_pos - 1, -- 转换为 0-based
			text = line:sub(start_pos, end_pos),
		}
	end
	return nil
end

-- 获取光标下的函数调用位置
local function get_function_call_at_cursor(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return nil
	end

	-- 查找函数调用模式：标识符 + '('
	local start_pos = col
	while start_pos > 0 and line:sub(start_pos, start_pos):match("[%w_%a]") do
		start_pos = start_pos - 1
	end
	if start_pos < col then
		start_pos = start_pos + 1
	else
		return nil
	end

	-- 检查后面是否有 '('
	local after_text = line:sub(col + 1, col + 20)
	if after_text:match("^%s*%(") then
		return {
			start = start_pos - 1,
			text = line:sub(start_pos, col),
		}
	end
	return nil
end

-- 获取光标下的表达式边界
local function get_expression_at_cursor(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return nil
	end

	-- 查找表达式边界（变量、字段访问、方法调用）
	local patterns = {
		{ pattern = "[%w_%a\u{4e00}-\u{9fff}]+%.[%w_%a\u{4e00}-\u{9fff}]+", desc = "field access" },
		{ pattern = "[%w_%a\u{4e00}-\u{9fff}]+%s*%(", desc = "function call" },
		{ pattern = "[%w_%a\u{4e00}-\u{9fff}]+", desc = "identifier" },
	}

	for _, p in ipairs(patterns) do
		local start_pos = col
		while start_pos > 0 do
			local sub = line:sub(start_pos, col)
			if sub:match(p.pattern .. "$") then
				local match_start = start_pos
				local match_end = col
				while match_end <= #line and line:sub(match_end, match_end):match("[%w_%a\u{4e00}-\u{9fff}%._]") do
					match_end = match_end + 1
				end
				return {
					start = match_start - 1,
					text = line:sub(match_start, match_end - 1),
				}
			end
			start_pos = start_pos - 1
		end
	end
	return nil
end

--- 获取最佳的标记位置
--- @param bufnr integer
--- @param row integer 0-based
--- @param col integer 0-based
--- @return integer|nil start_col
local function get_best_marker_position(bufnr, row, col)
	-- 优先级：标识符 > 函数调用 > 表达式 > 光标位置
	local identifier = get_identifier_at_cursor(bufnr, row, col)
	if identifier then
		return identifier.start + #identifier.text
	end

	local func_call = get_function_call_at_cursor(bufnr, row, col)
	if func_call then
		return func_call.start + #func_call.text
	end

	local expr = get_expression_at_cursor(bufnr, row, col)
	if expr then
		return expr.start + #expr.text
	end

	-- 默认在光标后
	return col + 1
end

--- 清理指定断点的内联标记
function M.clear_for_bp(bp)
	if not bp or not bp.id then
		return
	end

	local mark_info = inline_marks[bp.id]
	if not mark_info then
		return
	end

	local buf = mark_info.bufnr
	if vim.api.nvim_buf_is_loaded(buf) then
		pcall(vim.api.nvim_buf_del_extmark, buf, NS, mark_info.extmark_id)
	end

	inline_marks[bp.id] = nil
end

--- 清理所有内联标记
function M.clear_all()
	for _, bp in pairs(registry.bps) do
		if bp.type == "inline" then
			M.clear_for_bp(bp)
		end
	end
end

--- 显示内联断点标记（在表达式/字段旁边）
--- @param bp table
function M.show(bp)
	if not bp or bp.type ~= "inline" then
		return
	end

	local bufnr = bp.config.bufnr
	if not bufnr or not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local line = bp.config.line
	local column = bp.config.column or 1

	-- 转换为 0-based
	local row = line - 1
	local col = column - 1

	-- 清理旧标记
	M.clear_for_bp(bp)

	-- 获取该行的内容
	local line_content = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line_content then
		return
	end

	-- 获取最佳标记位置（在标识符后面）
	local marker_col = get_best_marker_position(bufnr, row, col)
	if marker_col and marker_col > #line_content then
		marker_col = #line_content
	end

	-- 构建显示文本
	local text = "󰨮  "
	if bp.config.condition then
		text = text .. " " .. bp.config.condition
	end
	if bp.config.hitCondition then
		text = text .. " [x" .. bp.config.hitCondition .. "]"
	end

	-- 设置虚拟文本（在表达式/字段后面）
	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, NS, row, marker_col or col, {
		virt_text = { { text, "DapExtInlineBreakpoint" } },
		virt_text_pos = "overlay",
		priority = 100,
	})

	inline_marks[bp.id] = {
		bufnr = bufnr,
		row = row,
		col = marker_col or col,
		extmark_id = extmark_id,
	}
end

-- 监听断点变化
Event.on("breakpoint_created", function(bp)
	if bp.type == "inline" then
		M.show(bp)
	end
end)

Event.on("breakpoint_deleted", function(bp)
	if bp.type == "inline" then
		M.clear_for_bp(bp)
	end
end)

Event.on("breakpoint_changed", function(bp)
	if bp.type == "inline" then
		M.show(bp)
	end
end)

return M
