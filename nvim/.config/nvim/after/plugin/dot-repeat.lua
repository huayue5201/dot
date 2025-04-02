local repeat_action = nil
local repeat_count = 1

--- 记录最近的操作（支持 Lua 函数）
---@param action function|string
---@param count number
function _G.set_repeat_action(action, count)
	repeat_action = action
	repeat_count = count or 1
end

--- 执行最近的操作（支持按键和 Lua 函数）
function _G.repeat_last_action()
	if repeat_action then
		if type(repeat_action) == "string" then
			-- 如果是字符串（按键序列），用 feedkeys 执行
			local final_keys = string.rep(repeat_action, repeat_count)
			vim.api.nvim_feedkeys(final_keys, "n", true)
		elseif type(repeat_action) == "function" then
			-- 如果是 Lua 函数，则调用它 repeat_count 次
			for _ = 1, repeat_count do
				repeat_action()
			end
		end
	else
		vim.notify("No repeatable action recorded!", vim.log.levels.WARN)
	end
end

-- 绑定 `.` 号，使其调用 repeat_last_action
vim.keymap.set("n", ".", "<cmd>lua _G.repeat_last_action()<CR>", { noremap = true, silent = true })

--- 创建可重复的映射（支持 Lua 函数）
---@param mode string 模式，如 "n"、"x" 等
---@param lhs string 触发按键
---@param rhs function|string 实际执行的操作（按键或 Lua 函数）
---@param opts table 额外参数
vim.g.repeatable_map = function(mode, lhs, rhs, opts)
	opts = opts or {}
	opts.noremap = true
	opts.silent = true

	vim.keymap.set(mode, lhs, function()
		local count = vim.v.count1 -- 记录 `count`
		_G.set_repeat_action(rhs, count)

		if type(rhs) == "string" then
			-- 如果是字符串，直接执行按键
			local final_keys = string.rep(rhs, count)
			vim.api.nvim_feedkeys(final_keys, "n", true)
		elseif type(rhs) == "function" then
			-- 如果是 Lua 函数，执行它 count 次
			for _ = 1, count do
				rhs()
			end
		end
	end, opts)
end
