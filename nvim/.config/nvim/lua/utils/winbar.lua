-- lua/utils/winbar.lua
Winbar = {}

-- 配置
Winbar.config = {
	separator = " %#WinbarSeparator# ",
	folder_icon = "   ",
	special_dirs = {
		CODE = vim.g.projects_dir,
		DOTFILES = vim.fn.stdpath("config"),
		HOME = vim.env.HOME,
		PERSONAL = vim.g.personal_projects_dir,
	},
}

-- 处理特殊目录前缀
function Winbar.process_special_dirs(path)
	local prefix, prefix_path = "", ""
	for dir_name, dir_path in pairs(Winbar.config.special_dirs) do
		if vim.startswith(path, vim.fs.normalize(dir_path)) and #dir_path > #prefix_path then
			prefix, prefix_path = dir_name, dir_path
		end
	end
	if prefix ~= "" then
		path = path:gsub("^" .. prefix_path, "")
		prefix = string.format("%%#WinBarSpecial#%s %s%s", Winbar.config.folder_icon, prefix, Winbar.config.separator)
	end
	return prefix, path
end

-- 格式化路径
function Winbar.format_path(path)
	local segments = vim.split(path, "/")
	local formatted_segments = vim.tbl_map(function(segment)
		return string.format("%%#Winbar#%s", segment)
	end, segments)
	return table.concat(formatted_segments, Winbar.config.separator)
end

-- 渲染 Winbar
function Winbar.render()
	local full_path = vim.fs.normalize(vim.fn.expand("%:p"))
	local cwd = vim.fn.getcwd() -- 获取当前工作目录（通常是 Git 项目根目录）
	local path
	-- 仅在当前文件属于工作目录时使用相对路径
	if vim.startswith(full_path, cwd) then
		path = vim.fn.fnamemodify(full_path, ":p:.") -- 获取相对路径
	else
		path = vim.fn.pathshorten(full_path) -- 否则使用缩短的绝对路径
	end
	-- 处理特殊目录前缀
	local prefix
	prefix, path = Winbar.process_special_dirs(path)
	-- 通过拼接方式构建最终的 winbar 内容
	local winbar_content = {}
	-- 文件夹图标
	table.insert(winbar_content, Winbar.config.folder_icon)
	-- 处理并插入路径
	table.insert(winbar_content, prefix .. Winbar.format_path(path))
	-- 拼接最终字符串
	return table.concat(winbar_content, "")
end

vim.api.nvim_create_autocmd("BufWinEnter", {
	group = vim.api.nvim_create_augroup("Winbar", { clear = true }),
	desc = "Attach winbar",
	callback = function(args)
		if
			not vim.api.nvim_win_get_config(0).zindex
			and vim.bo[args.buf].buftype == ""
			and vim.api.nvim_buf_get_name(args.buf) ~= ""
			and not vim.wo[0].diff
		then
			vim.wo.winbar = "%{%v:lua.Winbar.render()%}"
		end
	end,
})
