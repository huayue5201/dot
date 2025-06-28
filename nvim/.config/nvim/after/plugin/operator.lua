-- 创建唯一模块命名空间
local M = {
	operators = {},
	auto_counter = 0,
	last_operator = nil,
}

-- 单一全局分派函数（仅在第一次加载时定义）
if not _G.__operator_dispatch then
	_G.__operator_dispatch = function()
		if M.last_operator then
			local op = M.operators[M.last_operator]
			if op and op.func then
				-- 安全执行操作符函数
				local ok, err = pcall(op.func)
				if not ok then
					vim.notify("Operator error: " .. err, vim.log.levels.ERROR)
				end

				-- 设置重复操作
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

	-- 默认设置 motion = "" 如果未指定
	local motion = opts.motion or ""

	M.operators[name] = {
		func = func,
		motion = motion,
	}

	return function()
		-- 设置当前操作符为最后使用的操作符
		M.last_operator = name
		-- 配置操作函数
		vim.o.operatorfunc = "v:lua.__operator_dispatch"
		-- 执行操作符命令
		vim.cmd("normal! g@" .. motion)
	end
end

-- 直接创建操作符映射
local function create_operator(mode, key, func, map_opts)
	-- 处理混合表（数组+字典）
	local processed_map_opts = {}
	if map_opts then
		-- 处理数组部分
		for i, v in ipairs(map_opts) do
			if type(v) == "table" then
				for k, val in pairs(v) do
					processed_map_opts[k] = val
				end
			end
		end

		-- 处理字典部分
		for k, v in pairs(map_opts) do
			if type(k) ~= "number" then -- 跳过数组索引
				processed_map_opts[k] = v
			end
		end
	else
		processed_map_opts = {}
	end

	-- 提取操作符选项
	local operator_opts = {}
	if processed_map_opts.operator_opts then
		operator_opts = vim.deepcopy(processed_map_opts.operator_opts)
		processed_map_opts.operator_opts = nil
	end

	-- 注册并获取触发函数
	local callback = register_operator(func, operator_opts)

	-- 设置按键映射
	vim.keymap.set(mode, key, callback, processed_map_opts)
end

-- 使函数全局可用
vim.operator = create_operator

-- 模块重新加载支持：更简洁的处理
if package.loaded["custom_operators"] then
	local reloaded = package.loaded["custom_operators"]
	-- 保留现有操作符注册
	M.operators = reloaded.operators
	-- 继续使用现有计数器避免ID冲突
	M.auto_counter = reloaded.auto_counter
end

return M
