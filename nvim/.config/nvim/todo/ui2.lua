-- NOTE: 非正式功能,需要做好容错处理.

local ui2 = require("vim._core.ui2")
local msgs = require("vim._core.ui2.messages")

-- ── Config ──────────────────────────────────────────────────────────

local IGNORED_KINDS = {
	bufwrite = true,
	[""] = true,
	empty = true,
}

local SKIP_PATTERNS = {
	"%d+L, %d+B",
	"; after #%d+",
	"; before #%d+",
	"%d fewer lines",
	"%d more lines",
	"%d lines yanked",
}

local KIND_TITLES = {
	emsg = { " Error ", "ErrorMsg" },
	echoerr = { " Error ", "ErrorMsg" },
	lua_error = { " Error ", "ErrorMsg" },
	rpc_error = { " Error ", "ErrorMsg" },
	wmsg = { " Warning ", "WarningMsg" },
	echo = { " Info ", "Normal" },
	echomsg = { " Info ", "Normal" },
	lua_print = { " Print ", "Normal" },
	search_cmd = { " Search ", "Normal" },
	search_count = { " Search ", "Normal" },
	undo = { " Undo ", "Normal" },
	shell_out = { " Shell ", "Normal" },
	shell_err = { " Shell ", "ErrorMsg" },
	shell_cmd = { " Shell ", "Normal" },
	quickfix = { " Quickfix ", "Normal" },
	progress = { " Progress ", "Normal" },
	typed_cmd = { " Command ", "Normal" },
	list_cmd = { " List ", "Normal" },
	verbose = { " Verbose ", "Comment" },
}

-- ── State ────────────────────────────────────────────────────────────

local last_title = nil
local last_hl = "Normal"
local last_msg_text = "" -- 最近一条消息的纯文本（保留，兼容其他引用）

-- 历史消息（最新的在前），每个元素为 { text = "...", title = "..." }
local msg_history = {}
local MAX_HISTORY = 100

-- ── Helpers ─────────────────────────────────────────────────────────

local function content_to_text(content)
	if type(content) ~= "table" then
		return tostring(content or "")
	end
	local parts = {}
	for _, chunk in ipairs(content) do
		if type(chunk) == "string" then
			parts[#parts + 1] = chunk
		elseif type(chunk) == "table" and chunk[2] then
			parts[#parts + 1] = chunk[2]
		end
	end
	return table.concat(parts)
end

local function should_skip(kind, content)
	if IGNORED_KINDS[kind] then
		return true
	end
	local text = content_to_text(content)
	for _, pat in ipairs(SKIP_PATTERNS) do
		if text:find(pat) then
			return true
		end
	end
	return false
end

local function resolve_title(kind, content)
	local entry = KIND_TITLES[kind]
	if entry then
		return entry[1], entry[2]
	end
	local text = vim.trim(content_to_text(content)):gsub("\n.*", "")
	if #text > 40 then
		text = text:sub(1, 37) .. "…"
	end
	return text ~= "" and (" " .. text .. " ") or " Message ", "Normal"
end

-- 记录一条历史消息（去重、限长）
local function push_history(text, title)
	if not text or text == "" then
		return
	end
	-- 与最新一条相同则跳过（应对流式输出/重复 echo）
	if msg_history[1] and msg_history[1].text == text then
		return
	end
	table.insert(msg_history, 1, { text = text, title = title or "" })
	if #msg_history > MAX_HISTORY then
		table.remove(msg_history)
	end
end

-- 复制到系统剪贴板，失败降级到无名寄存器
local function copy_to_clipboard(text)
	if not text or text == "" then
		vim.notify("没有可复制的消息", vim.log.levels.WARN)
		return
	end
	local ok = pcall(vim.fn.setreg, "+", text)
	if ok then
		vim.notify("已复制消息到 + 寄存器")
	else
		vim.fn.setreg('"', text)
		vim.notify("已复制到无名寄存器（+ 不可用）", vim.log.levels.WARN)
	end
end

local function override_msg_win()
	local win = ui2.wins and ui2.wins.msg
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if vim.api.nvim_win_get_config(win).hide then
		return
	end
	pcall(vim.api.nvim_win_set_config, win, {
		relative = "editor",
		anchor = "NE",
		row = 1,
		col = vim.o.columns - 1,
		border = "rounded",
		style = "minimal",
		title = last_title and { { last_title, last_hl } } or nil,
		title_pos = last_title and "center" or nil,
	})
end

local function override_pager_win()
	local win = ui2.wins and ui2.wins.pager
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if vim.api.nvim_win_get_config(win).hide then
		return
	end
	local height = vim.api.nvim_win_get_height(win)
	pcall(vim.api.nvim_win_set_config, win, {
		border = "rounded",
		height = height,
		style = "minimal",
		title = last_title and { { last_title, last_hl } } or nil,
		title_pos = last_title and "center" or nil,
	})
end

local function override_dialog_win()
	local win = ui2.wins and ui2.wins.dialog
	if not (win and vim.api.nvim_win_is_valid(win)) then
		return
	end
	if vim.api.nvim_win_get_config(win).hide then
		return
	end
	local height = vim.api.nvim_win_get_height(win)
	pcall(vim.api.nvim_win_set_config, win, {
		border = "rounded",
		height = height,
		style = "minimal",
		title = last_title and { { last_title, last_hl } } or nil,
		title_pos = last_title and "center" or nil,
	})
end

-- ── ui2 enable ──────────────────────────────────────────────────────

ui2.enable({
	enable = true,
	msg = {
		targets = {
			[""] = "msg",
			empty = "msg",
			bufwrite = "msg",
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
		},
		dialog = { height = 0.5 },
		msg = { height = 0.5 },
		pager = { height = 0.8 },
	},
})

-- ── Wrap set_pos: the single source of truth for msg window placement ─

local orig_set_pos = msgs.set_pos

msgs.set_pos = function(tgt)
	orig_set_pos(tgt)
	if tgt == "msg" or tgt == nil then
		override_msg_win()
		return
	end
	if tgt == "pager" then
		override_pager_win()
		return
	end

	if tgt == "dialog" then
		override_dialog_win()
	end
end

-- ── Wrap msg_show: filtering + title tracking ─────────────────────────

local orig_msg_show = msgs.msg_show

msgs.msg_show = function(kind, content, replace_last, history, append, id, trigger)
	if should_skip(kind, content) then
		return
	end
	last_msg_text = content_to_text(content) -- 记录最近一条消息的纯文本
	local title, hl = resolve_title(kind, content)
	last_title, last_hl = title, hl
	push_history(last_msg_text, title) -- ★ 新增：入历史
	-- orig_msg_show(kind, content, replace_last, history, append, id, trigger)

	local tgt = ui2.cfg.msg.targets[kind]
		or (trigger and trigger ~= "" and ui2.cfg.msg.targets[trigger])
		or (trigger and ui2.cfg.msg.targets[trigger])
		or ui2.cfg.msg.target

	msgs.show_msg(tgt, kind, content, replace_last, append, id)
	msgs.set_pos(tgt)
end

local orig_show_msg = msgs.show_msg
msgs.show_msg = function(tgt, kind, content, replace_last, append, id)
	-- local debug_chunk = { 0, ('[%s:%s] '):format(tgt, kind), 0 }
	-- local debug_content = { debug_chunk }
	-- for _, chunk in ipairs(content) do
	--    debug_content[#debug_content + 1] = chunk
	-- end
	if tgt == "msg" then
		local text = content_to_text(content)
		local width = 0
		for _, line in ipairs(vim.split(text, "\n")) do
			width = math.max(width, vim.api.nvim_strwidth(line))
		end
		local lines = #vim.split(text, "\n")
		if width > math.floor(vim.o.columns * 0.75) or lines > 20 then
			vim.schedule(function()
				-- msgs.show_msg('pager', kind, debug_content, replace_last, append, id)
				msgs.show_msg("pager", kind, content, replace_last, append, id)
				msgs.set_pos("pager")
			end)
			return
		end
	end
	-- orig_show_msg(tgt, kind, debug_content, replace_last, append, id)
	orig_show_msg(tgt, kind, content, replace_last, append, id)
end

-- ── Copy message (with history picker) ──────────────────────────────

vim.keymap.set("n", "<leader>ysm", function()
	if #msg_history == 0 then
		vim.notify("没有可复制的消息", vim.log.levels.WARN)
		return
	end

	vim.ui.select(msg_history, {
		prompt = "选择要复制的消息：",
		format_item = function(item)
			local one_line = item.text:gsub("\n", " ⏎ "):gsub("%s+", " ")
			local prefix = item.title ~= "" and ("[" .. vim.trim(item.title) .. "] ") or ""
			return (prefix .. one_line):sub(1, 120)
		end,
	}, function(choice)
		if not choice then
			return
		end
		copy_to_clipboard(choice.text)
	end)
end, { desc = "从历史消息中选择复制" })

-- 可选：直接复制最近一条
vim.keymap.set("n", "<leader>ym", function()
	copy_to_clipboard(last_msg_text)
end, { desc = "复制最近的消息" })

-- ── LSP progress ─────────────────────────────────────────────────────

-- local id = { LspProgressMessages = vim.api.nvim_create_augroup("LspProgressMessages", { clear = true }) }

-- vim.api.nvim_create_autocmd("LspProgress", {
-- 	group = id.LspProgressMessages,
-- 	callback = function(ev)
-- 		local value = ev.data.params.value
-- 		local client = vim.lsp.get_client_by_id(ev.data.client_id)
-- 		if not client then
-- 			return
-- 		end
-- 		local is_end = value.kind == "end"
-- 		local msg = value.message and (client.name .. ": " .. value.message)
-- 			or (client.name .. (is_end and ": done" or ""))
-- 		vim.api.nvim_echo({ { msg } }, false, {
-- 			id = "lsp." .. ev.data.client_id,
-- 			kind = "progress",
-- 			source = "vim.lsp",
-- 			title = value.title,
-- 			status = is_end and "success" or "running",
-- 			percent = value.percentage,
-- 		})
-- 	end,
-- })
