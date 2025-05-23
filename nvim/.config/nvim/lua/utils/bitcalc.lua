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
	local result = table.concat(t):gsub("^0+", "")
	return result ~= "" and result or "0"
end

local function format_result(val)
	return {
		"   Dec: " .. val,
		"   Hex: 0x" .. string.format("%X", val),
		"   Bin: " .. to_binary(val),
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
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 40
	local height = #lines
	-- local col = math.max(0, vim.o.columns - width - 2)
	local row = get_next_row(height)

	local win_opts = {
		relative = "editor",
		row = row,
		col = vim.o.columns - width - 2,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " 󱖦 BitCalc ",
		title_pos = "center",
		footer = { { " " .. expr .. " ", "Number" } },
		footer_pos = "center",
	}

	local win = vim.api.nvim_open_win(buf, false, win_opts)

	-- 记录窗口id
	table.insert(open_windows, win)

	-- 窗口关闭自动清理 open_windows
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

	-- 关闭窗口的快捷键
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { nowait = true, noremap = true, silent = true })

	-- 自动设置buffer不可修改，避免误操作
	vim.api.nvim_get_option_value("modifiable", { buf = buf })

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

local function bitcalc_visual()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" then
		vim.notify("请在 Visual 模式下使用", vim.log.levels.WARN)
		return
	end
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	-- 处理多行选中，连接为一整串表达式
	local expr_lines = {}
	for i, line in ipairs(lines) do
		if i == 1 and i == #lines then
			-- 只有一行选区，截取start_col到end_col
			expr_lines[#expr_lines + 1] = line:sub(start_pos[3], end_pos[3])
		elseif i == 1 then
			-- 第一行截取start_col到行尾
			expr_lines[#expr_lines + 1] = line:sub(start_pos[3])
		elseif i == #lines then
			-- 最后一行截取行首到end_col
			expr_lines[#expr_lines + 1] = line:sub(1, end_pos[3])
		else
			-- 中间整行
			expr_lines[#expr_lines + 1] = line
		end
	end
	local selected_text = table.concat(expr_lines, "")

	if selected_text == "" then
		vim.notify("没有选中任何文本", vim.log.levels.ERROR)
		return
	end

	local result, err = eval_expr(selected_text)
	if not result then
		vim.notify(err or "", vim.log.levels.ERROR)
	else
		open_float_win(format_result(result), selected_text)
	end
end

return {
	bitcalc = bitcalc,
	bitcalc_visual = bitcalc_visual,
}
