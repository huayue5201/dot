local Statuscolumn = {}

-- 获取标记的函数
local M = {}

function M.get_mark(buf, lnum)
	local marks = vim.fn.getmarklist(buf)
	vim.list_extend(marks, vim.fn.getmarklist())
	for _, mark in ipairs(marks) do
		if mark.pos[1] == buf and mark.pos[2] == lnum and mark.mark:match("[a-zA-Z]") then
			return { text = mark.mark:sub(2), texthl = "DiagnosticHint" }
		end
	end
end

-- 显示标记符号配置
Statuscolumn.mark = function()
	local mark_info = M.get_mark(vim.api.nvim_get_current_buf(), vim.v.lnum)
	if mark_info then
		-- 如果当前行有标记，返回标记符号和高亮组
		return "%#" .. mark_info.texthl .. "#" .. mark_info.text
	end
	return ""
end

-- 设置拼接的内容
Statuscolumn.active = function()
	return table.concat({
		" %s",
		"%=", -- 自动分隔（左右对齐）
		"%l",
		"%=", -- 自动分隔（左右对齐）
		Statuscolumn.mark(), -- 显示标记符号
		"%=",
		"%C",
	})
end

return Statuscolumn
