-- https://github.com/rcarriga/nvim-dap-ui

return {
	"rcarriga/nvim-dap-ui",
	lazy = true,
	dependencies = {
		"mfussenegger/nvim-dap", -- 核心调试插件[citation:2]
		"nvim-neotest/nvim-nio", -- 新增的必需依赖[citation:1]
	},
	config = function()
		-- 导入 nvim-dap-ui 模块
		local dapui = require("dapui")

		-- 调用 setup() 函数进行配置，这是插件工作的必需步骤[citation:10]
		dapui.setup({
			element_mappings = {},
			-- =====================
			-- 1. 图标设置
			-- =====================
			icons = {
				expanded = "", -- 已展开元素的图标
				collapsed = "", -- 已折叠元素的图标
				current_frame = "", -- 当前栈帧的指示图标
			},

			-- =====================
			-- 2. 元素内键盘映射
			-- 这些快捷键在调试窗口（如作用域、监视窗口）内生效
			-- =====================
			mappings = {
				expand = { "<CR>", "<2-LeftMouse>" }, -- 展开/折叠项：回车或双击
				open = "o", -- 打开项目（如跳转到代码）
				remove = "d", -- 删除项目（如删除监视表达式）
				edit = "e", -- 编辑项目（如修改变量值）
				repl = "r", -- 将项目发送到 REPL
				toggle = "t", -- 切换项目状态（如启用/禁用断点）
			},

			-- =====================
			-- 3. 布局定义
			-- 这是核心部分，决定调试窗口的位置、大小和包含的元素[citation:4]
			-- =====================
			layouts = {
				{
					-- 第一个布局：放置在编辑器左侧
					elements = {
						-- 元素可以是字符串，也可以是带有 `id` 和 `size` 键的表
						-- `size` 可以是具体数值（如40列），也可以是比例（0-1之间）
						{ id = "scopes", size = 0.25 }, -- 变量作用域
						{ id = "breakpoints", size = 0.25 }, -- 断点列表
						{ id = "stacks", size = 0.25 }, -- 线程与调用栈
						{ id = "watches", size = 0.25 }, -- 监视表达式
					},
					size = 40, -- 布局宽度为 40 列
					position = "left", -- 位置在左侧
				},
				{
					-- 第二个布局：放置在编辑器底部
					elements = {
						"repl", -- 调试控制台 (Read-Eval-Print Loop)
						"console", -- 程序输出/终端
					},
					size = 10, -- 布局高度为 10 行
					position = "bottom", -- 位置在底部
				},
			},

			-- =====================
			-- 4. 浮动窗口配置
			-- 设置临时弹出窗口（如用 `:lua require("dapui").float_element()` 打开）的外观和行为
			-- =====================
			floating = {
				max_height = nil, -- 最大高度（数值，或0-1的比例）。nil表示自适应。
				max_width = nil, -- 最大宽度（数值，或0-1的比例）。nil表示自适应。
				border = "rounded", -- 边框样式，可选 "single"、"double"、"rounded" 等
				mappings = {
					close = { "q", "<Esc>" }, -- 关闭浮动窗口的快捷键
				},
			},

			-- =====================
			-- 5. 调试控制栏设置
			-- 在指定元素（如REPL）上方显示调试按钮（暂停、继续、单步等）
			-- =====================
			controls = {
				enabled = true, -- 启用控制栏
				element = "repl", -- 控制栏附着在哪个元素上，通常是 "repl"
				icons = {
					pause = "",
					play = "",
					step_into = "",
					step_over = "",
					step_out = "",
					step_back = "",
					run_last = "",
					terminate = "",
				},
			},

			-- =====================
			-- 6. 渲染与样式选项
			-- 控制调试信息在窗口中的显示方式
			-- =====================
			render = {
				indent = 1, -- 嵌套变量渲染时的缩进空格数
				max_value_lines = 100, -- 单个值最多显示的行数，防止超长数据刷屏
			},

			-- =====================
			-- 7. 其他杂项配置
			-- =====================
			expand_lines = true, -- 当当前行内容过长时，是否自动展开到悬停窗口
			force_buffers = true, -- 防止其他缓冲区加载到 dap-ui 的专属窗口
		})

		vim.keymap.set({ "n", "x" }, "<M-k>", "<Cmd>lua require('dapui').eval()<CR>")
		vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "DAP UI: Toggle" })
		vim.keymap.set("n", "<leader>df", dapui.float_element, { desc = "DAP UI: Float element" })
		vim.keymap.set("n", "<leader>de", dapui.eval, { desc = "DAP UI: Eval under cursor" })
		vim.keymap.set("v", "<leader>de", dapui.eval, { desc = "DAP UI: Eval selection" })
		vim.keymap.set("n", "<leader>dE", function()
			dapui.eval(vim.fn.input("Expression: "))
		end, { desc = "DAP UI: Eval input expression" })
	end,
}
