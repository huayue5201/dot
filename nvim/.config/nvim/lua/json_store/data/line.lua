-- json_store/data/line.lua
local project = require("json_store.core.project")
local file = require("json_store.data.file")
local store = require("json_store.core.store")
local anchor = require("json_store.data.anchor")

local M = {}

function M.set_line_data(filepath, line, data)
	filepath = filepath or vim.api.nvim_buf_get_name(0)
	local bufnr = vim.fn.bufnr(filepath)
	if bufnr == -1 then
		return
	end

	local _, project_obj = project.get_current_project()
	local store_obj = file.get_file_store(project_obj, filepath)
	local file_data = store.load(store_obj)

	file_data.lines = file_data.lines or {}

	local anchor_obj = anchor.create_anchor(bufnr, line)

	file_data.lines[tostring(line)] = {
		data = data,
		anchor = anchor_obj,
	}

	store.mark_dirty(store_obj)
end

function M.get_line_data(filepath, line)
	filepath = filepath or vim.api.nvim_buf_get_name(0)

	local _, project_obj = project.get_current_project()
	local store_obj = file.get_file_store(project_obj, filepath)
	local file_data = store.load(store_obj)

	local entry = file_data.lines and file_data.lines[tostring(line)]
	if not entry then
		return nil
	end

	return entry.data
end

return M
