-- json_store/sync/relocator.lua
local project = require("json_store.core.project")
local file = require("json_store.data.file")
local store = require("json_store.core.store")
local anchor = require("json_store.data.anchor")

local M = {}

-- 简化的行号重定位
local function apply_diff_to_line(line, hunks)
	if not hunks or #hunks == 0 or not line then
		return line
	end

	local new_line = line

	for _, h in ipairs(hunks) do
		local old_start, old_count, new_start, new_count = unpack(h)
		if not (old_start and old_count and new_start and new_count) then
			goto continue
		end

		local old_end = old_start + old_count - 1
		local delta = new_count - old_count

		if new_line < old_start then
			-- 在hunk之前，不受影响
		elseif new_line >= old_start and new_line <= old_end then
			-- 在hunk内部，被删除
			return nil
		else
			-- 在hunk之后，平移
			new_line = new_line + delta
		end

		::continue::
	end

	return new_line
end

-- 主重定位函数
function M.relocate(bufnr, hunks)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local _, project_obj = project.get_current_project()
	if not project_obj then
		return
	end

	-- 获取文件存储
	local store_obj, file_id = file.get_file_store(project_obj, filepath)
	local file_data = store.load(store_obj)

	if not file_data.lines or vim.tbl_isempty(file_data.lines) then
		return -- 没有需要重定位的数据
	end

	-- 检查是否有数据需要重定位
	local needs_relocation = false
	for line_str, _ in pairs(file_data.lines) do
		local line_num = tonumber(line_str)
		if line_num then
			needs_relocation = true
			break
		end
	end

	if not needs_relocation then
		return
	end

	local new_lines = {}
	local changed = false

	-- 应用diff重定位
	for line_str, entry in pairs(file_data.lines) do
		local old_line = tonumber(line_str)
		if old_line then
			local new_line = apply_diff_to_line(old_line, hunks)

			if new_line and new_line ~= old_line then
				-- 行号变化，更新anchor
				entry.anchor = anchor.create_anchor(bufnr, new_line)
				new_lines[tostring(new_line)] = entry
				changed = true
			elseif new_line == nil then
				-- 行被删除，移除数据
				changed = true
			else
				-- 行号未变，保持原样
				new_lines[line_str] = entry
			end
		else
			-- 非数字行号，保持原样
			new_lines[line_str] = entry
		end
	end

	-- 如果有变化，更新存储
	if changed then
		file_data.lines = new_lines
		store.mark_dirty(store_obj)
	end

	return changed
end

return M
