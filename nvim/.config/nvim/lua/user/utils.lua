local M = {}

M.settings = {
	["dap-repl"] = {
		setup = function()
			-- 仅在当前 buffer 中禁用保存确认提示
			vim.opt_local.confirm = false
		end,
	},
}

-- ============================
-- 关闭策略表（你原来的）
-- ============================
M.buf_keymaps = {
	["q"] = {
		help = { cmd = "quit" },
		man = { cmd = "quit" },
		msgmore = { cmd = "quit" },
		FunctionReferences = { cmd = "quit" },
		checkhealth = { cmd = "close" },
		better_term = { cmd = "close" },
		["grug-far"] = { cmd = "bdelete" },
		git = { cmd = "bdelete" },
		["dap-repl"] = { cmd = "close" },
		["dap-float"] = { cmd = "close" },
		["dap-view-term"] = { cmd = "close" },
		["dap-view"] = { cmd = "DapViewClose" },
		["gitsigns-blame"] = { cmd = "bdelete!" },
		terminal = { cmd = "bdelete" },
		["nvim-undotree"] = { cmd = "close" },
		["vscode-diff-explorer"] = { cmd = "tabclose" },
		OverseerOutput = { cmd = "close" },
	},
}

-- ============================
-- 单文件版：更优雅、更可维护的 smart_close
-- ============================

local closed_windows = {}

local function safe_win_close(win, opts)
	if vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, opts or { force = true, noautocmd = true })
	end
end

local function safe_buf_delete(buf, opts)
	if vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, opts or { force = false })
	end
end

function M.smart_close(target_win)
	local win = target_win or vim.api.nvim_get_current_win()

	-- ① 防重复关闭
	if closed_windows[win] then
		return
	end

	-- ② 无效窗口直接标记并返回
	if not vim.api.nvim_win_is_valid(win) then
		closed_windows[win] = true
		return
	end

	-- ③ 获取 buffer 信息
	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local name = vim.fn.bufname(buf)

	-- ④ 查找关闭策略
	local close_map = M.buf_keymaps["q"]
	local strategy = nil

	-- dap-repl 特殊匹配
	if name:match("dap%-repl") then
		strategy = close_map["dap-repl"]
	end

	-- filetype / buftype 匹配
	strategy = strategy or close_map[ft] or close_map[bt]

	-- ⭐标记窗口已关闭（避免 WinClosed → 再次调用）
	closed_windows[win] = true

	-- ⑤ 如果有策略，执行策略
	if strategy then
		if type(strategy.cmd) == "function" then
			pcall(strategy.cmd)
		else
			pcall(vim.cmd, strategy.cmd)
		end
		return
	end

	-- ⑥ fallback：智能关闭逻辑
	local cfg = vim.api.nvim_win_get_config(win)

	-- 浮动窗口
	if cfg.relative ~= "" then
		safe_win_close(win, { force = false, noautocmd = true })
		return
	end

	-- 多窗口：直接关闭
	if vim.fn.winnr("$") > 1 then
		safe_win_close(win)
		return
	end

	-- 只有一个窗口：处理 buffer 切换
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

	-- 最后一个缓冲区：询问是否退出
	local choice = vim.fn.confirm("这是最后一个窗口，确认退出 Neovim？", "&是\n&否", 2)
	if choice == 1 then
		vim.cmd("qa")
	end
end

M.palette = {
	-- 基础颜色
	bg = "#1e1e2e", -- 背景色
	fg = "#cdd6f4", -- 前景色（文字颜色）

	-- 常用基础色
	red = "#f38ba8", -- 红色，用于错误
	green = "#a6e3a1", -- 绿色，用于成功、通过
	green3 = "#00CD00",
	blue = "#89b4fa", -- 蓝色，用于信息
	yellow = "#f9e2af", -- 黄色，用于警告
	magenta = "#f5c2e7", -- 洋红，用于强调
	cyan = "#94e2d5", -- 青色，用于提示
	gray = "#6c7086", -- 灰色
	darkgray = "#45475a", -- 深灰色

	-- 语义颜色（用于诊断等场景）
	error = "#f38ba8", -- 错误
	warning = "#f9e2af", -- 警告
	info = "#89dceb", -- 信息
	hint = "#74c7ec", -- 提示
}

return M
