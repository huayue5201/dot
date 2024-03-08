-- telescope_debuggers.lua

local M = {}

-- 定义函数来配置 Telescope 的行为和选项，选择调试器
M.select_debugger = function()
	local debuggers = {
		"codelldb",
		-- 添加其他调试器名称
	}

	-- 设置 Telescope 选项
	local opts = {
		prompt_title = "Select Debugger",
		sorting_strategy = "ascending",
		layout_strategy = "vertical",
		layout_config = {
			height = 12,
			width = 0.9,
			preview_cutoff = 10,
			prompt_position = "top",
		},
	}

	-- 在这里添加 Telescpe 的配置和逻辑
end

return M
