-- BrickDAG/ui/tri_window_manager.lua

local factory = require("BrickDAG.ui.window_factory")

local M = {}

--- 存储三个浮窗窗口与 buffer 的句柄
M.windows = {}

--- 高亮组定义（只需执行一次）
local function define_highlight_groups()
	local defs = {
		left = { bg = "#3b4252", fg = "#b48ead" },
		center = { bg = "#434c5e", fg = "#a3be8c" },
		right = { bg = "#4c566a", fg = "#ebcb8b" },
	}

	for name, hl in pairs(defs) do
		vim.api.nvim_set_hl(0, name .. "WinNormal", { bg = hl.bg })
		vim.api.nvim_set_hl(0, name .. "WinBorder", { fg = hl.fg, bg = hl.bg })
	end
end

--- 计算浮窗布局（3:5:2 横向分布）
local function calculate_layout()
	local total_width = vim.o.columns
	local total_height = vim.o.lines

	local usable_width = math.floor(total_width * 0.7)
	local col_offset = math.floor((total_width - usable_width) / 2)

	local gap = 2 -- 间隙列，防止边框重叠
	local total_gap = gap * 2

	local height = math.floor(total_height * 0.5)
	local row = math.floor((total_height - height) / 2)

	local content_width = usable_width - total_gap

	local total_ratio = 3 + 3 + 3
	local left_w = math.floor(content_width * 3 / total_ratio)
	local center_w = math.floor(content_width * 3 / total_ratio)
	local right_w = content_width - left_w - center_w

	local left_col = col_offset
	local center_col = col_offset + left_w + gap
	local right_col = col_offset + left_w + gap + center_w + gap

	return {
		left = {
			row = row,
			col = left_col,
			width = left_w,
			height = height,
		},
		center = {
			row = row,
			col = center_col,
			width = center_w,
			height = height,
		},
		right = {
			row = row,
			col = right_col,
			width = right_w,
			height = height,
		},
	}
end

--- 创建三个浮窗并显示内容
function M.open()
	define_highlight_groups()
	M.close_all() -- 避免重复打开

	local layout = calculate_layout()

	for name, opts in pairs(layout) do
		local win = factory.create({
			row = opts.row,
			col = opts.col,
			width = opts.width,
			height = opts.height,
			border = "rounded",
			zindex = 60,
			winhighlight = string.format("Normal:%sWinNormal,FloatBorder:%sWinBorder", name, name),
			enter_win = false, -- 这里禁止自动聚焦
		})

		M.windows[name] = win

		-- 清除缓冲区初始内容
		vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, {})
	end

	-- 手动聚焦中间窗口
	M.focus_center()
end

--- 关闭所有浮窗
function M.close_all()
	for _, win in pairs(M.windows) do
		if vim.api.nvim_win_is_valid(win.win) then
			vim.api.nvim_win_close(win.win, true)
		end
	end
	M.windows = {}
end

function M.ensure_open()
	if not M.windows.left or not vim.api.nvim_win_is_valid(M.windows.left.win) then
		M.open()
	end
end

function M.focus_center()
	if M.windows.center and vim.api.nvim_win_is_valid(M.windows.center.win) then
		vim.api.nvim_set_current_win(M.windows.center.win)
	end
end

return M
