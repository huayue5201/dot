-- json_store/sync/relocator.lua
local anchor = require("json_store.data.anchor")

local M = {}

-- 简单 diff：只关心行插入/删除导致的偏移
local function compute_line_delta(old_lines, new_lines)
	local old_count = #old_lines
	local new_count = #new_lines
	return new_count - old_count
end

-- 应用 diff + anchor 双策略
function M.relocate(bufnr, line, anchor_obj)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return line
	end

	local lines = anchor.get_buf_lines(bufnr)
	if line < 1 or line > #lines then
		-- 行号已经超出范围，尝试 anchor 匹配
		local best = anchor.find_best_match(bufnr, anchor_obj)
		return best or line
	end

	-- 优先 anchor 匹配
	local best = anchor.find_best_match(bufnr, anchor_obj)
	if best then
		return best
	end

	-- fallback：保持原行
	return line
end

return M
