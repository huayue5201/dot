local json_store = require("utils.json_store")

local M = {}

-- 存储所有芯片配置（包含默认配置）
local chip_configs = {
	default = {
		chip = "󰚦 ",
		configFiles = {},
		svdFile = "",
		openocd_template = "",
		probe = "",
	},
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
		svdFile = "/path/to/nrf52.svd",
	},
}

-- 校验每个芯片配置是否包含必须字段
local function validate_chip_configs()
	local required_fields = { "chip", "configFiles" }
	for name, conf in pairs(chip_configs) do
		-- 跳过默认配置
		if name ~= "default" then
			for _, key in ipairs(required_fields) do
				if conf[key] == nil then
					vim.notify(("芯片配置 [%s] 缺少字段: %s"):format(name, key), vim.log.levels.WARN)
				end
			end

			-- 确保所有配置都有svdFile字段
			if not conf.svdFile then
				conf.svdFile = chip_configs.default.svdFile
				vim.notify(("芯片配置 [%s] 缺少svdFile，使用默认值"):format(name), vim.log.levels.INFO)
			end
		end
	end
end

validate_chip_configs()

-- 创建 JSON 存储实例
local chip_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/selected_chip_config.json",
	default_data = {},
})

-- 获取当前项目名称（基于当前工作目录）
local function get_current_project_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 保存芯片配置到文件
local function save_chip_config(config_name, project_name)
	if not chip_configs[config_name] then
		vim.notify("无效的芯片配置: " .. config_name, vim.log.levels.ERROR)
		return false
	end

	-- 直接存储芯片名称，而不是嵌套结构
	return chip_store:set(project_name, config_name)
end

-- 自动检测芯片类型（优化版）
local function auto_detect_chip()
	local project_name = get_current_project_name()
	local project_name_lower = project_name:lower()

	-- 1. 尝试从项目名匹配
	for chip_name, _ in pairs(chip_configs) do
		if chip_name ~= "default" and project_name_lower:find(chip_name:lower(), 1, true) then
			return chip_name
		end
	end

	-- 2. 检查项目中的特定文件
	local project_files = {
		"Makefile",
		"CMakeLists.txt",
		"platformio.ini",
		"Cargo.toml",
	}

	for _, file in ipairs(project_files) do
		if vim.fn.filereadable(file) == 1 then
			local content = table.concat(vim.fn.readfile(file), "\n"):lower()

			-- 优先匹配完整芯片名称
			for chip_name, _ in pairs(chip_configs) do
				if chip_name ~= "default" and content:find(chip_name:lower(), 1, true) then
					return chip_name
				end
			end

			-- 尝试从文件内容中提取芯片型号
			local patterns = {
				"mcu%s*=%s*['\"]?([%w_]+)",
				"chip%s*=%s*['\"]?([%w_]+)",
				"target%s*=%s*['\"]?([%w_]+)",
				"stm32([fhl]%d+%w*)", -- STM32 系列匹配
				"nrf(%d+)", -- nRF 系列匹配
			}

			for _, pattern in ipairs(patterns) do
				local chip_match = content:match(pattern)
				if chip_match then
					-- 尝试标准化匹配结果
					local normalized = chip_match:gsub("[_%-]", ""):lower()

					for chip_name, _ in pairs(chip_configs) do
						if chip_name ~= "default" then
							-- 尝试多种匹配方式
							local chip_lower = chip_name:lower()
							if
								chip_lower == normalized
								or chip_lower:find(normalized, 1, true)
								or normalized:find(chip_lower, 1, true)
							then
								return chip_name
							end
						end
					end
				end
			end
		end
	end

	return nil
end

-- 在启动时加载配置
function M.load_chip_config_on_startup()
	local project_name = get_current_project_name()
	local selected_chip = chip_store:get(project_name)

	-- 1. 尝试加载缓存配置
	if selected_chip and chip_configs[selected_chip] then
		vim.g.selected_chip_config = chip_configs[selected_chip]
		vim.notify(("加载芯片配置: %s -> %s"):format(project_name, selected_chip), vim.log.levels.INFO)
		return
	end

	-- 2. 尝试自动检测
	local detected_chip = auto_detect_chip()
	if detected_chip and chip_configs[detected_chip] then
		vim.g.selected_chip_config = chip_configs[detected_chip]
		save_chip_config(detected_chip, project_name)
		vim.notify(("自动检测到芯片: %s -> %s"):format(project_name, detected_chip), vim.log.levels.INFO)
		return
	end

	-- 3. 使用默认配置
	vim.g.selected_chip_config = chip_configs.default
end

-- 安全获取芯片配置
function M.get_safe_config()
	return vim.g.selected_chip_config or chip_configs.default
end

-- 选择芯片的函数
function M.choose_chip()
	local project_name = get_current_project_name()
	local chips = {}

	-- 从chip_configs中提取所有芯片名称（排除default）
	for chip, _ in pairs(chip_configs) do
		if chip ~= "default" then
			table.insert(chips, chip)
		end
	end

	table.sort(chips)

	vim.ui.select(chips, {
		prompt = "选择芯片架构",
		format_item = function(item)
			return chip_configs[item].chip .. " (" .. item .. ")"
		end,
	}, function(choice)
		if choice then
			vim.g.selected_chip_config = chip_configs[choice]
			save_chip_config(choice, project_name)
			vim.notify(("已选择芯片: %s"):format(choice), vim.log.levels.INFO)
		end
	end)
end

-- 返回已选择的芯片配置
function M.get_selected_chip_config()
	if not vim.g.selected_chip_config then
		vim.schedule(function()
			vim.notify("未配置芯片，请使用 :ChooseChip 选择芯片配置", vim.log.levels.WARN, {
				title = "芯片配置缺失",
				timeout = 3000,
			})
		end)
		return chip_configs.default
	end
	return vim.g.selected_chip_config
end

-- ChipStatus: 状态栏显示
function M.ChipStatus()
	local config = M.get_safe_config()

	vim.api.nvim_set_hl(0, "chipIcon", { fg = "#6B8E23", bold = true })

	return "%#chipIcon# %*" .. config.chip
end

-- 初始化芯片配置
M.load_chip_config_on_startup()

return M
