local M = {}

-- 行数检测器
function M.check(buf, ctx, callback)
	-- 确保配置存在
	local max_lines = ctx.max_lines or 10000

	vim.defer_fn(function()
		if not vim.api.nvim_buf_is_valid(buf) then
			return callback(false, "buffer invalid")
		end

		local lines = vim.api.nvim_buf_line_count(buf)
		if lines > max_lines then
			callback(true, string.format("too many lines (%d > %d)", lines, max_lines))
		else
			callback(false)
		end
	end, 0)
end

return M
