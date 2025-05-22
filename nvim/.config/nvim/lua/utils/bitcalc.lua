-- 加载 FFI 库
local ffi = require("ffi")

-- 定义 C 函数接口
ffi.cdef([[
    unsigned int band(unsigned int a, unsigned int b);
    unsigned int bor(unsigned int a, unsigned int b);
    unsigned int bxor(unsigned int a, unsigned int b);
    unsigned int lshift(unsigned int a, int b);
    unsigned int rshift(unsigned int a, int b);
    unsigned int bnot(unsigned int a);
]])

-- 加载 C 标准库
local bit = ffi.C

-- 封装位运算函数
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

-- 辅助函数：将十进制数转换为二进制字符串
local function to_binary(n)
	local t = {}
	repeat
		table.insert(t, 1, n % 2)
		n = math.floor(n / 2)
	until n == 0
	return table.concat(t)
end

-- 格式化结果
local function format_result(val)
	return {
		"   Dec: " .. val,
		"   Hex: 0x" .. string.format("%X", val),
		"   Bin: " .. to_binary(val),
	}
end

-- 解析表达式，替换 C 风格的位运算符并计算结果
local function eval_expr(expr)
	-- 替换表达式中的位运算符
	expr = expr:gsub("(%w+)%s*&%s*(%w+)", "band(%1, %2)")
	expr = expr:gsub("(%w+)%s*|%s*(%w+)", "bor(%1, %2)")
	expr = expr:gsub("(%w+)%s*~%s*(%w+)", "bxor(%1, %2)")
	expr = expr:gsub("(%w+)%s*<<%s*(%d+)", "lshift(%1, %2)")
	expr = expr:gsub("(%w+)%s*>>%s*(%d+)", "rshift(%1, %2)")
	expr = expr:gsub("~(%w+)", "bnot(%1)")

	-- 使用 load 函数执行 Lua 表达式，确保传递 bit 函数
	local f, err = load(
		"return " .. expr,
		"expr",
		"t",
		{ band = band, bor = bor, bxor = bxor, lshift = lshift, rshift = rshift, bnot = bnot }
	)
	if not f then
		return nil, "表达式错误: " .. err
	end

	local ok, result = pcall(f)
	if not ok then
		return nil, "计算失败: " .. result
	end

	if type(result) ~= "number" then
		return nil, "结果类型错误: 非数字"
	end

	return result
end

-- 打开浮动窗口显示计算结果
local function open_float_win(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("filetype", "c", { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 40
	local height = #lines

	local win_opts = {
		relative = "editor",
		row = 1,
		col = vim.o.columns - width,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = "BitCalc",
		title_pos = "left",
		footer = { { "计算结果", "Type" } },
		footer_pos = "center",
	}

	vim.api.nvim_open_win(buf, false, win_opts)
end

-- 用户输入表达式并计算
local function bitcalc()
	vim.ui.input({ prompt = "输入表达式 : " }, function(input)
		if not input or input == "" then
			return
		end

		local result, err = eval_expr(input)
		if err then
			vim.notify(err, vim.log.levels.ERROR)
			return
		end

		open_float_win(format_result(result))
	end)
end

-- 获取 Visual 模式下选中的文本并计算
local function bitcalc_visual()
	-- 获取当前选区的文本
	local start_line, start_col = unpack(vim.api.nvim_buf_get_mark(0, "<"))
	local end_line, end_col = unpack(vim.api.nvim_buf_get_mark(0, ">"))
	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	local selected_text = table.concat(lines, "\n"):sub(start_col + 1, end_col)

	-- 如果选中的文本为空，直接返回
	if selected_text == "" then
		vim.notify("没有选中任何文本", vim.log.levels.ERROR)
		return
	end

	-- 计算选中的文本
	local result, err = eval_expr(selected_text)
	if err then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	-- 打开浮动窗口显示计算结果
	open_float_win(format_result(result))
end

return {
	bitcalc = bitcalc,
	bitcalc_visual = bitcalc_visual,
}
