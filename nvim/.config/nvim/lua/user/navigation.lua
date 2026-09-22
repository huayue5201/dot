-- File: ~/dotfiles/nvim/.config/nvim/lua/user.navigation.lua

local M = {}

-- ============================
-- 缓冲区特殊设置
-- ============================
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
	terminal = {
		setup = function()
			vim.opt_local.winfixbuf = true
		end,
	},
	sidekick_terminal = {
		setup = function()
			-- vim.opt_local.winfixbuf = true
			local keys_to_disable = { "<c-o>", "<c-i>", "<c-q>" }
			local modes = { "n", "v" } -- 指定要禁用的模式：n=普通, v=可视
			for _, mode in ipairs(modes) do
				for _, key in ipairs(keys_to_disable) do
					vim.keymap.set(mode, key, "<Nop>", { buffer = true, silent = true })
				end
			end
		end,
	},
}

-- ============================
-- 统一的快捷键配置表
-- ============================
-- 格式：
--   [按键] = {
--     [filetype或buftype] = {
--       cmd = "命令字符串" 或 function,
--       desc = "描述信息（可选）"
--     }
--   }
-- 特殊命令：next_error, prev_error, next_error_repeatable, prev_error_repeatable, smart_close 会自动调用对应函数
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
		git = { cmd = "bdelete", desc = "关闭 git 窗口" },
		["dap-repl"] = { cmd = "close", desc = "关闭 DAP REPL" },
		["dap-float"] = { cmd = "close", desc = "关闭 DAP 浮动窗" },
		["dap-view-term"] = { cmd = "close", desc = "关闭 DAP 终端" },
		["dap-view"] = { cmd = "DapViewClose", desc = "关闭 DAP 视图" },
		["gitsigns-blame"] = { cmd = "bdelete!", desc = "关闭 blame" },
		terminal = { cmd = "bdelete", desc = "关闭终端" },
		["nvim-undotree"] = { cmd = "close", desc = "关闭 undotree" },
		["vscode-diff-explorer"] = { cmd = "tabclose", desc = "关闭 diff" },
		OverseerOutput = { cmd = "close", desc = "关闭任务输出" },
		["neotest-summary"] = { cmd = "close", desc = "关闭测试摘要" },
		["neotest-output"] = { cmd = "close", desc = "关闭测试输出" },
		["neotest-output-panel"] = { cmd = "close", desc = "关闭测试输出面板" },
	},

	-- 错误跳转：下一个（]d 键）
	-- 使用 next_error_repeatable 以支持 . 重复命令
	["]d"] = {
		["better_term"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output-panel"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
	},

	-- 错误跳转：上一个（[d 键）
	-- 使用 prev_error_repeatable 以支持 . 重复命令
	["[d"] = {
		["better_term"] = { cmd = "prev_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output"] = { cmd = "prev_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output-panel"] = { cmd = "prev_error_repeatable", desc = "下一个错误（支持 . 重复）" },
	},
}

-- ============================
-- 错误跳转核心函数
-- ============================

-- 匹配错误位置的正则表达式
-- 匹配以 warning/error/panic 等开头的行
M.error_patterns = {
	-- 匹配 Rust 错误：error[E0425]:
	"^%s*error%[[^%]]+%]:",
	-- TypeScript/JavaScript
	"^%s*error  TS%d+:",
	-- Go
	"^%s*# ",
	"^%s*.*: error:",
	-- 匹配以 warning: 开头的行
	"^%s*warning:",
	-- 匹配以 error: 开头的行
	"^%s*error:",
	"^%s*ERROR:",
	-- 匹配以 panic 相关的行
	"^%s*panic",
	-- 匹配测试失败标记
	"FAILED",
	"failures:",
}

-- 获取当前缓冲区中所有包含错误位置的行号
-- @param bufnr 缓冲区号，默认为当前缓冲区
-- @return 行号列表（按顺序排列）
function M.get_error_lines(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local error_lines = {}

	-- 遍历每一行，查找匹配正则表达式的行
	for line_num, line in ipairs(lines) do
		for _, pattern in ipairs(M.error_patterns) do
			if line:find(pattern) then
				table.insert(error_lines, line_num)
				break
			end
		end
	end

	return error_lines
end

-- 跳转到下一个错误位置
-- 在当前光标位置之后查找下一个错误行，如果没有则回到第一个
function M.next_error()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local error_lines = M.get_error_lines()

	if #error_lines == 0 then
		vim.notify("未找到错误位置", vim.log.levels.WARN)
		return
	end

	-- 查找当前行之后的下一个错误行
	local target = nil
	for _, line_num in ipairs(error_lines) do
		if line_num > current_line then
			target = line_num
			break
		end
	end

	-- 如果后面没有，则跳转到第一个
	if not target then
		target = error_lines[1]
	end

	-- 移动光标到目标行
	vim.api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd([[normal! zv]]) -- 展开折叠行，确保看到跳转位置
end

-- 跳转到上一个错误位置
-- 在当前光标位置之前查找上一个错误行，如果没有则回到最后一个
function M.prev_error()
	local current_line = vim.api.nvim_win_get_cursor(0)[1]
	local error_lines = M.get_error_lines()

	if #error_lines == 0 then
		vim.notify("未找到错误位置", vim.log.levels.WARN)
		return
	end

	-- 从后往前查找当前行之前的上一个错误行
	local target = nil
	for i = #error_lines, 1, -1 do
		if error_lines[i] < current_line then
			target = error_lines[i]
			break
		end
	end

	-- 如果前面没有，则跳转到最后一个
	if not target then
		target = error_lines[#error_lines]
	end

	-- 移动光标到目标行
	vim.api.nvim_win_set_cursor(0, { target, 0 })
	vim.cmd([[normal! zv]]) -- 展开折叠行，确保看到跳转位置
end

-- ============================
-- 支持 . 重复的错误跳转
-- ============================
-- 原理：通过 g@ 操作符让 Neovim 记住这个操作，
-- 按 . 时会重复执行 g@，从而再次调用回调函数执行相同的跳转

-- 保存最后一次跳转的方向
-- "next" 表示下一个错误，"prev" 表示上一个错误
local last_jump_direction = nil

-- 回调函数（供 operatorfunc 使用）
-- 这个函数会在 g@ 操作符执行时被调用
-- 根据保存的方向执行对应的跳转函数
function M._repeat_jump_callback()
	if last_jump_direction == "next" then
		M.next_error()
	elseif last_jump_direction == "prev" then
		M.prev_error()
	end
end

-- 包装后的 next_error（支持 . 重复）
-- 使用方法：通过 ]d 键触发，或直接调用此函数
function M.next_error_repeatable()
	last_jump_direction = "next" -- 记录跳转方向
	vim.o.operatorfunc = "v:lua.require'user.navigation'._repeat_jump_callback" -- 设置回调
	vim.api.nvim_feedkeys("g@l", "i", false) -- 触发操作符（范围是当前字符）
end

-- 包装后的 prev_error（支持 . 重复）
-- 使用方法：通过 [d 键触发，或直接调用此函数
function M.prev_error_repeatable()
	last_jump_direction = "prev" -- 记录跳转方向
	vim.o.operatorfunc = "v:lua.require'user.navigation'._repeat_jump_callback" -- 设置回调
	vim.api.nvim_feedkeys("g@l", "i", false) -- 触发操作符（范围是当前字符）
end

-- ============================
-- 命令分发器
-- ============================
-- 根据命令字符串执行对应操作
-- @param cmd 命令字符串或函数
-- 支持的命令：next_error, prev_error, next_error_repeatable, prev_error_repeatable, smart_close, 或任意 vim 命令
function M.dispatch_command(cmd)
	if cmd == "next_error" then
		M.next_error()
	elseif cmd == "prev_error" then
		M.prev_error()
	elseif cmd == "next_error_repeatable" then
		M.next_error_repeatable()
	elseif cmd == "prev_error_repeatable" then
		M.prev_error_repeatable()
	elseif cmd == "smart_close" then
		M.smart_close()
	elseif type(cmd) == "function" then
		cmd()
	else
		pcall(vim.cmd, cmd)
	end
end

-- ============================
-- 智能关闭窗口
-- ============================

-- 记录已关闭的窗口，防止重复关闭
local closed_windows = {}

-- 安全关闭窗口（带有效性检查）
local function safe_win_close(win, opts)
	if vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, opts or { force = true, noautocmd = true })
	end
end

-- 安全删除缓冲区（带有效性检查）
local function safe_buf_delete(buf, opts)
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, opts or { force = false })
	end
end

-- 智能关闭当前或指定窗口
-- 根据窗口类型（filetype/buftype）查找配置表中的关闭策略
-- @param target_win 目标窗口ID，默认为当前窗口
function M.smart_close(target_win)
	local win = target_win or vim.api.nvim_get_current_win()

	-- 防止重复关闭同一个窗口
	if closed_windows[win] then
		return
	end

	-- 窗口无效时直接标记并返回
	if not vim.api.nvim_win_is_valid(win) then
		closed_windows[win] = true
		return
	end

	-- 获取窗口相关信息
	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local name = vim.fn.bufname(buf)

	-- 查找关闭策略
	local close_map = M.buf_keymaps["q"]
	local strategy = nil

	-- dap-repl 特殊匹配（根据缓冲区名称）
	if name:match("dap%-repl") then
		strategy = close_map["dap-repl"]
	end

	-- 按 filetype 或 buftype 匹配策略
	strategy = strategy or close_map[ft] or close_map[bt]

	-- 标记窗口已关闭
	closed_windows[win] = true

	-- 如果找到策略，执行策略
	if strategy then
		M.dispatch_command(strategy.cmd)
		return
	end

	-- ============================
	-- fallback：智能关闭逻辑
	-- ============================

	local cfg = vim.api.nvim_win_get_config(win)

	-- 浮动窗口：直接关闭
	if cfg.relative ~= "" then
		safe_win_close(win, { force = false, noautocmd = true })
		return
	end

	-- 多窗口：直接关闭当前窗口
	if vim.fn.winnr("$") > 1 then
		safe_win_close(win)
		return
	end

	-- 只有一个窗口：尝试切换到其他缓冲区
	local buffers = vim.api.nvim_list_bufs()
	local buf_count = #buffers

	if buf_count > 1 then
		for _, other_buf in ipairs(buffers) do
			if other_buf ~= buf and vim.api.nvim_buf_is_loaded(other_buf) then
				vim.api.nvim_win_set_buf(win, other_buf)
				safe_buf_delete(buf)
				return
			end
		end
	end

	-- 最后一个缓冲区：询问是否退出 Neovim
	local choice = vim.fn.confirm("这是最后一个窗口，确认退出 Neovim？", "&是\n&否", 2)
	if choice == 1 then
		vim.cmd("qa")
	end
end

return M
