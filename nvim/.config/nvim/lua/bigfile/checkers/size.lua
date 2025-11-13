local uv = vim.loop
local M = {}

function M.check(buf, ctx, callback)
	ctx = ctx or {}
	local max_bytes = ctx.max_bytes or 2 * 1024 * 1024 -- 2MB 默认阈值

	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		if callback then
			callback(false, "no file path")
		end
		return
	end

	uv.fs_stat(name, function(err, stat)
		if err or not stat then
			if callback then
				callback(false, "cannot stat file")
			end
			return
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
