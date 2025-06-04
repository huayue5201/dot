-- lua/utils/platform_config.lua
M = {}

-- 芯片配置列表
local chip_configs = {
	stm32f103c8t6 = {
		lsp = "clangd",
		dap = "openocd",
		clock_speed = 72000000,
		flash_size = 128,
		svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32F103xx.svd",
		configFiles = {
			"interface/stlink.cfg",
			"target/stm32f103c8t6.cfg",
		},
	},
	stm32h743vi = {
		lsp = "clangd",
		dap = "probe-rs",
		clock_speed = 180000000,
		flash_size = 2048,
		svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32H743x.svd",
		configFiles = {
			"interface/stlink.cfg",
			"target/stm32h7x.cfg",
		},
	},
	-- 可以继续添加其他芯片的配置
}

-- 存储已选择的芯片配置
M.selected_chip_config = nil

-- 选择芯片的函数
function M.choose_chip()
	local chips = { "stm32f103c8t6", "stm32h743vi" } -- 列出支持的芯片型号
	vim.ui.select(chips, {
		prompt = "选择目标芯片",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			-- 获取选择的芯片配置
			M.selected_chip_config = chip_configs[choice]
			print("已选择芯片: " .. choice)
			-- 显示选择的芯片配置
			vim.api.nvim_out_write("已选择芯片配置: " .. vim.inspect(M.selected_chip_config) .. "\n")
		end
	end)
end

-- 返回已选择的芯片配置
function M.get_selected_chip_config()
	return M.selected_chip_config
end

return M
