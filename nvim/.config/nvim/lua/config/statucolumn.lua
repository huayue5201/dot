local Statuscolumn = {}

-- 获取标记的函数
vim.cmd("highlight RedMark guifg=#FF0000 gui=bold") -- 创建红色高亮组
local function get_mark(buf, lnum)
	local marks = vim.fn.getmarklist(buf) -- 获取当前 buffer 的标记
	vim.list_extend(marks, vim.fn.getmarklist()) -- 获取全局的标记
	for _, mark in ipairs(marks) do
		if mark.pos[1] == buf and mark.pos[2] == lnum and mark.mark:match("[a-zA-Z]") then
			return { text = mark.mark:sub(2), texthl = "RedMark" }
		end
	end
end

-- 显示标记符号配置
Statuscolumn.mark = function()
	local mark_info = get_mark(vim.api.nvim_get_current_buf(), vim.v.lnum)
	if mark_info then
		-- 如果当前行有标记，返回标记符号和红色高亮组
		return "%#" .. mark_info.texthl .. "#" .. mark_info.text
	end
	return ""
end

-- 设置拼接的内容
Statuscolumn.active = function()
	return table.concat({
		" %C ",
		"%=",
		"%l",
		"%=",
		Statuscolumn.mark(),
		"%=",
		"%s",
	})
end

return Statuscolumn
