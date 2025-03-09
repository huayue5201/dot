local M = {}

-- 替换制表符为对应的空格（智能计算列宽）
local function replace_tabs_with_spaces(line)
	local col = 0
	return line:gsub("\t", function()
		local spaces = vim.o.tabstop - (col % vim.o.tabstop)
		col = col + spaces
		return string.rep(" ", spaces)
	end)
end

-- 获取折叠内的 LSP 诊断信息（匹配全局配置）
local function get_fold_diagnostics(start_lnum, end_lnum)
	local diagnostics = vim.diagnostic.get(0) -- 获取当前缓冲区的诊断信息
	local counts = { ERROR = 0, WARN = 0, HINT = 0, INFO = 0 }

	-- 统计不同类型的诊断数量
	for _, diag in ipairs(diagnostics) do
		if diag.lnum >= start_lnum and diag.lnum <= end_lnum then
			if diag.severity == vim.diagnostic.severity.ERROR then
				counts.ERROR = counts.ERROR + 1
			elseif diag.severity == vim.diagnostic.severity.WARN then
				counts.WARN = counts.WARN + 1
			elseif diag.severity == vim.diagnostic.severity.HINT then
				counts.HINT = counts.HINT + 1
			elseif diag.severity == vim.diagnostic.severity.INFO then
				counts.INFO = counts.INFO + 1
			end
		end
	end

	-- 按 **优先级** 选择显示
	local diag_text = ""
	if counts.ERROR > 0 then
		diag_text = string.format("  ✘ %d ", counts.ERROR) -- 错误
	elseif counts.WARN > 0 then
		diag_text = string.format("  ▲ %d ", counts.WARN) -- 警告
	elseif counts.HINT > 0 then
		diag_text = string.format("  ⚑ %d ", counts.HINT) -- 提示
	elseif counts.INFO > 0 then
		diag_text = string.format("  » %d ", counts.INFO) -- 信息
	end

	-- 选择对应的高亮组
	local hl = ""
	if counts.ERROR > 0 then
		hl = "DiagnosticSignError"
	elseif counts.WARN > 0 then
		hl = "DiagnosticSignWarn"
	elseif counts.HINT > 0 then
		hl = "DiagnosticSignHint"
	elseif counts.INFO > 0 then
		hl = "DiagnosticSignInfo"
	end

	return diag_text, hl
end

-- 自定义折叠文本的虚拟高亮
local function fold_virt_text(result, s, lnum, coloff)
	coloff = coloff or 0
	local text, hl = "", "Normal"

	for i = 1, #s do
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local _hl = hls[1] or { capture = "Normal" } -- 取第一个高亮

		local new_hl = "@" .. _hl.capture
		if new_hl ~= hl then
			if text ~= "" then
				table.insert(result, { text, hl })
			end
			text, hl = "", new_hl
		end
		text = text .. char
	end
	if text ~= "" then
		table.insert(result, { text, hl })
	end
end

-- 自定义折叠文本
function M.custom_foldtext()
	local start_lnum = vim.v.foldstart - 1
	local end_lnum = vim.v.foldend - 1
	local start = replace_tabs_with_spaces(vim.fn.getline(vim.v.foldstart))
	local end_str = vim.fn.getline(vim.v.foldend)
	local end_ = vim.trim(end_str)
	local fold_lines = vim.v.foldend - vim.v.foldstart + 1

	local result = {}

	-- 为折叠文本添加虚拟高亮
	fold_virt_text(result, start, start_lnum)

	-- 添加省略号
	table.insert(result, { " … ", "Delimiter" })

	-- 获取 LSP 诊断信息（如果有）
	local diag_text, diag_hl = get_fold_diagnostics(start_lnum, end_lnum)
	if diag_text ~= "" then
		table.insert(result, { diag_text, diag_hl }) -- 诊断信息高亮
	end

	-- 添加折叠行数信息（统一对齐）
	local fold_info = string.format("   %d lines ", fold_lines)
	table.insert(result, { fold_info, "Delimiter" })

	return result
end

return M
