-- 导航/窗口：buffer 快捷键 + buffer 设置 + 错误跳转 + 智能关闭 + 窗口尺寸守卫
-- 对外接口：setup()、smart_close(win)、_repeat_jump_callback（operatorfunc 用）
local M = {}

local api = vim.api
local handlers = require("feat.navigation.handlers")

--- 数据：filetype/buftype -> buffer 局部设置
--- size 声明窗口期望尺寸，布局变化后由 winfix_guard 维持。
M.settings = {
	["dap-repl"] = {
		setup = function()
			vim.opt_local.confirm = false
			vim.opt.buflisted = false
		end,
	},
	["neotest-output"] = {
		setup = function()
			vim.opt_local.winfixbuf = true
			vim.opt.buflisted = false
		end,
	},
	["sqmeow-drawer"] = {
		size = function()
			local ok, width = pcall(function()
				return require("sqmeow.config").get().ui.drawer.width
			end)
			return { width = ok and width or 42 }
		end,
	},
	["sqmeow-result"] = {
		size = function()
			local ok, height = pcall(function()
				return require("sqmeow.config").get().ui.result.height
			end)
			return { height = ok and height or 16 }
		end,
	},
}

--- 数据：按键 -> { filetype/buftype -> { cmd = 命令字符串|function, desc } }
--- 特殊命令（由 dispatch_command 解析）：next_error / prev_error /
--- next_error_repeatable / prev_error_repeatable / smart_close
M.buf_keymaps = {
	-- 关闭窗口（q 键）
	["q"] = {
		help = { cmd = "quit", desc = "关闭帮助窗口" },
		man = { cmd = "quit", desc = "关闭 man 窗口" },
		msgmore = { cmd = "quit", desc = "关闭消息窗口" },
		FunctionReferences = { cmd = "quit", desc = "关闭引用窗口" },
		checkhealth = { cmd = "close", desc = "关闭健康检查" },
		better_term = { cmd = "close", desc = "关闭终端" },
		["grug-far"] = { cmd = "bdelete", desc = "关闭搜索替换" },
		["dap-repl"] = { cmd = "close", desc = "关闭 DAP REPL" },
		["dap-float"] = { cmd = "close", desc = "关闭 DAP 浮动窗" },
		["dap-view-term"] = { cmd = "close", desc = "关闭 DAP 终端" },
		["dap-view"] = { cmd = "DapViewClose", desc = "关闭 DAP 视图" },
		["gitsigns-blame"] = { cmd = "bdelete!", desc = "关闭 blame" },
		terminal = { cmd = "bdelete", desc = "关闭终端" },
		["nvim-undotree"] = { cmd = "close", desc = "关闭 undotree" },
		["codediff-explorer"] = { cmd = "tabclose", desc = "关闭 diff" },
		["codediff-history"] = { cmd = "tabclose", desc = "关闭 diff 历史" },
		["codediff-help"] = { cmd = "close", desc = "关闭 diff 帮助" },
		OverseerOutput = { cmd = "close", desc = "关闭任务输出" },
		["neotest-summary"] = { cmd = "close", desc = "关闭测试摘要" },
		["neotest-output"] = { cmd = "close", desc = "关闭测试输出" },
		["neotest-output-panel"] = { cmd = "close", desc = "关闭测试输出面板" },
	},

	-- 错误跳转：下一个（]d），用 repeatable 版本支持 . 重复
	["]d"] = {
		["better_term"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output-panel"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
	},

	-- 错误跳转：上一个（[d）
	["[d"] = {
		["better_term"] = { cmd = "prev_error_repeatable", desc = "上一个错误（支持 . 重复）" },
		["neotest-output"] = { cmd = "prev_error_repeatable", desc = "上一个错误（支持 . 重复）" },
		["neotest-output-panel"] = { cmd = "prev_error_repeatable", desc = "上一个错误（支持 . 重复）" },
	},
}

-- 错误跳转 API（operatorfunc 里按模块名引用，所以要在本模块上保留）
M.error_patterns = handlers.error_patterns
M.get_error_lines = handlers.get_error_lines
M.next_error = handlers.next_error
M.prev_error = handlers.prev_error
M.next_error_repeatable = handlers.next_error_repeatable
M.prev_error_repeatable = handlers.prev_error_repeatable
M._repeat_jump_callback = handlers._repeat_jump_callback

function M.smart_close(target_win)
	handlers.smart_close(target_win, M.buf_keymaps["q"])
end

--- 把 cmd 字符串/函数分发到对应逻辑
local function dispatch_command(cmd)
	if cmd == "next_error" then
		handlers.next_error()
	elseif cmd == "prev_error" then
		handlers.prev_error()
	elseif cmd == "next_error_repeatable" then
		handlers.next_error_repeatable()
	elseif cmd == "prev_error_repeatable" then
		handlers.prev_error_repeatable()
	elseif cmd == "smart_close" then
		M.smart_close()
	elseif type(cmd) == "function" then
		cmd()
	else
		pcall(vim.cmd, cmd)
	end
end

--- 为当前 buffer 应用快捷键映射（数据来自 buf_keymaps）
local function apply_keymaps()
	local ft = vim.bo.filetype
	local bt = vim.bo.buftype
	local bufname = vim.fn.bufname("%")
	local applied = vim.b.keymaps_applied or {}

	-- 窗口类型标识：filetype 优先，其次 buftype
	local buf_type = ft ~= "" and ft or bt

	for key, type_configs in pairs(M.buf_keymaps) do
		if not applied[key] then
			local config = type_configs[buf_type]

			if not config and bufname:match("dap%-repl") then
				config = type_configs["dap-repl"]
			end

			if config and config.cmd then
				local cmd = config.cmd
				vim.keymap.set("n", key, function()
					dispatch_command(cmd)
				end, {
					buffer = true,
					silent = true,
					noremap = true,
					nowait = true,
					desc = config.desc or ("映射: " .. key),
				})

				applied[key] = true
			end
		end
	end

	vim.b.keymaps_applied = applied
end

--- 按 settings 表应用 buffer 局部设置
local function apply_settings(args)
	local buf = args.buf
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local kind = (ft ~= "" and ft) or bt

	if M.settings[kind] and M.settings[kind].setup then
		M.settings[kind].setup()
	end
end

--- 注册 autocmd 与窗口尺寸守卫。由 init.lua 调用。
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

	require("feat.navigation.winfix_guard").setup(nil, M.settings)
	-- 焦点在插件状态窗口时，让打开文件/LSP 跳转落到编辑区而不是把它顶掉。
	require("feat.navigation.redirect").setup()
end

return M
