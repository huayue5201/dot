-- utils/usb_status.lua

local uv = vim.loop

local colors = require("utils.utils").palette
vim.api.nvim_set_hl(0, "UsbDisconnected", { fg = colors.red, bold = true })
vim.api.nvim_set_hl(0, "UsbConnected", { fg = colors.green3, bold = true })

local M = {}

local CHECK_INTERVAL_MS = 30000

local usb_status = {
	cached_status = "%#UsbDisconnected#󰌘 %*",
	checking = false,
	_output = "",
	_devices = {},
}

-- 平台检测
local function get_platform()
	local sysname = uv.os_uname().sysname:lower()
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

-- 默认 USB 探测命令
local function get_usb_cmd()
	local platform = get_platform()
	if platform == "macos" then
		return "ioreg -p IOUSB -l"
	elseif platform == "linux" then
		return "lsusb"
	elseif platform == "windows" then
		return "wmic path Win32_USBHub"
	else
		return nil
	end
end

-- 探测器注册表
local DETECTORS = {}

--- 注册新的设备探测器
---@param detector { name: string, match: fun(output: string): boolean, display: string, source?: string }
function M.register_device_detector(detector)
	table.insert(DETECTORS, detector)
end

--- 外部注入已识别设备
function M.inject_device(name)
	table.insert(usb_status._devices, name)
	M.update_status()
end

--- 更新状态栏缓存
function M.update_status()
	if #usb_status._devices > 0 then
		local joined = table.concat(usb_status._devices, " | ")
		usb_status.cached_status = "%#UsbConnected#󰌘 %*" .. joined
	else
		usb_status.cached_status = "%#UsbDisconnected#󰌘 %*"
	end
	vim.schedule(function()
		vim.cmd("redrawstatus")
	end)
end

-- 启动探测流程
local function detect_all_devices(output)
	usb_status._devices = {}
	for _, detector in ipairs(DETECTORS) do
		local src_out = output
		if detector.source then
			local handle = io.popen(detector.source)
			if handle then
				src_out = handle:read("*a")
				handle:close()
			end
		end
		if detector.match(src_out) then
			table.insert(usb_status._devices, detector.display)
		end
	end
end

-- 主检测函数
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
		detect_all_devices(usb_status._output)
		M.update_status()
		usb_status.checking = false
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

-- 启动
check_usb()
local timer = uv.new_timer()
timer:start(CHECK_INTERVAL_MS, CHECK_INTERVAL_MS, vim.schedule_wrap(check_usb))

-- 公共接口
M.UsbStatus = function()
	return usb_status.cached_status
end

M.RefreshUsbStatus = function()
	usb_status.checking = false
	check_usb()
	print("🔄 正在刷新 USB 状态…")
end

vim.api.nvim_create_user_command("RefreshUsbStatus", M.RefreshUsbStatus, {})

-- 预注册几个典型设备
M.register_device_detector({
	name = "jlink",
	match = function(out)
		return out:lower():find("j%-link")
	end,
	display = "j",
})
M.register_device_detector({
	name = "stlink",
	match = function(out)
		return out:lower():find("stm32 stlink")
	end,
	display = "st",
})
M.register_device_detector({
	name = "stlink-v3",
	match = function(out)
		return out:lower():find("stlink%-v3")
	end,
	display = "st3",
})

return M
