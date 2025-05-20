local M = {}

local function to_binary(n)
	local t = {}
	repeat
		table.insert(t, 1, n % 2)
		n = math.floor(n / 2)
	until n == 0
	return table.concat(t)
end

local function format_result(val)
	return {
		"计算结果:",
		"Dec: " .. val,
		"Hex: 0x" .. string.format("%X", val),
		"Bin: " .. to_binary(val),
	}
end

local function eval_expr(expr)
	local bit = require("bit")

	-- 支持二进制 0b 前缀
	expr = expr:gsub("0b[01]+", function(bin)
		return tostring(tonumber(bin:sub(3), 2))
	end)

	-- 替换 C 风格位运算为 Lua `bit.*` 函数
	expr = expr:gsub("(%b())%s*>>%s*(%d+)", "bit.rshift(%1,%2)")
		:gsub("(%w+)%s*>>%s*(%d+)", "bit.rshift(%1,%2)")
		:gsub("(%b())%s*<<%s*(%d+)", "bit.lshift(%1,%2)")
		:gsub("(%w+)%s*<<%s*(%d+)", "bit.lshift(%1,%2)")
		:gsub("(%b())%s*&%s*(%b())", "bit.band(%1,%2)")
		:gsub("(%w+)%s*&%s*(%w+)", "bit.band(%1,%2)")
		:gsub("(%b())%s*|%s*(%b())", "bit.bor(%1,%2)")
		:gsub("(%w+)%s*|%s*(%w+)", "bit.bor(%1,%2)")
		:gsub("(%b())%s*~%s*(%b())", "bit.bxor(%1,%2)")
		:gsub("(%w+)%s*~%s*(%w+)", "bit.bxor(%1,%2)")

	local f, err = load("return " .. expr)
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

local function open_float_win(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "filetype", "lua")
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
		border = "shadow",
	}

	vim.api.nvim_open_win(buf, false, win_opts)
end

function M.bitcalc()
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

return M
