-- tasks/stylua_format.lua

    return {
	name = "styLua",
	type = "format",
	format = {
		cmd = "stylua",
		args = {
			"--search-parent-directories",
			"--indent-type=Spaces",
			"--indent-width=4",
		},
		-- 明确指定文件参数位置 ▼▼▼
		files = { "${file_path}" }, -- 使用上下文变量
		-- 明确指定文件参数位置 ▲▲▲
		incremental = true,
		range_mode = "stylua",
		reload = true,
		notify = true,
	},
	filetypes = { "lua" },
	description = "使用StyLua格式化当前Lua文件",
}
