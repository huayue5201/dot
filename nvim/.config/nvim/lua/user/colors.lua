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

return M
