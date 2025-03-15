local Statuscolumn = {}

-- 设置拼接的内容
Statuscolumn.active = function()
	return table.concat({
		"%s",
		"%=",
		"%l",
		"%=",
		"%=",
		"%C ",
	})
end

return Statuscolumn
