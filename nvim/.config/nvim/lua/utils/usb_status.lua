local uv = vim.loop

local M = {}

local usb_status = {
	cached_status = "%#UsbDisconnected#  %*",
	checking = false,
	_output = "",
}

-- 设备关键词映射（key: 关键字，value: 显示名）
local DEVICE_MAP = {
	["j-link"] = "j",
	["stm32 stlink"] = "st",
	["daplink"] = "dap",
}

local CHECK_INTERVAL_MS = 30000

-- 平台自动检测
local function get_platform()
	local sysname = vim.loop.os_uname().sysname:lower()
	if sysname == "darwin" then
		return "macos"
	elseif sysname == "linux" then
		return "linux"
	elseif sysname:find("windows") then
		return "windows"
	else
		return "unknown"
	end
end

-- 根据平台构造命令
local function get_usb_cmd()
	local platform = get_platform()
	if platform == "macos" then
		return "ioreg -p IOUSB -l"
	elseif platform == "linux" then
		return "lsusb"
	else
		return nil
	end
end

-- 查找第一个匹配的设备显示名
local function detect_device_name(output)
	local lower_out = output:lower()
	for key, display_name in pairs(DEVICE_MAP) do
		if lower_out:find(key, 1, true) then
			return display_name
		end
	end
	return nil
end

local function update_status()
	local device_name = detect_device_name(usb_status._output)
	if device_name then
		usb_status.cached_status = string.format("%%#UsbConnected# %s%%*", device_name)
	else
		usb_status.cached_status = "%#UsbDisconnected#  %*"
	end
	vim.schedule(function()
		vim.cmd("redrawstatus")
	end)
end

local function check_usb()
	if usb_status.checking then
		return
	end
	usb_status.checking = true
	usb_status._output = ""

	local cmd = get_usb_cmd()
	if not cmd then
		vim.schedule(function()
			vim.notify("不支持当前平台 USB 检测", vim.log.levels.ERROR)
		end)
		usb_status.checking = false
		return
	end

	local stdout = uv.new_pipe(false)
	local handle

	handle = uv.spawn("sh", {
		args = { "-c", cmd },
		stdio = { nil, stdout, nil },
	}, function()
		if stdout then
			stdout:close()
		end
		if handle then
			handle:close()
		end
		usb_status.checking = false
		update_status()
	end)

	if not handle then
		usb_status.checking = false
		vim.schedule(function()
			vim.notify("启动 USB 检测失败", vim.log.levels.ERROR)
		end)
		return
	end

	stdout:read_start(function(err, data)
		if err then
			vim.schedule(function()
				vim.notify("USB 状态读取错误: " .. err, vim.log.levels.WARN)
			end)
			return
		end
		if data then
			usb_status._output = usb_status._output .. data
		end
	end)
end

-- 启动立即检测
check_usb()

-- 定时检测
local timer = uv.new_timer()
timer:start(CHECK_INTERVAL_MS, CHECK_INTERVAL_MS, vim.schedule_wrap(check_usb))

-- 用户可调用函数
M.UsbStatus = function()
	return usb_status.cached_status
end

-- 用户手动触发命令
M.RefreshUsbStatus = function()
	usb_status.checking = false
	check_usb()
	print("🔄 正在刷新 USB 状态…")
end

vim.api.nvim_create_user_command("RefreshUsbStatus", M.RefreshUsbStatus, {})

return M
