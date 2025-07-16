-- BrickDAG/ui/window_factory.lua
local M = {}
local border_chars = {
	{ "╭", "FloatBorder" },
	{ "─", "FloatBorder" },
	{ "╮", "FloatBorder" },
	{ "│", "FloatBorder" },
	{ "╯", "FloatBorder" },
	{ "─", "FloatBorder" },
	{ "╰", "FloatBorder" },
	{ "│", "FloatBorder" },
}

function M.create(opts)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = border_chars,
		row = opts.row,
		col = opts.col,
		width = opts.width,
		height = opts.height,
		zindex = opts.zindex or 50,
	})

	return { win = win, buf = buf }
end

return M
