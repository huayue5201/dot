-- 错误捕获模块：捕捉Neovim所有错误输出并在退出时保存到日志
local M = {}

-- 默认配置
local default_config = {
	-- 日志文件路径（默认在当前工作目录）
	log_file = "nvim_error.log",
	-- 是否追加日志（false则每次覆盖）
	append_log = true,
	-- 是否监控寄存器写入中的异常（如null字符）
	monitor_reg = true,
	-- 是否在终端打印日志保存提示
	show_notification = true,
}

-- 合并用户配置和默认配置
local config = {}

-- 检查路径是否为绝对路径（兼容所有Neovim版本的纯Lua实现）
local function is_absolute_path(path)
	if not path then
		return false
	end
	-- Unix/Linux/macOS 绝对路径以 / 开头
	if vim.fn.has("unix") == 1 then
		return path:sub(1, 1) == "/"
	-- Windows 绝对路径以 盘符:/ 或 \\ 开头（可选，按需保留）
	elseif vim.fn.has("win32") == 1 then
		return path:match("^%a:[/\\]") or path:sub(1, 2) == "\\\\"
	end
	return false
end

-- 初始化：重写setreg监控寄存器异常（通用版）
local function init_reg_monitor()
	if not config.monitor_reg then
		return
	end

	local old_setreg = vim.fn.setreg
	vim.fn.setreg = function(reg, val, ...)
		-- 记录调用堆栈（用于调试）
		local stack = debug.traceback("", 2)

		-- 检测并清理null字符（通用，不针对特定插件）
		if val and type(val) == "string" then
			-- 检查null字符
			if val:find("%z") then
				vim.notify(
					string.format(
						"⚠️ 检测到寄存器 '%s' 中包含null字符，已自动清理\n调用堆栈: %s",
						reg,
						stack
					),
					vim.log.levels.ERROR
				)
				val = val:gsub("%z", "")
			end

			-- 可选：记录所有寄存器写入（调试用，默认关闭）
			-- vim.notify(string.format("寄存器 '%s' 写入内容: %s", reg, val:sub(1, 50)), vim.log.levels.INFO)
		end

		-- 调用原始setreg
		return old_setreg(reg, val, ...)
	end
end

-- 收集错误信息
local function collect_errors()
	local errors = {}

	-- 1. 获取:messages中的所有消息
	local messages = vim.fn.execute("messages")
	for line in messages:gmatch("[^\r\n]+") do
		-- 匹配错误/警告关键词（通用规则）
		if
			line:match("E%d+") -- Neovim内置错误码（如E486）
			or line:match("[Ee]rror") -- Error/error
			or line:match("[Ww]arning") -- Warning/warning
			or line:match("[Ff]ail") -- Fail/fail
			or line:match("[Cc]rash") -- Crash/crash
			or line:match("[Ee]xception")
		then -- Exception/exception
			table.insert(errors, line)
		end
	end

	-- 2. 获取全局错误变量v:errmsg
	local errmsg = vim.fn.eval("v:errmsg")
	if errmsg and errmsg ~= "" then
		table.insert(errors, "全局错误信息(v:errmsg): " .. errmsg)
	end

	return errors
end

-- 写入错误日志
local function write_error_log(errors)
	if #errors == 0 then
		return
	end

	-- 构建日志内容
	local log_content = {
		"=== Neovim 错误日志 ===",
		"时间: " .. os.date("%Y-%m-%d %H:%M:%S"),
		"工作目录: " .. vim.fn.getcwd(),
		"Neovim版本: " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
		"============================",
		"",
	}

	-- 添加错误信息
	for i, err in ipairs(errors) do
		table.insert(log_content, string.format("%d. %s", i, err))
	end
	table.insert(log_content, "\n") -- 分隔不同会话的日志

	-- 确定文件打开模式
	local mode = config.append_log and "a" or "w"

	-- 写入文件（带异常处理）
	local ok, err = pcall(function()
		local file = io.open(config.log_file, mode)
		if not file then
			error("无法打开日志文件: " .. config.log_file)
		end
		file:write(table.concat(log_content, "\n"))
		file:close()

		-- 终端提示
		if config.show_notification then
			print(string.format("错误日志已保存到: %s", vim.fn.expand(config.log_file)))
		end
	end)

	-- 日志写入失败的提示
	if not ok then
		print("❌ 错误日志写入失败: " .. err)
	end
end

-- 注册退出前的自动命令
local function setup_autocmd()
	vim.api.nvim_create_autocmd("VimLeavePre", {
		pattern = "*",
		callback = function()
			local errors = collect_errors()
			write_error_log(errors)
		end,
		desc = "Neovim退出前收集并保存错误日志",
	})
end

-- 模块入口：初始化配置并启动监控
function M.setup(user_config)
	-- 合并配置
	config = vim.tbl_deep_extend("force", default_config, user_config or {})

	-- 解析日志路径（支持绝对路径/相对路径）- 替换了原来的vim.fn.isabs
	if not is_absolute_path(config.log_file) then
		config.log_file = vim.fn.getcwd() .. "/" .. config.log_file
	end

	-- 初始化寄存器监控
	init_reg_monitor()

	-- 注册自动命令
	setup_autocmd()

	-- 启动提示
	if config.show_notification then
		print("✅ 错误捕获模块已加载，日志文件: " .. config.log_file)
	end
end

return M
