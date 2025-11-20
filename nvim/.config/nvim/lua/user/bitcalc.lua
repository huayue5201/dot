local bit = require("bit")

local function band(a, b)
	return bit.band(a, b)
end
local function bor(a, b)
	return bit.bor(a, b)
end
local function bxor(a, b)
	return bit.bxor(a, b)
end
local function lshift(a, b)
	return bit.lshift(a, b)
end
local function rshift(a, b)
	return bit.rshift(a, b)
end
local function bnot(a)
	return bit.bnot(a)
end

local function to_binary(n)
	local t = {}
	for i = 31, 0, -1 do
		table.insert(t, bit.band(bit.rshift(n, i), 1))
	end
	local bin_str = table.concat(t):gsub("^0+", "")
	bin_str = bin_str ~= "" and bin_str or "0"

	-- 每4位加一个空格分隔
	local padded = bin_str:reverse():gsub("....", "%0 "):reverse():gsub("^%s+", "")
	return padded
end

local function format_number_groups(s)
	return s:reverse():gsub("(%d%d%d%d)", "%1 "):reverse():gsub("^%s+", "")
end

local function format_hex_groups(s)
	return s:reverse():gsub("(%x%x%x%x)", "%1 "):reverse():gsub("^%s+", "")
end

local function format_result(val)
	local dec = format_number_groups(tostring(val))
	local hex = format_hex_groups(string.format("%X", val))
	local bin = to_binary(val)
	return {
		" 󰕆  Dec: " .. dec,
		" 󰛡  Hex: 0x" .. hex,
		"   Bin: " .. bin,
	}
end

local function eval_expr(expr)
	-- 去掉空格方便处理
	expr = expr:gsub("%s+", "")

	-- 支持十六进制数字，转成十进制字符串（load里能直接识别其实可不转）
	expr = expr:gsub("0x%x+", function(h)
		return tostring(tonumber(h))
	end)

	-- 替换 C 风格位运算符为函数调用
	-- 支持数字和变量（%w_）
	expr = expr:gsub("([%w_%(%)]+)<<([%w_%(%)]+)", "lshift(%1,%2)")
		:gsub("([%w_]+)>>(%d+)", "rshift(%1,%2)")
		:gsub("~([%w_]+)", "bnot(%1)")
		:gsub("([%w_]+)&([%w_]+)", "band(%1,%2)")
		:gsub("([%w_]+)|([%w_]+)", "bor(%1,%2)")
		:gsub("([%w_]+)~([%w_]+)", "bxor(%1,%2)")

	-- 载入并运行表达式
	local f, err = load("return " .. expr, "bitcalc", "t", {
		band = band,
		bor = bor,
		bxor = bxor,
		lshift = lshift,
		rshift = rshift,
		bnot = bnot,
		math = math, -- 预留，方便扩展
	})

	if not f then
		return nil, "语法错误: " .. err
	end

	local ok, result = pcall(f)
	if not ok then
		return nil, "执行出错: " .. result
	end

	if type(result) ~= "number" then
		return nil, "结果类型错误: 计算结果不是数字"
	end

	return result
end

local open_windows = {}
local function get_next_row(height)
	-- 从第2行开始
	local base_row = -1
	-- 找出当前所有窗口的最大底部行
	local max_bottom = base_row
	for _, win in pairs(open_windows) do
		local win_config = vim.api.nvim_win_get_config(win)
		if win_config.relative == "editor" then
			local top = win_config.row or base_row
			local bottom = top + (win_config.height or height)
			if bottom > max_bottom then
				max_bottom = bottom
			end
		end
	end

	local gap = 2 -- 你想要的间距，比如2行
	return max_bottom + gap
end

local function open_float_win(lines, expr)
	local buf = vim.api.nvim_create_buf(false, true)

	local max_width = 80
	local min_width = 30

	local display_lines = {}
	local max_line_len = 0

	for _, line in ipairs(lines) do
		local chunks = { line }
		for _, chunk in ipairs(chunks) do
			table.insert(display_lines, chunk)
			max_line_len = math.max(max_line_len, vim.fn.strdisplaywidth(chunk))
		end
	end

	local width = math.max(min_width, math.min(max_line_len + 4, max_width))
	local total_height = #display_lines
	local max_height = vim.o.lines - 4
	local height = math.min(total_height, max_height)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

	local row = math.min(get_next_row(height), vim.o.lines - height - 2)
	local col = math.max(2, vim.o.columns - width - 2)

	local win_opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		focusable = true,
		mouse = false,
		style = "minimal",
		border = "rounded",
		title = "  BitCalc ",
		title_pos = "center",
		footer = { { " " .. expr .. " ", "Number" } },
		footer_pos = "center",
	}

	local win = vim.api.nvim_open_win(buf, false, win_opts)

	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("linebreak", true, { win = win })
	vim.api.nvim_set_option_value("scrolloff", 1, { win = win })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- 支持浮窗内容滚动
	local opts = { nowait = true, noremap = true, silent = true }
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-d>", "<C-d>", opts)
	vim.api.nvim_buf_set_keymap(buf, "n", "<C-u>", "<C-u>", opts)
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", opts)

	table.insert(open_windows, win)

	vim.api.nvim_create_autocmd("WinClosed", {
		buffer = buf,
		once = true,
		callback = function()
			for i, w in ipairs(open_windows) do
				if w == win then
					table.remove(open_windows, i)
					break
				end
			end
		end,
	})

	-- 高亮显示结果数字部分
	vim.api.nvim_buf_add_highlight(buf, -1, "Function", 0, 6, -1)
	vim.api.nvim_buf_add_highlight(buf, -1, "Constant", 1, 6, -1)
	vim.api.nvim_buf_add_highlight(buf, -1, "Keyword", 2, 6, -1)

	return win, buf
end

local function bitcalc()
	vim.ui.input({ prompt = "输入表达式: " }, function(input)
		if not input or input == "" then
			return
		end
		local result, err = eval_expr(input)
		if not result then
			vim.notify(err or "", vim.log.levels.ERROR)
		else
			open_float_win(format_result(result), input)
		end
	end)
end

return {
	bitcalc = bitcalc,
}
