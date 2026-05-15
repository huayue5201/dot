-- https://github.com/BinL233/agent-tally.nvim

return {
	"BinL233/agent-tally.nvim",
	event = "VeryLazy",
	config = function()
		require("agent-tally").setup({
			-- 后台守护进程的可执行文件路径（默认："agent-tallyd"）
			daemon_bin = "agent-tallyd",

			-- UNIX 套接字路径，必须与守护进程的 --socket 参数保持一致
			socket_path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/agent-tally.sock",

			-- PID 文件路径，用于防止启动多个守护进程实例
			pid_file = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/agent-tally.pid",

			-- 是否在 Neovim 启动时自动启动守护进程（默认：false）
			auto_start = false,

			-- 状态栏格式（%t = 总 token 数，%p = 进程名称）
			statusline_format = " [AT: %t tokens]",

			-- 查询限制
			query = {
				events_limit = 500, -- 每次打开仪表板时加载的最大事件数量
				skills_limit = 50, -- 为"按技能分类"部分获取的最大技能行数
			},

			-- UI 界面选项
			ui = {
				width = 0.8, -- 宽度为编辑器宽度的 80%
				height = 0.8, -- 高度为编辑器高度的 80%
				border = "rounded", -- 边框样式（圆角边框）
			},

			-- 仪表板快捷键映射
			keymaps = {
				close = { "q", "<Esc>" }, -- 关闭仪表板
				drill_down = "<CR>", -- 进入下一级（向下钻取）
				back = "<BS>", -- 返回上一级
				next_entry = "<C-j>", -- 下一个条目
				prev_entry = "<C-k>", -- 上一个条目
				grep = "G", -- 搜索/过滤
				refresh = "r", -- 刷新数据
				heatmap = "H", -- 生成热力图（范围 → 代理 → 指标）
			},
		})
	end,
}
