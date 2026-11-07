local M = {}

-- ============================
-- 颜色调色板
-- ============================
M.palette = {
	bg = "#1e1e2e", -- 背景色
	fg = "#cdd6f4", -- 前景色（文字颜色）
	red = "#f38ba8", -- 红色，用于错误
	green = "#a6e3a1", -- 绿色，用于成功、通过
	green3 = "#00CD00",
	blue = "#89b4fa", -- 蓝色，用于信息
	yellow = "#f9e2af", -- 黄色，用于警告
	magenta = "#f5c2e7", -- 洋红，用于强调
	cyan = "#94e2d5", -- 青色，用于提示
	gray = "#6c7086", -- 灰色
	darkgray = "#45475a", -- 深灰色
	error = "#f38ba8", -- 语义：错误
	warning = "#f9e2af", -- 语义：警告
	info = "#89dceb", -- 语义：信息
	hint = "#74c7ec", -- 语义：提示
}

-- ============================
-- 状态栏 / UI 强调色
-- ============================
-- 纯色字面量放这里，随主题走的一律引用上面的 palette。
M.color = {
	-- 保存状态
	save_dirty = "#E4080A", -- 未保存数量红字 + 未保存红点
	save_clean = "#50fa7b", -- 已保存绿点

	-- 各段图标/强调色
	pink = "#ffde7d", -- 滚动条
	icon = "#ffc125", -- TODO2 计数
	dap = "#FF0000",
	git = "#FF8C00",
	lsp = "#fffff0",

	-- git 变更计数
	git_added = M.palette.green,
	git_removed = M.palette.red,
	git_changed = M.palette.yellow,

	-- 段间分隔符
	sep = M.palette.darkgray,

	-- 数据库工作台（sqmeow）窗口角色
	db_icon = M.palette.cyan,
	db_locked = M.palette.gray,

	-- 上游同步
	upstream_ok = M.palette.green,
	upstream_behind = M.palette.yellow,
	upstream_behind_many = M.palette.red,
	upstream_ahead = M.palette.gray,
	upstream_error = M.palette.red,

	-- 工作区锚点槽位 StlWs1..6：同一个根目录永远同一个颜色
	ws = {
		M.palette.blue,
		M.palette.magenta,
		M.palette.cyan,
		M.palette.green,
		M.palette.yellow,
		M.palette.red,
	},
}

return M
