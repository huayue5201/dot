M = {}

-- 存储所有芯片配置
local chip_configs = {
	stm32f103c8t6 = {
		svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32F103xx.svd",
		chip = "STM32F103C8",
		openocd_template = "openocd -f interface/stlink.cfg -f target/stm32f1x.cfg -c 'program {binary_file} verify reset exit'",
		probe = "0483:3752:066AFF494982654867254648",
		configFiles = {
			"interface/stlink.cfg",
			"target/stm32f1x.cfg",
		},
	},
	stm32h743vi = {
		svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32H743x.svd",
		chip = "STM32H743VI",
		openocd_template = "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c 'program {binary_file} verify reset exit'",
		probe = "0483:3754:0032003E3532510A31333430",
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

-- 校验每个芯片配置是否包含必须字段
local function validate_chip_configs()
	local required_fields = { "chip", "configFiles" }
	for name, conf in pairs(chip_configs) do
		for _, key in ipairs(required_fields) do
			if conf[key] == nil then
				vim.notify(("芯片配置 [%s] 缺少字段: %s"):format(name, key), vim.log.levels.WARN)
			end
		end
	end
end

-- 在模块加载时执行校验
validate_chip_configs()

-- 缓存文件路径
local cache_file_path = vim.fn.stdpath("cache") .. "/selected_chip_config.json"

-- 自动创建目录（如果不存在）
local function create_cache_dir()
	local cache_dir = vim.fn.stdpath("cache")
	vim.fn.mkdir(cache_dir, "p")
end

-- 获取当前项目名称（假设当前项目是当前打开的目录）
local function get_current_project_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 读取缓存数据
local function load_chip_config_from_file()
	local file = io.open(cache_file_path, "r")
	if file then
		local content = file:read("*all")
		local data = vim.fn.json_decode(content)
		file:close()
		return data or {}
	end
	return {}
end

-- 保存每个项目的芯片配置到文件
local function save_chip_config_to_file(config_name, project_name)
	create_cache_dir()
	local cached_data = load_chip_config_from_file()
	cached_data[project_name] = { selected_chip = config_name }
	local json_data = vim.fn.json_encode(cached_data)

	local file = io.open(cache_file_path, "w")
	if file then
		file:write(json_data)
		file:close()
		print("Chip config saved for project: " .. project_name .. " - " .. config_name)
	else
		print("Error saving chip config.")
	end
end

-- 在启动时加载配置并初始化 vim.g.selected_chip_config
function M.load_chip_config_on_startup()
	local project_name = get_current_project_name()
	local cached_chip_config = load_chip_config_from_file()

	if cached_chip_config[project_name] then
		vim.g.selected_chip_config = chip_configs[cached_chip_config[project_name].selected_chip]
		print("Loaded chip config for project: " .. project_name)
	else
		vim.g.selected_chip_config = nil
		print("No cached chip config found for project: " .. project_name)
	end
end

-- 选择芯片的函数
function M.choose_chip()
	local project_name = get_current_project_name()
	local chips = {}

	-- 自动从 chip_configs 中获取芯片列表
	for chip, _ in pairs(chip_configs) do
		table.insert(chips, chip)
	end

	vim.ui.select(chips, {
		prompt = "选择芯片架构",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			vim.g.selected_chip_config = chip_configs[choice]
			save_chip_config_to_file(choice, project_name) -- 保存当前项目的芯片配置
		end
	end)
end

-- 返回已选择的芯片配置
function M.get_selected_chip_config()
	return vim.g.selected_chip_config
end

-- ChipStatus: 返回当前选择的芯片状态
vim.api.nvim_set_hl(0, "chipIion", { fg = "#6B8E23", bold = true })
vim.api.nvim_set_hl(0, "chipNotSelected", { fg = "#FF6347", bold = true })

function M.ChipStatus()
	local selected_chip = vim.g.selected_chip_config
	if selected_chip then
		return "%#chipIion# %*" .. selected_chip.chip
	else
		return "%#chipNotSelected# No Chip Selected"
	end
end

return M
