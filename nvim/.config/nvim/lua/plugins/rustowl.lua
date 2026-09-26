-- https://github.com/cordx56/rustowl
-- RustOwl - 可视化 Rust 所有权和生命周期

return {
	"cordx56/rustowl",
	version = "*", -- Latest stable version
	-- build = "cargo install rustowl",
	lazy = false,
	config = function()
		local rustowl = require("rustowl")
		rustowl.setup({
			-- 自动附加 LSP 客户端（默认 true）
			auto_attach = true,
			-- 自动启用高亮（默认 false）
			-- 持续分析很吃 CPU，改为按需手动 toggle
			auto_enable = true,
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
	end,
}
