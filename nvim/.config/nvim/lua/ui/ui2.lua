-- Neovim ui2（内置消息 / cmdline UI）
-- https://neovim.io/doc/user/lua.html#ui2

local M = {}

-- 消息目标路由。键名会按 Lua pattern 匹配消息 ID，default 处理未命中的消息。
local targets = {
	default = "cmd",
	empty = "cmd",
	bufwrite = "cmd",
	echo = "msg",
	echomsg = "msg",
	shell_ret = "msg",
	undo = "msg",
	wmsg = "msg",
	completion = "msg",
	confirm = "dialog",
	confirm_sub = "dialog",
	echoerr = "msg",
	emsg = "msg",
	list_cmd = "pager",
	lua_error = "msg",
	lua_print = "msg",
	progress = "msg",
	quickfix = "msg",
	rpc_error = "msg",
	search_cmd = "msg",
	search_count = "msg",
	shell_cmd = "msg",
	shell_err = "msg",
	shell_out = "msg",
	typed_cmd = "msg",
	verbose = "pager",
	wildlist = "msg",
}

local skip_messages = {
	-- Write
	"%d+L, %d+B",

	-- Search
	"; after #%d+",
	"; before #%d+",
	"^[/?].*",
	"E486: Pattern not found:",

	-- Edit
	"%d+ less lines",
	"%d+ fewer lines",
	"%d+ more lines",
	"%d+ change;",
	"%d+ line less;",
	"%d+ more lines?;",
	"%d+ fewer lines;?",
	"1 more line",
	"1 line less",
	"^Hunk %d+ of %d+$",
	"Already at newest change",
	"Already at oldest change",

	"%d lines yanked",
	"no lines in buffer",

	-- Undo/Redo
	"%d+ changes?;",
	" changes; brefore #",
	" changes; after #",
	" 1 change; before #",
	" 1 change; after #",

	-- Move lines
	" lines moved",
	" lines indented",
}

local function normalized_content(src)
	if type(src) ~= "table" then
		return tostring(src or "")
	end

	local list = {}
	for _, chunk in ipairs(src) do
		if type(chunk) == "table" and chunk[2] then
			list[#list + 1] = chunk[2]
		end
	end

	return table.concat(list)
end

local function should_skip(kind, content)
	if kind == "bufwrite" then
		return true
	end

	local msg = normalized_content(content)
	for _, pat in ipairs(skip_messages) do
		if msg:find(pat) then
			return true
		end
	end

	return false
end

function M.setup()
	require("vim._core.ui2").enable({
		enable = true,
		msg = {
			targets = targets,
			dialog = { height = 0.5 },
			msg = { height = 0.3 },
			pager = { height = 0.5 },
		},
	})

	-- ui2 默认把消息窗口放在底部（relative = 'laststatus'，anchor = 'SE'）。
	-- 包一层 set_pos，在原位置计算后再把它挪到右上角。
	local ui = require("vim._core.ui2")
	local messages = require("vim._core.ui2.messages")
	local original_set_pos = messages.set_pos

	messages.set_pos = function(tgt, focus)
		original_set_pos(tgt, focus)

		local win = ui.wins.msg
		if not vim.api.nvim_win_is_valid(win) or (tgt ~= nil and tgt ~= "msg") then
			return
		end

		local cfg = vim.api.nvim_win_get_config(win)
		vim.api.nvim_win_set_config(win, {
			relative = "editor",
			anchor = "NE",
			row = 2,
			col = vim.o.columns,
			width = cfg.width,
			height = cfg.height,
			hide = cfg.hide,
			border = "none",
			mouse = cfg.mouse,
			zindex = cfg.zindex,
		})
	end

	-- ui2 新版把 timeout / maxheight 移到了 'messagesopt'。
	vim.opt.messagesopt:append("maxheight:50,timeout:5000")

	-- 过滤掉不需要显示的写入、搜索、撤销等高频消息。
	local original_msg_show = messages.msg_show

	messages.msg_show = function(kind, content, replace_last, history, append, id, trigger)
		if should_skip(kind, content) then
			return
		end

		original_msg_show(kind, content, replace_last, history, append, id, trigger)
	end

	-- 浮窗背景全透明（只留文字，不叠一层底色）。
	-- ui2 的窗口没有映射 Normal，浮窗背景默认取 NormalFloat，消息文本行用 MsgArea。
	-- 两者都映射到 Ui2TransparentBg：继承 Normal 的前景色，但不设背景色（=NONE），
	-- 所以能透出后面的内容，不依赖配色自身的 transparent 开关。
	-- 注意：不能用 winblend=100，那是连文字一起混掉。
	-- 只作用于 ui2 自己的窗口，不动全局 NormalFloat，避免影响 telescope 等其他浮窗。
	local transparent_targets = { "msg", "dialog", "pager" } -- 需要 cmd 也透明时把 "cmd" 加进来
	local transparent_hl = "Ui2TransparentBg"

	local function refresh_transparent_hl()
		local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		vim.api.nvim_set_hl(0, transparent_hl, {
			fg = normal.fg,
			ctermfg = normal.ctermfg,
			-- 不写 bg：背景保持 NONE
		})
	end

	refresh_transparent_hl()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("ui2_transparent_float", { clear = true }),
		callback = refresh_transparent_hl,
		desc = "ui2 浮窗透明背景跟随配色",
	})

	local function make_transparent(win)
		if not vim.api.nvim_win_is_valid(win) then
			return
		end

		-- 幂等：已经映射过就让开（ui2 在 check_targets 里会重设 winhighlight，这里顺手修复）。
		local current = vim.wo[win].winhighlight
		local normal_map, msgarea_map = "Normal:" .. transparent_hl, "MsgArea:" .. transparent_hl
		if current:find(normal_map, 1, true) and current:find(msgarea_map, 1, true) then
			return
		end

		-- winhighlight 中同名组以靠后的为准，所以先剔除旧的 Normal/MsgArea 映射再追加。
		local parts = {}
		for _, part in ipairs(vim.split(current, ",", { trimempty = true })) do
			if not part:match("^Normal:") and not part:match("^MsgArea:") then
				parts[#parts + 1] = part
			end
		end
		parts[#parts + 1] = normal_map
		parts[#parts + 1] = msgarea_map

		vim.wo[win].winhighlight = table.concat(parts, ",")
	end

	-- ui2 在 check_targets() 里创建/重建窗口，每次重绘都会经过它，在这里兜住新窗口。
	local original_check_targets = ui.check_targets

	ui.check_targets = function()
		original_check_targets()
		for _, tgt in ipairs(transparent_targets) do
			make_transparent(ui.wins[tgt])
		end
	end
end

return M
