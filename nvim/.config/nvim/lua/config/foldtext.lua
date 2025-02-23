local M = {}

-- 替换制表符为对应的空格
local function replace_tabs_with_spaces(line)
	return line:gsub("\t", string.rep(" ", vim.o.tabstop))
end

-- 自定义折叠文本的虚拟高亮
local function fold_virt_text(result, s, lnum, coloff)
	if not coloff then
		coloff = 0
	end
	local text = ""
	local hl
	for i = 1, #s do
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local _hl = hls[#hls]
		if _hl then
			local new_hl = "@" .. _hl.capture
			if new_hl ~= hl then
				if text ~= "" then
					table.insert(result, { text, hl })
				end
				text = ""
				hl = new_hl
			end
			text = text .. char
		else
			text = text .. char
		end
	end
	if text ~= "" then
		table.insert(result, { text, hl })
	end
end

-- 自定义折叠文本
function M.custom_foldtext()
	local start = replace_tabs_with_spaces(vim.fn.getline(vim.v.foldstart))
	local end_str = vim.fn.getline(vim.v.foldend)
	local end_ = vim.trim(end_str)
	local fold_lines = vim.v.foldend - vim.v.foldstart + 1 -- 计算折叠的行数

	local result = {}

	-- 为折叠文本添加虚拟高亮
	fold_virt_text(result, start, vim.v.foldstart - 1)

	-- 添加省略号
	table.insert(result, { " ... ", "Delimiter" })

	-- 添加折叠结束的虚拟高亮
	fold_virt_text(result, end_, vim.v.foldend - 1, #(end_str:match("^(%s+)") or ""))

	-- 将图标和折叠行数添加到最后
	local fold_icon = "  " -- 你可以使用任何图标
	table.insert(result, { " " .. fold_icon .. " " .. fold_lines .. " lines", "Delimiter" })

	return result
end

return M
