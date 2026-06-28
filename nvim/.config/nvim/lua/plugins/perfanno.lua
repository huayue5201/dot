-- https://github.com/t-troebst/perfanno.nvim/blob/master/doc/perfanno.txt

return {
	"t-troebst/perfanno.nvim",
	event = "VeryLazy",
	config = function()
		local perfanno = require("perfanno")
		local util = require("perfanno.util")

		perfanno.setup({
			-- 用于高亮热代码行的高亮列表（设为 nil 可禁用）
			line_highlights = require("perfanno.util").make_bg_highlights(nil, "#FF0000", 10),
			-- 用于虚拟文本注释的高亮（设为 nil 可禁用虚拟文本）
			vt_highlight = require("perfanno.util").make_fg_highlight("#FF0000"),

			-- 可通过 :PerfCycleFormat 循环切换的注释格式
			--   "percent" 控制显示百分比还是绝对计数
			--   "format" 是用于显示计数/百分比的格式字符串
			--   "minimum" 低于此值的行将不显示注释
			-- 注意：这也会影响 telescope 查找器中显示的内容
			formats = {
				{ percent = true, format = "%.2f%%", minimum = 0.5 },
				{ percent = false, format = "%d", minimum = 1 },
			},

			-- 在执行 :PerfLoadFlat 和 :PerfLoadCallGraph 后自动注释文件
			annotate_after_load = true,
			-- 如果有可用信息，自动注释新打开的缓冲区
			annotate_on_open = true,

			-- 基于 telescope 的热点行查找器选项
			telescope = {
				-- 如果可能则启用，否则回退到 fzf-lua 或 vim.ui.select
				enabled = pcall(require, "telescope"),
				-- 在预览窗口中显示注释
				annotate = false,
			},

			-- 基于 fzf-lua 的热点行查找器选项
			fzf_lua = {
				-- 如果可能则启用，否则回退到 vim.ui.select
				enabled = pcall(require, "fzf-lua"),
				-- 在预览窗口中显示注释
				annotate = false,
			},

			-- 用于查找光标所在函数的节点类型模式
			ts_function_patterns = {
				-- 这些应该适用于大多数语言（至少是常与 perf 一起使用的语言）
				default = {
					"function",
					"method",
				},
				-- 你也可以为特定语言添加模式，例如：
				-- weirdlang = {
				--     "weirdfunc",
				-- }
			},

			-- 覆盖默认的 perf.data 路径提示行为，使用自定义函数返回 perf 文件路径字符串
			get_path_callback = nil,

			-- 为多线程应用启用每线程性能分析支持
			-- 启用后，加载 perf.data 时可以选择要分析哪些线程
			thread_support = false,
		})

		-- 使用 vim.keymap.set 替代 nvim_set_keymap，以支持 desc 字段
		local opts = { noremap = true, silent = true }

		-- 加载数据
		vim.keymap.set(
			"n",
			"<LEADER>oplf",
			":PerfLoadFlat<CR>",
			vim.tbl_extend("force", opts, { desc = "加载 perf.data（无调用图）" })
		)
		vim.keymap.set(
			"n",
			"<LEADER>oplg",
			":PerfLoadCallGraph<CR>",
			vim.tbl_extend("force", opts, { desc = "加载 perf.data（带调用图）" })
		)
		vim.keymap.set(
			"n",
			"<LEADER>oplo",
			":PerfLoadFlameGraph<CR>",
			vim.tbl_extend("force", opts, { desc = "加载火焰图数据" })
		)

		-- 事件选择
		vim.keymap.set(
			"n",
			"<LEADER>ope",
			":PerfPickEvent<CR>",
			vim.tbl_extend("force", opts, { desc = "选择要显示的事件" })
		)

		-- 注释相关
		vim.keymap.set(
			"n",
			"<LEADER>opa",
			":PerfAnnotate<CR>",
			vim.tbl_extend("force", opts, { desc = "注释当前缓冲区" })
		)
		vim.keymap.set(
			"n",
			"<LEADER>opf",
			":PerfAnnotateFunction<CR>",
			vim.tbl_extend("force", opts, { desc = "注释当前函数" })
		)
		vim.keymap.set(
			"v",
			"<LEADER>opa",
			":PerfAnnotateSelection<CR>",
			vim.tbl_extend("force", opts, { desc = "注释选中的区域" })
		)

		-- 切换注释
		vim.keymap.set(
			"n",
			"<LEADER>opt",
			":PerfToggleAnnotations<CR>",
			vim.tbl_extend("force", opts, { desc = "切换注释显示" })
		)

		-- 查找热点
		vim.keymap.set(
			"n",
			"<LEADER>oph",
			":PerfHottestLines<CR>",
			vim.tbl_extend("force", opts, { desc = "查找最热的代码行" })
		)
		vim.keymap.set(
			"n",
			"<LEADER>ops",
			":PerfHottestSymbols<CR>",
			vim.tbl_extend("force", opts, { desc = "查找最热的函数" })
		)
		vim.keymap.set(
			"n",
			"<LEADER>opc",
			":PerfHottestCallersFunction<CR>",
			vim.tbl_extend("force", opts, { desc = "查找当前函数的调用者" })
		)
		vim.keymap.set(
			"v",
			"<LEADER>opc",
			":PerfHottestCallersSelection<CR>",
			vim.tbl_extend("force", opts, { desc = "查找选中区域的调用者" })
		)
	end,
}
