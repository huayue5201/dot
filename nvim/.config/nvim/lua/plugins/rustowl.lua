-- https://github.com/cordx56/rustowl
-- RustOwl - 可视化 Rust 所有权和生命周期

return {
	"cordx56/rustowl",
	sem_version = "*", -- Latest stable version
	-- build = "cargo install rustowl",
	-- 懒加载：只在按下下面三个键时才加载插件 + 起 rustowl 客户端。
	-- 之前 lazy=false 会让它随 nvim 启动就初始化，并容易意外拉起 cargo check --all-targets。
	lazy = true,
	keys = { "<leader>rtR", "<localleader>re", "<localleader>rd" },
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

		-- 全局入口：首次按下会自己 lsp.start() 并把客户端 attach 到当前 buffer。
		-- 传显式 bufnr（不传 buf 会导致 enable 的 autocmd 变成“所有 buffer”）。
		local function rustowl_action(method, desc)
			return function()
				if vim.bo.filetype ~= "rust" then
					vim.notify("RustOwl: 只在 rust buffer 里生效", vim.log.levels.WARN)
					return
				end
				require("rustowl")[method](vim.api.nvim_get_current_buf())
			end
		end

		vim.keymap.set("n", "<leader>rtR", rustowl_action("toggle", "RustOwl: 开关"), { desc = "RustOwl: toggle" })
		vim.keymap.set("n", "<localleader>re", rustowl_action("enable", "RustOwl: 启用"), { desc = "RustOwl: enable" })
		vim.keymap.set("n", "<localleader>rd", rustowl_action("disable", "RustOwl: 禁用"), { desc = "RustOwl: disable" })
	end,
}
