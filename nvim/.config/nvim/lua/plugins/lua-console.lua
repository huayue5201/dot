-- https://github.com/YaroSpace/lua-console.nvim

return {
	"YaroSpace/lua-console.nvim",
	lazy = true,
	keys = {
		{ "`", desc = "Lua 控制台 (toggle)" },
		{ "<Leader>`", desc = "Lua 控制台 (attach 到 buffer)" },
	},
	opts = {
		buffer = {
			result_prefix = "=> ", -- 执行结果前缀
			save_path = vim.fn.stdpath("state") .. "/lua-console-session.lua",
			autosave = true, -- 隐藏/关闭时自动保存会话
			load_on_start = true, -- 启动时加载之前的会话
			preserve_context = true, -- 保留上下文（变量等）在不同执行之间
			strip_local = true, -- 执行时去掉 `local` 声明（顶层）
			show_one_line_results = true, -- 即使有多行结果，也尝试一行显示
			notify_result = false, -- 是否弹出通知来显示执行结果
			clear_before_eval = false, -- 每次 buffer 整体 eval 前清除旧结果
			process_timeout = 2 * 1e5, -- 执行超时 (指令条数)
		},
		window = {
			border = "double", -- 窗口边框风格（可选 single / rounded / double 等）
			height = 0.6, -- 控制台高度占窗口比例
		},
		mappings = {
			toggle = "`", -- 切换 Lua 控制台
			attach = "<Leader>`", -- 将控制台附加到当前 buffer (buffer 模式)
			quit = "q", -- 关闭控制台
			eval = "<CR>", -- 执行当前行表达式或语句
			eval_buffer = "<S-CR>", -- 执行整个 buffer
			kill_ps = "<Leader>K", -- 杀掉执行进程 (如果有长运行)
			open = "gf", -- 打开（例如错误堆栈中的链接或来源）
			messages = "M", -- 加载 Neovim 消息到控制台
			save = "S", -- 保存控制台会话
			load = "L", -- 加载之前保存的会话
			resize_up = "<C-Up>", -- 向上扩展控制台高度
			resize_down = "<C-Down>", -- 向下缩小控制台
			help = "?", -- 显示帮助
		},
	},
}
