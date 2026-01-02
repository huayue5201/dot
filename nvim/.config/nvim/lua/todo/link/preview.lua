-- lua/todo/link/preview.lua
local M = {}

local store = require("todo.store")

function M.preview_todo()
	local line = vim.fn.getline(".")
	local id = line:match("TODO:ref:(%w+)")

	if not id then
		return
	end

	local link = store.get_todo_link(id)
	if not link then
		return
	end

	local ok, lines = pcall(vim.fn.readfile, link.path)
	if not ok then
		return
	end

	local start_line = math.max(1, link.line - 3)
	local end_line = math.min(#lines, link.line + 3)
	local context_lines = {}

	for i = start_line, end_line do
		table.insert(context_lines, lines[i])
	end

	local content = table.concat(context_lines, "\n")

	vim.lsp.util.open_floating_preview({ content }, "markdown", {
		border = "rounded",
		focusable = true,
	})
end

function M.preview_code()
	local line = vim.fn.getline(".")
	local id = line:match("{#(%w+)}")

	if not id then
		return
	end

	local link = store.get_code_link(id)
	if not link then
		return
	end

	local ok, lines = pcall(vim.fn.readfile, link.path)
	if not ok then
		return
	end

	local start_line = math.max(1, link.line - 3)
	local end_line = math.min(#lines, link.line + 3)
	local context_lines = {}

	for i = start_line, end_line do
		table.insert(context_lines, lines[i])
	end

	local content = table.concat(context_lines, "\n")

	vim.lsp.util.open_floating_preview({ content }, "markdown", {
		border = "rounded",
		focusable = true,
	})
end

return M
