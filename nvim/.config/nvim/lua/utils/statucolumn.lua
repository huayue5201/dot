-- lua/utils/statucolumn.lua
local Statuscolumn = {}

-- 设置自定义的高亮组
Statuscolumn.setHl = function()
	-- 定义自定义的高亮组，设置边框的颜色
	vim.api.nvim_set_hl(0, "StatusBorder", {
		fg = "#CBA6F7", -- 设置前景色
		bg = "#1E1E2E", -- 设置背景色
	})
end

-- 边框的函数
Statuscolumn.border = function()
	return "%#StatusBorder#│" -- 直接返回边框的部分
end

-- 行号的函数
Statuscolumn.number = function(config)
	local text = ""
	-- 获取当前行号
	if config.mode == "normal" then
		text = vim.v.lnum
	elseif config.mode == "relative" then
		text = vim.v.relnum
	elseif config.mode == "hybrid" then
		text = vim.v.relnum == 0 and vim.v.lnum or vim.v.relnum
	end
	-- 在返回值中添加占位符，以便其它部分可以更灵活的自动对齐
	return text .. " "
end

-- 折叠状态的函数
Statuscolumn.folds = function()
	local foldlevel = vim.fn.foldlevel(vim.v.lnum)
	local foldlevel_before = vim.fn.foldlevel(vim.v.lnum - 1)
	local foldlevel_after = vim.fn.foldlevel(vim.v.lnum + 1)
	local foldclosed = vim.fn.foldclosed(vim.v.lnum)
	-- 如果当前行没有折叠信息，返回空格
	if foldlevel == 0 then
		return " "
	end
	-- 如果当前行是折叠的行
	if foldclosed ~= -1 and foldclosed == vim.v.lnum then
		return "▶ "
	end
	-- 如果当前行是折叠的开始行
	if foldlevel > foldlevel_before then
		return "▽ "
	end
	-- 如果当前行是折叠的最后一行
	if foldlevel > foldlevel_after then
		return "╰ "
	end
	-- 其他情况为折叠中的行
	return "╎ "
end

-- 创建主状态列的函数
Statuscolumn.statuscolumn = function()
	local text = ""
	-- 使用 `%=` 来在每个功能块之间创建占位符，使它们分布得更自然
	text = table.concat({
		Statuscolumn.folds(), -- 折叠符号
		Statuscolumn.number({ mode = "relative" }), -- 行号
		"%=", -- 自动填充的占位符
		Statuscolumn.border(), -- 边框
		"%=", -- 右边再加入一个占位符
	})
	return text
end

return Statuscolumn
