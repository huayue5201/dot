-- 终端 UI 配色：全部从当前 colorscheme 的既有高亮组推导，换主题自动跟着变。
--
-- 目标：终端面板 / winbar / 侧栏各自有一层色差，像 IDE 那样「编辑器、面板、面板头、
-- 侧栏导轨」四层分明，而不是整屏同一个背景色。
--
-- 层级（自上而下由亮到暗）：
--   编辑器 Normal bg
--   终端面板 Pmenu bg（更暗 = 下沉的抽屉）
--   面板 winbar TabLineSel bg + 顶部强调线（accent 下划线，标出当前终端）
--   侧栏：Normal 与 fg 混 6% 提亮（比面板亮一档，读起来像贴在面板右侧的导轨）
--
-- 焦点变化时用 TwTerm*NC 变暗，跟 colorscheme 的 dim_inactive 一致。

local api = vim.api

local M = {}

----------------------------------------------------------------------
-- 颜色工具
----------------------------------------------------------------------

---@param c integer|nil
---@return integer|nil
local function rgb(c)
	if type(c) ~= "number" then
		return nil
	end
	return math.floor(c / 0x10000) % 0x100, math.floor(c / 0x100) % 0x100, c % 0x100
end

---@param r integer
---@param g integer
---@param b integer
---@return integer
local function pack(r, g, b)
	return r * 0x10000 + g * 0x100 + b
end

--- 在两色之间插值：t=0 取 a，t=1 取 b
---@param a integer|nil
---@param b integer|nil
---@param t number
---@return integer|nil
function M.blend(a, b, t)
	local ar, ag, ab = rgb(a)
	local br, bg, bb = rgb(b)
	if not ar then
		return b
	end
	if not br then
		return a
	end
	local function mix(x, y)
		return math.floor(x + (y - x) * t + 0.5)
	end
	return pack(mix(ar, br), mix(ag, bg), mix(ab, bb))
end

--- 取某个高亮组的属性（link 展开；组不存在时返回 nil）
---@param name string
---@param attr "fg"|"bg"
---@return integer|nil
local function pick(name, attr)
	local ok, hl = pcall(api.nvim_get_hl, 0, { name = name, link = false })
	if not ok or type(hl) ~= "table" then
		return nil
	end
	return hl[attr]
end

--- 当前主题推导出来的一整套色（也给 define_hl 之外的地方用，如状态栏）
---@return table
function M.palette()
	local bg = pick("Normal", "bg")
	local fg = pick("Normal", "fg")
	local accent = pick("Function", "fg") or pick("Title", "fg") or pick("Special", "fg") or fg
	-- 终端 UI 的强调色用绿（DiagnosticOk / Added 都是主题里的绿）
	local green = pick("DiagnosticOk", "fg") or pick("Added", "fg") or pick("DiffAdd", "fg") or accent
	local dim_fg = pick("Comment", "fg") or pick("NonText", "fg") or fg

	local panel_bg = pick("Pmenu", "bg") or M.blend(bg, 0x000000, 0.35) or bg
	-- 有些主题的 Pmenu/Normal 是同一个背景，那样面板就跟编辑器糊成一片了：
	-- 兜底往 fg 方向挪一点点，保证「看得出来是另一层」
	if panel_bg == bg then
		panel_bg = M.blend(bg, fg, 0.06) or bg
	end
	local bar_bg = pick("TabLineSel", "bg") or M.blend(bg, accent, 0.12) or panel_bg
	if bar_bg == panel_bg then
		bar_bg = M.blend(panel_bg, fg, 0.08) or panel_bg
	end
	local bar_fg = pick("TabLine", "fg") or dim_fg
	-- 选中的 chip 在主题 Visual 底色上再提亮一点：既是"按钮被抬起"，也和普通 chip 拉开
	local active_bg = M.blend(pick("Visual", "bg") or bar_bg, fg, 0.10) or bar_bg
	-- winbar 的四个层次：条底（比面板更暗，作为"轨道"）、普通 chip、选中 chip、+ 按钮
	local bar_strip = M.blend(panel_bg, 0x000000, 0.40) or panel_bg
	local chip_bg = M.blend(bar_strip, fg, 0.13) or bar_bg
	local chip_fg = M.blend(bar_strip, fg, 0.55) or fg
	local chip_close = M.blend(bar_strip, fg, 0.40) or fg
	local btn_bg = M.blend(bar_strip, green, 0.22) or active_bg
	local sb_bg = M.blend(bg, fg, 0.06) or panel_bg

	return {
		fg = fg,
		accent = accent,
		green = green,
		dim = dim_fg,
		panel_bg = panel_bg,
		panel_bg_nc = M.blend(panel_bg, 0x000000, 0.35),
		bar_bg = bar_bg,
		bar_fg = bar_fg,
		active_bg = active_bg,
		sb_bg = sb_bg,
		sb_bg_nc = M.blend(sb_bg, 0x000000, 0.30),
		sb_header_bg = M.blend(sb_bg, 0x000000, 0.22),
		sep_fg = M.blend(bar_bg, fg, 0.25),
		bar_strip = bar_strip,
		chip_bg = chip_bg,
		chip_fg = chip_fg,
		chip_close = chip_close,
		btn_bg = btn_bg,
	}
end

----------------------------------------------------------------------
-- 高亮组
----------------------------------------------------------------------

--- 定义全部 TwTerm* 高亮（ColorScheme 时重跑）
function M.apply()
	local c = M.palette()

	-- 终端面板本体：Normal 在面板窗口里被映射成它（winhighlight）
	api.nvim_set_hl(0, "TwTermPanel", { fg = c.fg, bg = c.panel_bg })
	api.nvim_set_hl(0, "TwTermPanelNC", { fg = c.dim, bg = c.panel_bg_nc })

	-- winbar：模仿 bufferline 的 chip —— 条底是"轨道"，每个终端是一块浮起的按钮
	api.nvim_set_hl(0, "TwTermBar", { fg = c.bar_fg, bg = c.bar_strip })
	api.nvim_set_hl(0, "TwTermTab", { fg = c.chip_fg, bg = c.chip_bg })
	api.nvim_set_hl(0, "TwTermTabIcon", { fg = M.blend(c.chip_bg, c.green, 0.72), bg = c.chip_bg })
	api.nvim_set_hl(0, "TwTermTabClose", { fg = c.chip_close, bg = c.chip_bg })
	-- 选中的 chip：亮一档 + 底部 accent 下划线（与 bufferline 的 underline indicator 同款）
	api.nvim_set_hl(0, "TwTermTabActive", {
		fg = c.fg,
		bg = c.active_bg,
		bold = true,
		underline = true,
		sp = c.green,
	})
	api.nvim_set_hl(0, "TwTermTabIconActive", {
		fg = c.green,
		bg = c.active_bg,
		underline = true,
		sp = c.green,
	})
	api.nvim_set_hl(0, "TwTermTabCloseActive", {
		fg = M.blend(c.active_bg, c.fg, 0.5),
		bg = c.active_bg,
	})
	-- `+` 按钮：自带底色，看起来是能按的
	api.nvim_set_hl(0, "TwTermNew", { fg = c.green, bg = c.btn_bg, bold = true })

	-- 分隔线（面板/侧栏与编辑器之间那一条竖线）
	api.nvim_set_hl(0, "TwTermSep", { fg = c.sep_fg, bg = c.panel_bg })
	api.nvim_set_hl(0, "TwTermSepNC", { fg = c.panel_bg_nc and M.blend(c.sep_fg, c.panel_bg, 0.6) or c.sep_fg })

	-- 侧栏导轨
	api.nvim_set_hl(0, "TwTermSbNormal", { fg = c.fg, bg = c.sb_bg })
	api.nvim_set_hl(0, "TwTermSbNormalNC", { fg = c.dim, bg = c.sb_bg_nc })
	api.nvim_set_hl(0, "TwTermSbCursor", { bg = M.blend(c.sb_bg, c.bar_bg, 0.85) })
	api.nvim_set_hl(0, "TwTermSbHeader", { fg = c.green, bg = c.sb_header_bg, bold = true })
	api.nvim_set_hl(0, "TwTermSbHeaderNC", { fg = M.blend(c.green, c.sb_bg, 0.45), bg = c.sb_bg_nc, bold = true })
	api.nvim_set_hl(0, "TwTermSbItem", { fg = c.fg, bg = c.sb_bg })
	api.nvim_set_hl(0, "TwTermSbActive", { fg = c.fg, bg = c.active_bg, bold = true })
	api.nvim_set_hl(0, "TwTermSbDead", { fg = c.dim, bg = c.sb_bg, italic = true })
	api.nvim_set_hl(0, "TwTermSbBadge", { fg = c.green, bg = c.sb_header_bg, bold = true })
	-- 行尾的关闭按钮：平时是暗色，当前终端那行亮一点，看得出「能点」
	api.nvim_set_hl(0, "TwTermSbClose", { fg = c.chip_close, bg = c.sb_bg })
	api.nvim_set_hl(0, "TwTermSbCloseActive", { fg = M.blend(c.active_bg, c.fg, 0.5), bg = c.active_bg })
	-- 侧栏每行的 shell 标识：左边图标、右边名字，都是虚拟文本。
	-- 只给 fg（虚拟文本用 hl_mode="combine"，底色沿用所在行的 TwTermSb* 组）
	api.nvim_set_hl(0, "TwTermSbShellIcon", { fg = M.blend(c.sb_bg, c.green, 0.75) })
	api.nvim_set_hl(0, "TwTermSbShellTag", { fg = c.dim })
end

----------------------------------------------------------------------
-- 窗口映射（面板/侧栏的 Normal、CursorLine、分隔线）
----------------------------------------------------------------------

---@param focused boolean
---@return string 面板窗口的 winhighlight
function M.panel_winhl(focused)
	local normal = focused and "TwTermPanel" or "TwTermPanelNC"
	local sep = focused and "TwTermSep" or "TwTermSepNC"
	return table.concat({
		"Normal:" .. normal,
		"NormalNC:" .. normal,
		"EndOfBuffer:" .. normal,
		"WinSeparator:" .. sep,
		"VertSplit:" .. sep,
	}, ",")
end

---@param focused boolean
---@return string 侧栏窗口的 winhighlight
function M.sidebar_winhl(focused)
	local normal = focused and "TwTermSbNormal" or "TwTermSbNormalNC"
	local sep = focused and "TwTermSep" or "TwTermSepNC"
	return table.concat({
		"Normal:" .. normal,
		"NormalNC:" .. normal,
		"EndOfBuffer:" .. normal,
		"CursorLine:TwTermSbCursor",
		"WinSeparator:" .. sep,
		"VertSplit:" .. sep,
	}, ",")
end

--- 按当前焦点刷新所有终端相关窗口的 winhighlight
function M.update_windows()
	local cur = api.nvim_get_current_win()
	for _, win in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_get_config(win).relative == "" then
			local focused = win == cur
			if vim.w[win].tw_term_panel then
				api.nvim_set_option_value("winhighlight", M.panel_winhl(focused), { win = win })
			elseif vim.w[win].tw_term_sidebar then
				api.nvim_set_option_value("winhighlight", M.sidebar_winhl(focused), { win = win })
			end
		end
	end
end

return M
