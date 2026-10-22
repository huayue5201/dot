-- https://github.com/cordx56/rustowl
-- RustOwl - 可视化 Rust 所有权和生命周期

return {
	"cordx56/rustowl",
	sem_version = "*", -- Latest stable version
	-- build = "cargo install rustowl",
	-- 插件本身启动即加载，但不主动起客户端（auto_attach=false）：客户端由下面
	-- config 里注册的三个键按需 lsp.start()，避免意外拉起 cargo check --all-targets。
	config = function()
		local rustowl = require("rustowl")
		rustowl.setup({
			-- 不自动 attach：RustOwl 持续分析很吃 CPU，改成按需手动起客户端。
			-- 代价是 on_attach 里挂键位永远等不到，所以下面用全局键位当入口。
			auto_attach = false,
			-- 必须 false：插件 ftplugin/rust.lua:99 里 auto_enable 会挂一个全局
			-- LspAttach → show-on-hover.enable() → lsp.start()，等于每次 rust-analyzer
			-- attach 都拉起 rustowl 二进制并跑 rustowl/analyze（这就是它会自己跑
			-- cargo check 的原因）。高亮入口已由下面三个键代替。
			auto_enable = false,
			-- 悬停等待时间（毫秒），默认 500
			idle_time = 500,
			-- ============================================================
			-- 高亮样式：'underline'（直线）或 'undercurl'（波浪线）
			-- ============================================================
			highlight_style = "undercurl",
			-- ============================================================
			-- 自定义颜色（可选）
			-- ============================================================
			-- colors = {
			-- 	lifetime = "#00cc00", -- 🟩 绿色：变量生命周期
			-- 	imm_borrow = "#c2e1f8", -- 🟦 蓝色：不可变借用
			-- 	mut_borrow = "#6891f3", -- 🟪 紫色：可变借用
			-- 	move = "#cccc00", -- 🟧 黄色：值移动
			-- 	call = "#cccc00", -- 🟧 黄色：函数调用
			-- 	outlive = "#cc0000", -- 🟥 红色：生命周期错误
			-- },
		})

		-- 加载器是 eager 的：插件 rtp 在任何 rust buffer 触发 FileType 之前就已就位，
		-- ftplugin/rust.lua 会被 nvim 正常 source，不需要手动补。

		-- 全局入口：首次按下会自己 lsp.start() 并把客户端 attach 到当前 buffer。
		-- 传显式 bufnr（不传 buf 会导致 enable 的 autocmd 变成“所有 buffer”）。
		local function rustowl_action(method)
			return function()
				if vim.bo.filetype ~= "rust" then
					vim.notify("RustOwl: 只在 rust buffer 里生效", vim.log.levels.WARN)
					return
				end
				if vim.fn.executable("rustowl") == 0 then
					vim.notify("RustOwl: 找不到 rustowl 可执行文件（cargo install rustowl）", vim.log.levels.ERROR)
					return
				end
				require("rustowl")[method](vim.api.nvim_get_current_buf())
			end
		end

		vim.keymap.set(
			"n",
			"<localleader>rt",
			rustowl_action("toggle"),
			{ desc = "RustOwl: toggle" }
		)
		vim.keymap.set(
			"n",
			"<localleader>re",
			rustowl_action("enable"),
			{ desc = "RustOwl: enable" }
		)
		vim.keymap.set(
			"n",
			"<localleader>rd",
			rustowl_action("disable"),
			{ desc = "RustOwl: disable" }
		)
	end,
}
