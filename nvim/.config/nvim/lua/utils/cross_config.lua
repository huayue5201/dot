M = {}

-- 存储所有芯片配置
local chip_configs = {
	stm32f103c8t6 = {
		svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32F103xx.svd",
		chip = "STM32F103C8",
		openocd_template = "openocd -f interface/stlink.cfg -f target/stm32f1x.cfg -c 'program {binary_file} verify reset exit'",
		probe = "0483:3752:066AFF494982654867254648", -- （可选）指定具体调试器，如果多个设备可用时手动选择
		configFiles = {
			"interface/stlink.cfg",
			"target/stm32f1x.cfg",
		},
	},
	stm32h743vi = {
		svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32H743x.svd",
		chip = "STM32H743VI", -- 指定目标芯片型号，必须准确匹配
		openocd_template = "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c 'program {binary_file} verify reset exit'",
		probe = "0483:3754:0032003E3532510A31333430", -- （可选）指定具体调试器，如果多个设备可用时手动选择
		configFiles = {
			"interface/stlink.cfg",
			"target/stm32h7x.cfg",
		},
	},
	nrf52 = {
		chip = "nrf52833_xxAA",
		configFiles = {
			"interface/cmsis-dap.cfg",
			"target/nrf52.cfg",
		},
	},
}

-- 缓存文件路径
local cache_file_path = vim.fn.stdpath("cache") .. "/selected_chip_config.json"

-- 自动创建目录（如果不存在）
local function create_cache_dir()
	local cache_dir = vim.fn.stdpath("cache")
	vim.fn.mkdir(cache_dir, "p")
end

-- 保存选择的芯片配置到文件
local function save_chip_config_to_file(config_name)
	create_cache_dir()
	local json_data = vim.fn.json_encode({ selected_chip = config_name })
	local file = io.open(cache_file_path, "w")
	if file then
		file:write(json_data)
		file:close()
		print("Chip config saved: " .. config_name)
	else
		print("Error saving chip config.")
	end
end

-- 从缓存文件读取芯片配置
local function load_chip_config_from_file()
	local file = io.open(cache_file_path, "r")
	if file then
		local content = file:read("*all")
		local data = vim.fn.json_decode(content)
		file:close()
		return data.selected_chip
	end
	return nil
end

-- 在启动时加载配置并初始化 vim.g.selected_chip_config
function M.load_chip_config_on_startup()
	local cached_chip_config = load_chip_config_from_file()
	if cached_chip_config then
		vim.g.selected_chip_config = chip_configs[cached_chip_config]
		print("Loaded chip config: " .. cached_chip_config)
	else
		vim.g.selected_chip_config = nil
		print("No cached chip config found.")
	end
end

-- 选择芯片的函数
function M.choose_chip()
	-- 自动从 chip_configs 中获取芯片列表
	local chips = {}
	for chip, _ in pairs(chip_configs) do
		table.insert(chips, chip)
	end

	vim.ui.select(chips, {
		prompt = " 芯片架构  ",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			vim.g.selected_chip_config = chip_configs[choice]
			save_chip_config_to_file(choice)
		end
	end)
end

-- 返回已选择的芯片配置
function M.get_selected_chip_config()
	return vim.g.selected_chip_config
end

-- ChipStatus: 返回当前选择的芯片状态
vim.api.nvim_set_hl(0, "chipIion", { fg = "#6B8E23", bold = true })
function M.ChipStatus()
	local selected_chip = vim.g.selected_chip_config
	if selected_chip then
		-- 设置状态栏显示格式
		return "%#chipIion# %*" .. selected_chip.chip
	end
end

return M
