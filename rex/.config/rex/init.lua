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
		rex.session.focus_direction({
			session_id = ctx.session_id,
			direction = direction,
			wrap = false,
		})
		if focused_block(ctx) == block then
			-- No neighbour: give the key back so the shell keeps it.
			forward(key)
		end
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

for direction, base in pairs(KEYS) do
	rex.bind("ctrl+" .. base, "smart_splits_navigate", { direction = direction })
	rex.bind("ctrl+alt+" .. base, "smart_splits_resize", { direction = direction })
end

