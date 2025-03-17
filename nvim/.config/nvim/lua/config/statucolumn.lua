local Statuscolumn = {}

Statuscolumn.folds = function()
	local lnum = vim.v.lnum
	local foldlevel = vim.fn.foldlevel(lnum)
	local foldlevel_before = vim.fn.foldlevel(math.max(1, lnum - 1))
	local foldlevel_after = vim.fn.foldlevel(math.min(vim.fn.line("$"), lnum + 1))
	local foldclosed = vim.fn.foldclosed(lnum)

	-- 1️⃣ 该行不属于任何折叠
	if foldlevel == 0 then
		return " "
	end
	-- 2️⃣ 该行是折叠的起点（关闭状态）
	if foldclosed == lnum then
		return "╶" -- ▶ 代表折叠行
	end
	-- 3️⃣ 该行是新折叠的开始
	if foldlevel > foldlevel_before then
		return "╭" -- ▽ 代表折叠起始
	end
	-- 4️⃣ 该行是折叠的最后一行
	if foldlevel > foldlevel_after then
		return "╰" -- ╰ 代表折叠结束
	end
	-- 5️⃣ 该行在一个打开的折叠中
	return "│"
end

-- 设置拼接的内容
Statuscolumn.active = function()
	return table.concat({
		"%s",
		"%=",
		"%l",
		"%=",
		"%=",
		Statuscolumn.folds(),
		-- "%C ",
	})
end

return Statuscolumn
