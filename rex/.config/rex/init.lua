-- smart-splits style pane navigation for Rex.
--
--   ctrl+hjkl       focus the pane in that direction
--   ctrl+alt+hjkl   resize the pane in that direction
--
-- When the focused block runs a Vim (or a TUI named in
-- SMART_SPLITS_REX_PASSTHROUGH_RE), the chord is handed back to that program,
-- so it can move its own splits and only call back into Rex at its edge.

local TERMINAL = "com.superlogical.terminal"

-- Same names vim-tmux-navigator treats as Vim: vi, vim, nvim, view, gvim,
-- and their *diff variants. Lua patterns have no alternation, so this is
-- spelled out.
local function is_vim(name)
	local stem = name:gsub("diff$", "")
	return stem:match("^g?view$") ~= nil or stem:match("^g?l?n?vim?x?$") ~= nil
end

-- Optional extra passthrough for other TUIs that own the chord themselves:
--   SMART_SPLITS_REX_PASSTHROUGH=lazygit,k9s
local NAMES = {}
for name in (os.getenv("SMART_SPLITS_REX_PASSTHROUGH")
	or os.getenv("SMART_SPLITS_HERDR_PASSTHROUGH_RE")
	or ""):gmatch("[^,%s]+") do
	NAMES[name:lower()] = true
end

local function basename(path)
	return (tostring(path or ""):match("([^/]+)$"))
end

local function focused_block(ctx)
	local view = rex.session.view({ session_id = ctx.session_id })
	if type(view) ~= "table" then
		return nil
	end
	local windows = view.windows or {}
	for _, window in ipairs(windows) do
		if window.window_id == view.active_window_id then
			return window.focused_block_id
		end
	end
	for _, window in ipairs(windows) do
		if window.focused_block_id then
			return window.focused_block_id
		end
	end
	return nil
end

-- True when the program in front of the block owns the chord itself.
local function active_window(ctx)
	local view = rex.session.view({ session_id = ctx.session_id })
	if type(view) ~= "table" then
		return nil
	end
	for _, window in ipairs(view.windows or {}) do
		if window.window_id == view.active_window_id then
			return window
		end
	end
	return nil
end

-- The zoomed block in the active window, if any. Zoom is per window, so
-- changing tabs/windows keeps it; moving focus inside the window clears it.
local function zoomed_block(ctx)
	local window = active_window(ctx)
	return window and window.zoomed_block_id or nil
end

local function keep_zoom(ctx, zoomed, before)
	local after = focused_block(ctx)
	if zoomed and after and after ~= before then
		rex.session.zoom_block({
			session_id = ctx.session_id,
			block_id = after,
			zoom = true,
		})
	end
end

local function forwards(block_id)
	if not block_id then
		return false
	end
	local ok, info = pcall(rex.block.call, TERMINAL, "process", { block_id = block_id })
	if not ok or type(info) ~= "table" then
		return false
	end
	local foreground = info.foreground or {}
	for _, candidate in ipairs({
		foreground.name,
		foreground.argv0,
		basename(foreground.invoked_path),
		basename(foreground.path),
	}) do
		local name = tostring(candidate or ""):lower()
		if name ~= "" and (is_vim(name) or NAMES[name]) then
			return true
		end
	end
	return false
end

local function forward(key)
	pcall(rex.client.queue, "pane.send_key", { key = key })
end

local KEYS = { left = "h", down = "j", up = "k", right = "l" }

-- Defined with the jump list below; the focus actions above record into it.
local observe

rex.action({
	name = "smart_splits_navigate",
	title = "Navigate Pane",
	description = "Focus the pane in that direction, or hand the key to a focused editor.",
	category = "smart-splits",
	keywords = "pane focus navigate smart splits",
	args = { direction = "string" },
	run = function(ctx, args)
		local direction = args.direction
		local key = "ctrl+" .. KEYS[direction]
		local block = ctx.block_id or focused_block(ctx)
		if forwards(block) then
			forward(key)
			return
		end
		observe(ctx)
		local zoomed = zoomed_block(ctx)
		rex.session.focus_direction({
			session_id = ctx.session_id,
			direction = direction,
			wrap = false,
		})
		keep_zoom(ctx, zoomed, block)
		if focused_block(ctx) == block then
			-- No neighbour: give the key back so the shell keeps it.
			forward(key)
			return
		end
		observe(ctx)
	end,
})

rex.action({
	name = "smart_splits_resize",
	title = "Resize Pane",
	description = "Resize the pane in that direction, or hand the key to a focused editor.",
	category = "smart-splits",
	keywords = "pane resize smart splits",
	args = { direction = "string" },
	run = function(ctx, args)
		local direction = args.direction
		local key = "ctrl+alt+" .. KEYS[direction]
		if forwards(ctx.block_id or focused_block(ctx)) then
			forward(key)
			return
		end
		pcall(rex.client.queue, "pane.resize", { direction = direction })
	end,
})

-- Cycle through panes while keeping a zoomed pane maximized.
rex.action({
	name = "smart_splits_cycle",
	title = "Cycle Pane Keeping Zoom",
	description = "Focus the next or previous pane; if the window is zoomed, zoom the new pane too.",
	category = "smart-splits",
	keywords = "pane focus next previous cycle zoom maximize",
	args = { step = "string" },
	run = function(ctx, args)
		local before = ctx.block_id or focused_block(ctx)
		local zoomed = zoomed_block(ctx)
		observe(ctx)
		if args.step == "previous" then
			rex.session.focus_previous_pane({ session_id = ctx.session_id })
		else
			rex.session.focus_next_pane({ session_id = ctx.session_id })
		end
		keep_zoom(ctx, zoomed, before)
		observe(ctx)
	end,
})

for direction, base in pairs(KEYS) do
	rex.bind("ctrl+" .. base, "smart_splits_navigate", { direction = direction })
	rex.bind("ctrl+alt+" .. base, "smart_splits_resize", { direction = direction })
end

rex.bind("cmd+]", "smart_splits_cycle", { step = "next" })
rex.bind("cmd+[", "smart_splits_cycle", { step = "previous" })

-- Jump list: ctrl-o / ctrl-i semantics over panes.
--
--   cmd+o   go back to the pane focused before this one
--   cmd+i   go forward again
--
-- A pane focused another way (a mouse click, an agent, a palette pick) joins
-- the list the next time one of these actions runs, because the jump observes
-- the layout before it moves.
local JUMP_LIMIT = 50

-- window_id -> { entries = { block_id }, index = position in entries, last = last observed focus }
local lists = {}

local function list_of(window_id)
	local list = lists[window_id]
	if not list then
		list = { entries = {}, index = 0, last = nil }
		lists[window_id] = list
	end
	return list
end

local function active_window_of(view)
	for _, window in ipairs(view.windows or {}) do
		if window.window_id == view.active_window_id then
			return window
		end
	end
	return (view.windows or {})[1]
end

-- Record the focused pane of the active window, dropping panes that closed.
-- Returns the list, or nil when the session can't be read.
observe = function(ctx)
	local view = rex.session.view({ session_id = ctx.session_id })
	if type(view) ~= "table" then
		return nil
	end
	local window = active_window_of(view)
	if not window then
		return nil
	end

	local live = {}
	for _, layer in ipairs(window.layers or {}) do
		for _, block in ipairs(layer.blocks or {}) do
			if block.block_id then
				live[block.block_id] = true
			end
		end
	end

	local list = list_of(window.window_id)
	local kept, removed_before = {}, 0
	for position, block_id in ipairs(list.entries) do
		if live[block_id] then
			kept[#kept + 1] = block_id
		elseif position <= list.index then
			removed_before = removed_before + 1
		end
	end
	list.entries = kept
	list.index = math.max(0, list.index - removed_before)

	local current = window.focused_block_id
	if current and current ~= list.last then
		for position = #list.entries, list.index + 1, -1 do
			list.entries[position] = nil
		end
		list.entries[#list.entries + 1] = current
		if #list.entries > JUMP_LIMIT then
			table.remove(list.entries, 1)
		end
		list.index = #list.entries
		list.last = current
	end
	return list
end

local function jump_move(ctx, step)
	local list = observe(ctx)
	if not list then
		return
	end
	local target = list.index + step
	while list.entries[target] and list.entries[target] == list.last do
		target = target + step
	end
	local block_id = list.entries[target]
	if not block_id then
		return
	end
	local zoomed = zoomed_block(ctx)
	local before = list.last
	list.index, list.last = target, block_id
	rex.session.focus_block({ session_id = ctx.session_id, block_id = block_id })
	keep_zoom(ctx, zoomed, before)
end

rex.action({
	name = "jump_back",
	title = "Go Back to Previous Pane",
	description = "Focus the pane that had focus before this one, like ctrl-o.",
	category = "smart-splits",
	keywords = "pane focus back previous jump history",
	run = function(ctx)
		jump_move(ctx, -1)
	end,
})

rex.action({
	name = "jump_forward",
	title = "Go Forward to Next Pane",
	description = "Undo a back jump, like ctrl-i.",
	category = "smart-splits",
	keywords = "pane focus forward next jump history",
	run = function(ctx)
		jump_move(ctx, 1)
	end,
})

rex.bind("cmd+o", "jump_back")
rex.bind("cmd+i", "jump_forward")


-- Floating tool launcher (command palette: shift+cmd+p, category "tools").
require("tools")
