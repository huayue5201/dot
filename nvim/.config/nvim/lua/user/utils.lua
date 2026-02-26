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
		["gitsigns-blame"] = { cmd = "bdelete!" },
		terminal = { cmd = "bdelete" },
		["nvim-undotree"] = { cmd = "close" },
		["vscode-diff-explorer"] = { cmd = "tabclose" },
		SymbolsSidebar = { cmd = "SymbolsClose" },
	},
}

-- ============================
-- ⭐统一关闭函数（核心）
-- ============================
function M.smart_close(target_win)
	local win = target_win or vim.api.nvim_get_current_win()
	if not vim.api.nvim_win_is_valid(win) then
		return
	end

	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	local bt = vim.bo[buf].buftype
	local name = vim.fn.bufname(buf)

	local close_map = M.buf_keymaps["q"]

	-- ① 特殊匹配 dap-repl
	local command
	if name:match("dap%-repl") then
		command = close_map["dap-repl"]
	end

	-- ② filetype / buftype 匹配
	command = command or close_map[ft] or close_map[bt]

	-- ③ fallback：SmartClose 行为
	if not command then
		local cfg = vim.api.nvim_win_get_config(win)

		-- 浮动窗口
		if cfg.relative ~= "" then
			vim.api.nvim_win_close(win, { force = false, noautocmd = true })
			return
		end

		-- 普通窗口
		if vim.fn.winnr("$") > 1 then
			vim.api.nvim_win_close(win, { force = true, noautocmd = true })
		else
			vim.cmd("bdelete " .. buf)
		end
		return
	end

	-- ④ 执行关闭命令
	if type(command.cmd) == "function" then
		command.cmd()
	else
		vim.cmd(command.cmd)
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
