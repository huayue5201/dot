local M = {}

function M.check(buf, ctx, callback)
	ctx = ctx or {}
	local max_length = ctx.max_length or 500
	local chunk_size = ctx.chunk_size or 1000
	local total_lines = vim.api.nvim_buf_line_count(buf)

	if total_lines == 0 then
		callback(false)
		return
	end

	local current_line = 0
	local stopped = false

	local function check_chunk()
		if stopped or current_line >= total_lines then
			if not stopped then
				callback(false) -- 没有命中
			end
			return
		end

		local end_line = math.min(current_line + chunk_size, total_lines)
		local lines = vim.api.nvim_buf_get_lines(buf, current_line, end_line, false) -- 使用 false 避免复制

		for i, line in ipairs(lines) do
			if #line > max_length then
				stopped = true
				callback(true, string.format("line %d too long (%d > %d)", current_line + i, #line, max_length))
				return
			end
		end

		current_line = end_line
		vim.defer_fn(check_chunk, 0) -- 下一块继续
	end

	check_chunk()
end

return M
