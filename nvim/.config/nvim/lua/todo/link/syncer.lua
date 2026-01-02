-- lua/todo/link/syncer.lua
local M = {}

local store = require("todo.store")
local renderer = require("todo.link.renderer")

function M.sync_code_links()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local found = {}
	for i, line in ipairs(lines) do
		local id = line:match("TODO:ref:(%w+)")
		if id then
			found[id] = i
		end
	end

	-- 同步当前文件的链接
	local all_code_links = store.get_all_code_links()

	for id, info in pairs(all_code_links) do
		if info.path == path then
			if not found[id] then
				store.delete_code_link(id)
			elseif found[id] ~= info.line then
				store.save_code_link(id, path, found[id])
			end
		end
	end

	vim.schedule(function()
		renderer.render_code_status(bufnr)
	end)
end

function M.sync_todo_links()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	-- 确保是绝对路径
	path = vim.fn.fnamemodify(path, ":p")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local found = {}
	for i, line in ipairs(lines) do
		local id = line:match("{#(%w+)}")
		if id then
			found[id] = i
		end
	end

	-- 同步当前文件的链接
	local all = store.get_all_todo_links()
	for id, info in pairs(all) do
		-- 比较绝对路径
		if vim.fn.fnamemodify(info.path, ":p") == path then
			if not found[id] then
				store.delete_todo_link(id)
			elseif found[id] ~= info.line then
				store.save_todo_link(id, path, found[id])
			end
		end
	end

	-- 更新相关代码文件的显示
	for id, _ in pairs(found) do
		local code = store.get_code_link(id)
		if code then
			local cbuf = vim.fn.bufnr(code.path)
			if cbuf ~= -1 then
				vim.schedule(function()
					renderer.render_code_status(cbuf)
				end)
			end
		end
	end
end

return M
