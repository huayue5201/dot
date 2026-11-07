-- lua/ui/icons.lua
---@brief 状态栏字形的唯一来源（ui.statusline / lsp_ext.statusline / feat.fork_upstream 共用）
-- 换图标只动这一个文件；颜色统一在 lua/ui/colors.lua（M.color），这里只放字形。
-- 注意：LuaJIT 不支持 \uXXXX 转义，字形必须写字面量；码位见行尾注释。
-- 诊断圆点（ERROR/WARN/INFO/HINT）仍由 lua/lsp_ext/icons.lua 管：sign 列与 quicker
-- 弹窗共用，且自带尾随空格（影响 sign 宽度），换它们去那里改。
local M = {}

-- ================================
-- 字形
-- ================================
-- 约定：只存字形本身，前后的空格由各段自己的格式串负责，换图标不会连带改动排版。
-- 码位来自 nerd font（nf-md / nf-cod / nf-dev / nf-fa），必须与终端字体一致。
M.icon = {
	-- 工作区锚点（每个 tab = 一个工作区）
	ws = "󱌖", -- nf-md-folder U+F024B 工作区根目录
	ws_lock = "󰌾", -- nf-md-lock U+F033E 根目录被手动锁定（<leader>lws）

	-- 保存状态：同一个点，靠高亮区分脏/净（SaveDotDirty / SaveDotClean）
	save_dot = "", -- nf-md-circle-small U+F245

	-- 调试
	dap = "", -- nf-cod-debug_alt U+EAD0

	-- Git
	git_branch = "", -- nf-dev-git_branch U+E702
	git_changed = "", -- nf-cod-diff_modified U+E7E8

	-- TODO2 标记数量
	todo = "", -- nf-fa-list_ul U+EF2F

	-- 数据库工作台：winfixbuf 锁定后的后缀「·locked」
	db_lock = "·", -- 中点 U+00B7

	-- LSP（lua/lsp_ext/statusline.lua）
	lsp_idle = "", -- nf-md-circle U+F244 没有 client 时的点
	lsp_suffix = "", -- U+EB65 客户端名后的结尾符
	spinner_frames = {
		"",
		"",
		"",
		"",
		"",
		"",
	},

	-- 上游同步（lua/feat/fork_upstream.lua）
	upstream_behind = "↑", -- ↑ 上游有新提交待合入
	upstream_ahead = "↓", -- ↓ 本地独有提交
	upstream_ok_mark = "✓", -- ✓ 已同步（fork_upstream 的 OK 段）

	-- 段间分隔符（配 color.sep 低对比高亮）
	sep = "│", -- │ U+2502

	-- 滚动条动画：15 帧进度字形，由 get_scrollbar 按当前行位置取帧
	scroll_frames = {
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
	},
}

return M
