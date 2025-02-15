-- statuscolumn.lua

local Statuscolumn = {}

Statuscolumn.border = function()
	-- NOTE: lua tables start at 1 but relnum starts at 0, so we add 1 to it to get the highlight group
	if vim.v.relnum < 9 then
		return "%#Gradient_" .. (vim.v.lnum + 1) .. "#│"
	else
		return "%#Gradient_10#│"
	end
end

-- 行号配置
Statuscolumn.line_number = function()
	return "%l"
end

-- 折叠配置
Statuscolumn.fold_config = function()
	local foldlevel = vim.fn.foldlevel(vim.v.lnum)
	local foldlevel_before = vim.fn.foldlevel((vim.v.lnum - 1) >= 1 and vim.v.lnum - 1 or 1)
	local foldlevel_after =
		vim.fn.foldlevel((vim.v.lnum + 1) <= vim.fn.line("$") and (vim.v.lnum + 1) or vim.fn.line("$"))
	local foldclosed = vim.fn.foldclosed(vim.v.lnum)
	-- Line has nothing to do with folds so we will skip it
	if foldlevel == 0 then
		return " "
	end
	-- Line is a closed fold(I know second condition feels unnecessary but I will still add it)
	if foldclosed ~= -1 and foldclosed == vim.v.lnum then
		return "▾"
	end
	-- I didn't use ~= because it couldn't make a nested fold have a lower level than it's parent fold and it's not something I would use
	if foldlevel > foldlevel_before then
		return "▸"
	end
	-- The line is the last line in the fold
	if foldlevel > foldlevel_after then
		return "╰"
	end
	-- Line is in the middle of an open fold
	return "│"
end

-- 设置拼接的内容
Statuscolumn.active = function()
	local line_str = Statuscolumn.line_number() -- 行号
	-- local fold_str = Statuscolumn.fold_config() -- 折叠文本
	-- local border_str = Statuscolumn.border()

	return table.concat({
		" %s",
		"%=", -- 自动分隔（左右对齐）
		line_str,
		"%=", -- 自动分隔（左右对齐）
		-- border_str,
		"%C",
		-- fold_str,
	})
end

return Statuscolumn
