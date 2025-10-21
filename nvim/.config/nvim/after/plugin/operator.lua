-- 创建唯一模块命名空间
local M = {
	operators = {},
	auto_counter = 0,
	last_operator = nil,
}

-- 全局分派函数
if not _G.__operator_dispatch then
	_G.__operator_dispatch = function()
		if M.last_operator then
			local op = M.operators[M.last_operator]
			if op and op.func then
				local ok, err = pcall(op.func)
				if not ok then
					vim.notify("Operator error: " .. err, vim.log.levels.ERROR)
				end
				-- 保持 operatorfunc 支持重复
				vim.o.operatorfunc = "v:lua.__operator_dispatch"
			end
		end
	end
end

-- 注册操作符（内部函数）
local function register_operator(func, opts)
	opts = opts or {}
	M.auto_counter = M.auto_counter + 1
	local name = "auto_operator_" .. M.auto_counter

	-- 默认 motion = ""
	local motion = opts.motion or ""

	-- 判断是否非选区命令（字符串命令）
	local is_non_motion = false
	if type(func) == "string" then
		local cmd = func
		func = function()
			if vim.bo.modifiable then
				vim.cmd(cmd)
			else
				vim.notify("当前 buffer 不可修改，操作符未执行", vim.log.levels.WARN)
			end
		end
		is_non_motion = true
	end

	M.operators[name] = {
		func = func,
		motion = motion,
		is_non_motion = is_non_motion,
	}

	return function()
		M.last_operator = name
		vim.o.operatorfunc = "v:lua.__operator_dispatch"

		if M.operators[name].is_non_motion then
			vim.notify("此操作为非选区命令，无法使用 g@ / 重复操作", vim.log.levels.INFO)
			func()
			return
		end

		local mode = vim.fn.mode()
		if mode == "v" or mode == "V" or mode == "\22" then
			vim.cmd("normal! g@")
		else
			vim.cmd("normal! g@" .. motion)
		end
	end
end

-- 处理 map_opts：数组+字典混合
local function normalize_map_opts(map_opts)
	local res = {}
	if not map_opts then
		return res
	end

	-- ✅ 改进：更清晰的选项处理
	for k, v in pairs(map_opts) do
		if type(k) == "string" then
			res[k] = v
		elseif type(v) == "table" then
			for subk, subv in pairs(v) do
				res[subk] = subv
			end
		end
	end
	return res
end

-- 创建操作符映射
local function create_operator(mode, key, func, map_opts)
	local processed_map_opts = normalize_map_opts(map_opts)

	-- 提取 operator_opts
	local operator_opts = {}
	if processed_map_opts.operator_opts then
		operator_opts = vim.deepcopy(processed_map_opts.operator_opts)
		processed_map_opts.operator_opts = nil
	end

	-- motion 单独处理
	if processed_map_opts.motion then
		operator_opts.motion = processed_map_opts.motion
		processed_map_opts.motion = nil
	end

	local callback = register_operator(func, operator_opts)

	-- ✅ 改进：更好的错误处理
	local ok, err = pcall(function()
		vim.keymap.set(mode, key, callback, processed_map_opts)
	end)

	if not ok then
		vim.notify("Failed to set operator mapping: " .. err, vim.log.levels.ERROR)
		return false
	end

	return true
end

-- 全局可用
vim.operator = create_operator

-- ✅ 新增：工具函数，便于使用
M.utils = {
	-- 获取当前可视选区内容
	get_visual_selection = function()
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		local lines = vim.fn.getline(start_pos[2], end_pos[2])

		if #lines == 0 then
			return ""
		end

		-- 处理行内选区
		local start_col = start_pos[3]
		local end_col = end_pos[3]

		if #lines == 1 then
			return string.sub(lines[1], start_col, end_col)
		else
			lines[1] = string.sub(lines[1], start_col)
			lines[#lines] = string.sub(lines[#lines], 1, end_col)
			return table.concat(lines, "\n")
		end
	end,

	-- 简单的操作符示例
	example_operators = {
		-- 转换为大写
		to_upper = function()
			local selection = M.utils.get_visual_selection()
			if selection and #selection > 0 then
				vim.api.nvim_input("c" .. selection:upper())
			end
		end,

		-- 转换为小写
		to_lower = function()
			local selection = M.utils.get_visual_selection()
			if selection and #selection > 0 then
				vim.api.nvim_input("c" .. selection:lower())
			end
		end,

		-- 复制到系统剪贴板
		copy_to_clipboard = function()
			local selection = M.utils.get_visual_selection()
			if selection and #selection > 0 then
				vim.fn.setreg("+", selection)
				vim.notify("已复制到系统剪贴板", vim.log.levels.INFO)
			end
		end,
	},
}

-- 模块重载支持
if package.loaded["custom_operators"] then
	local reloaded = package.loaded["custom_operators"]
	M.operators = reloaded.operators
	M.auto_counter = reloaded.auto_counter
end

-- ✅ 新增：清理函数，避免内存泄漏
function M.cleanup()
	for name, operator in pairs(M.operators) do
		if operator.is_non_motion and type(operator.func) == "function" then
			-- 清理字符串命令创建的函数
			operator.func = nil
		end
	end
	-- 可选：清理长时间未使用的操作符
end

return M
