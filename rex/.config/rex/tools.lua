-- Tool launcher: one entry per tool, opened in a floating layer.
--
-- Every tool below becomes an action in the command palette under "tools".
-- Open the palette (shift+cmd+p), type the tool name, and pick it. The entry
-- is not tied to the program in the focused pane: lazygit can float over
-- Neovim, Neovim can float over lazygit, and so on.
--
-- Add a tool by adding a row to TOOLS. `keep_open` keeps the pane visible
-- after the program exits so its last output can be read.

local TERM = "com.superlogical.terminal"

local TOOLS = {
	{ id = "lazygit", title = "lazygit", cmd = { "lazygit" }, keep_open = true, keywords = "git" },
	{ id = "nvim", title = "Neovim", cmd = { "nvim" }, keep_open = false, keywords = "editor vim" },
	{ id = "claude", title = "Claude", cmd = { "claude" }, keep_open = true, keywords = "agent ai" },
	{ id = "yazi", title = "yazi", cmd = { "yazi" }, keep_open = false, keywords = "files file manager" },
	{ id = "btop", title = "btop", cmd = { "btop" }, keep_open = false, keywords = "monitor process cpu" },
}

local function focused_block(ctx)
	if ctx.block_id then
		return ctx.block_id
	end
	local view = rex.session.view({ session_id = ctx.session_id })
	if type(view) ~= "table" then
		return nil
	end
	for _, window in ipairs(view.windows or {}) do
		if window.window_id == view.active_window_id then
			return window.focused_block_id
		end
	end
	for _, window in ipairs(view.windows or {}) do
		if window.focused_block_id then
			return window.focused_block_id
		end
	end
	return nil
end

-- The directory the tool should start in: the focused terminal's reported
-- working directory, falling back to the foreground process's cwd.
local function cwd_of(ctx)
	local block_id = focused_block(ctx)
	if not block_id then
		return nil
	end

	local ok, info = pcall(rex.block.call, TERM, "pwd", { block_id = block_id })
	local pwd = ok and type(info) == "table" and info.pwd or nil
	if pwd then
		return (pwd:gsub("^file://", ""))
	end

	ok, info = pcall(rex.block.call, TERM, "process", { block_id = block_id })
	local foreground = ok and type(info) == "table" and info.foreground or nil
	return foreground and foreground.cwd or nil
end

local function open_float(ctx, tool)
	local options = {
		command = tool.cmd,
		cwd = cwd_of(ctx),
	}
	if tool.keep_open then
		options.exit = { on_completion = false }
	end

	local layer, err = rex.session.new_layer({
		session_id = ctx.session_id,
		bounds = { 0.08, 0.08, 0.84, 0.84 },
		focus = true,
		layout = rex.layout.block({
			flavor = TERM .. ".shell",
			options = options,
		}),
	})
	if not layer then
		rex.log("error", "float_" .. tool.id .. ": " .. tostring(err))
	end
	return layer
end

for _, tool in ipairs(TOOLS) do
	rex.action({
		name = "float_" .. tool.id,
		title = "Float: " .. tool.title,
		description = "Open " .. tool.title .. " in a floating layer in the focused pane's directory.",
		category = "tools",
		keywords = "tool float popup launcher " .. (tool.keywords or tool.id),
		run = function(ctx)
			open_float(ctx, tool)
		end,
	})
end
