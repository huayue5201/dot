local uv = vim.loop
local M = {}

-- 文件大小检测器
function M.check(buf, ctx, callback)
	-- 确保配置存在
	local max_bytes = ctx.max_bytes or (10 * 1024 * 1024)

	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return callback(false, "no file path")
	end

	uv.fs_stat(name, function(err, stat)
		if err or not stat then
			return callback(false, "cannot stat file")
		end

		if stat.size > max_bytes then
			callback(
				true,
				string.format("file too large (%.2fMB > %.2fMB)", stat.size / 1024 / 1024, max_bytes / 1024 / 1024)
			)
		else
			callback(false)
		end
	end)
end

return M
