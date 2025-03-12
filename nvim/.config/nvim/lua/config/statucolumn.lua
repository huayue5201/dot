local Statuscolumn = {}

-- 创建红色高亮组
vim.cmd("highlight RedMark guifg=#FF0000 gui=bold")
-- 获取当前行的标记
local function get_mark(buf, lnum)
	local marks = vim.fn.getmarklist(buf)
	for _, mark in ipairs(marks) do
		-- 只查找字母标记
		if mark.pos[1] == buf and mark.pos[2] == lnum and mark.mark:match("[a-zA-Z]") then
			return { text = mark.mark:sub(2), texthl = "RedMark" }
		end
	end
end
-- 提取 mark 逻辑封装成一个函数
function Statuscolumn.mark_display()
	local mark_info = get_mark(vim.api.nvim_get_current_buf(), vim.v.lnum)
	if mark_info then
		return "%#" .. mark_info.texthl .. "#" .. mark_info.text
	end
	return ""
end

-- 设置拼接的内容
Statuscolumn.active = function()
	return table.concat({
		"%s",
		"%=",
		"%l",
		"%=",
		Statuscolumn.mark_display(), -- 调用封装后的 mark 函数
		"%=",
		"%C ",
	})
end

return Statuscolumn
