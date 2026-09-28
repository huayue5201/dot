-- https://github.com/t-troebst/perfanno.nvim
-- perf 性能分析注解：把 perf / flamegraph 采样结果直接标注在源码行上

return {
	"t-troebst/perfanno.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-treesitter/nvim-treesitter", -- :PerfAnnotateFunction / :PerfHottestCallersFunction 依赖
	},
	config = function()
		local perfanno = require("perfanno")
		local util = require("perfanno.util")

		perfanno.setup({
			-- 行高亮：主题背景色 -> 橙红的 10 级渐变（采样越多越红）
			line_highlights = util.make_bg_highlights(nil, "#CC3300", 10),
			vt_highlight = util.make_fg_highlight("#CC3300"),

			-- 加载数据后自动注解 / 打开 buffer 时自动注解
			annotate_after_load = true,
			annotate_on_open = true,
		})

		-- 加载 profiling 数据
		vim.keymap.set("n", "<leader>plf", "<cmd>PerfLoadFlat<CR>", { desc = "PerfAnno: 加载 flat 数据" })
		vim.keymap.set("n", "<leader>plg", "<cmd>PerfLoadCallGraph<CR>", { desc = "PerfAnno: 加载 callgraph 数据" })
		vim.keymap.set("n", "<leader>plo", "<cmd>PerfLoadFlameGraph<CR>", { desc = "PerfAnno: 加载 flamegraph 数据" })

		-- 事件 / 注解
		vim.keymap.set("n", "<leader>pe", "<cmd>PerfPickEvent<CR>", { desc = "PerfAnno: 切换采样事件" })
		vim.keymap.set("n", "<leader>pa", "<cmd>PerfAnnotate<CR>", { desc = "PerfAnno: 注解当前文件" })
		vim.keymap.set("n", "<leader>pf", "<cmd>PerfAnnotateFunction<CR>", { desc = "PerfAnno: 注解当前函数" })
		vim.keymap.set("n", "<leader>pt", "<cmd>PerfToggleAnnotations<CR>", { desc = "PerfAnno: 切换注解显示" })

		-- 热点查找
		vim.keymap.set("n", "<leader>ph", "<cmd>PerfHottestLines<CR>", { desc = "PerfAnno: 最热代码行" })
		vim.keymap.set("n", "<leader>ps", "<cmd>PerfHottestSymbols<CR>", { desc = "PerfAnno: 最热符号" })
		vim.keymap.set("n", "<leader>pc", "<cmd>PerfHottestCallersFunction<CR>", { desc = "PerfAnno: 当前函数最热调用者" })

		-- 选中区域相关命令带 range，用 ex 模式（自动带上 '<,'> 范围）
		vim.keymap.set("v", "<leader>pa", ":PerfAnnotateSelection<CR>", { desc = "PerfAnno: 注解选中区域" })
		vim.keymap.set("v", "<leader>pc", ":PerfHottestCallersSelection<CR>", { desc = "PerfAnno: 选中区域最热调用者" })
	end,
}
