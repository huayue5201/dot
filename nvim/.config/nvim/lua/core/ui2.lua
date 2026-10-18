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
			row = 1,
			col = vim.o.columns,
			width = cfg.width,
			height = cfg.height,
			hide = cfg.hide,
			border = cfg.border,
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
end

return M
