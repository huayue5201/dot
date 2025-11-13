local M = {}

function M.check(buf, ctx, callback)
	ctx = ctx or {}
	local max_lines = ctx.max_lines or 10000

	vim.defer_fn(function()
		local lines = vim.api.nvim_buf_line_count(buf)
		if lines > max_lines then
			callback(true, string.format("too many lines (%d > %d)", lines, max_lines))
		else
			callback(false)
		end
	end, 0)
end

return M
