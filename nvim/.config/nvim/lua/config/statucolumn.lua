local Statuscolumn = {}

-- 边框配置
Statuscolumn.border = function()
	return vim.v.relnum < 9 and ("%#Gradient_" .. (vim.v.lnum + 1) .. "#│") or "%#Gradient_10#│"
end

-- 行号配置
Statuscolumn.line_number = function()
	return "%l"
end

-- 折叠配置
Statuscolumn.fold_config = function()
	local foldlevel = vim.fn.foldlevel(vim.v.lnum)
	if foldlevel == 0 then
		return " "
	end

	local foldlevel_before = vim.fn.foldlevel(vim.v.lnum - 1)
	local foldlevel_after = vim.fn.foldlevel(vim.v.lnum + 1)
	local foldclosed = vim.fn.foldclosed(vim.v.lnum)

	-- 处理折叠状态
	if foldclosed ~= -1 and foldclosed == vim.v.lnum then
		return "▾"
	elseif foldlevel > foldlevel_before then
		return "▸"
	elseif foldlevel > foldlevel_after then
		return "╰"
	end
	return "│"
end

-- 设置拼接的内容
Statuscolumn.active = function()
	return table.concat({
		" %s",
		"%=", -- 自动分隔（左右对齐）
		Statuscolumn.line_number(),
		"%=", -- 自动分隔（左右对齐）
		"%C",
	})
end

return Statuscolumn
