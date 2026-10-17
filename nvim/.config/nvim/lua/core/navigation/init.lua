-- 导航模块聚合入口
-- 拆分为：settings（数据）、keymaps（数据）、errors（逻辑）、
-- smart_close（逻辑）、dispatch（分发器）
local M = {}

-- 数据
M.settings = require("core.navigation.settings")
M.buf_keymaps = require("core.navigation.keymaps")

-- 错误跳转
local errors = require("core.navigation.errors")
M.error_patterns = errors.error_patterns
M.get_error_lines = errors.get_error_lines
M.next_error = errors.next_error
M.prev_error = errors.prev_error
M.next_error_repeatable = errors.next_error_repeatable
M.prev_error_repeatable = errors.prev_error_repeatable
M._repeat_jump_callback = errors._repeat_jump_callback

-- 智能关闭
M.smart_close = require("core.navigation.smart_close").smart_close

-- 命令分发
M.dispatch_command = require("core.navigation.dispatch").dispatch_command

-- 窗口尺寸守卫：关窗时把被撑大的 winfix 窗口塞回原尺寸
M.winfix_guard = require("core.navigation.winfix_guard")

local api = vim.api

--- 为当前 buffer 应用快捷键映射（数据来自 buf_keymaps）。
local function apply_keymaps()
	local ft = vim.bo.filetype
	local bt = vim.bo.buftype
	local bufname = vim.fn.bufname("%")
	local applied = vim.b.keymaps_applied or {}

	-- 确定当前窗口的类型标识（优先级：filetype > buftype）
	local buf_type = ft ~= "" and ft or bt

	for key, type_configs in pairs(M.buf_keymaps) do
		-- 跳过已映射的按键
		if not applied[key] then
			local config = type_configs[buf_type]

			if not config and bufname:match("dap%-repl") then
				config = type_configs["dap-repl"]
			end

			if config and config.cmd then
				local cmd = config.cmd
				local desc = config.desc or ("映射: " .. key)

				vim.keymap.set("n", key, function()
					M.dispatch_command(cmd)
				end, {
					buffer = true,
					silent = true,
					noremap = true,
					nowait = true,
					desc = desc,
				})

				applied[key] = true
			end
		end
	end

	vim.b.keymaps_applied = applied
end

--- 按 settings 表应用 buffer 局部设置。
local function apply_settings(args)
	local buf = args.buf
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local kind = (ft ~= "" and ft) or bt

	if M.settings[kind] and M.settings[kind].setup then
		M.settings[kind].setup()
	end
end

--- 注册导航/窗口相关的 autocmd 与守卫。由 init.lua 调用。
function M.setup()
	api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		group = api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
		desc = "根据配置表自动应用窗口快捷键",
		callback = apply_keymaps,
	})

	api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
		group = api.nvim_create_augroup("CustomBufferSettings", { clear = true }),
		desc = "根据配置表自动应用 buffer 设置",
		callback = apply_settings,
	})

	M.winfix_guard.setup()
end

return M
