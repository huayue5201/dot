-- https://igorlfs.github.io/nvim-dap-view/home
-- https://github.com/Jorenar/nvim-dap-disasm

return {
	"Jorenar/nvim-dap-disasm",
	dependencies = "igorlfs/nvim-dap-view",
	lazy = true,
	config = function()
		require("nvim-dap-disasm").setup({
			-- 将反汇编视图添加到 nvim-dap-ui 的元素中
			dapui_register = true,

			-- 将反汇编视图添加到 nvim-dap-view 中
			dapview_register = true,

			-- 如果已注册，将分区配置传递给 nvim-dap-view
			dapview = {
				keymap = "D",
				label = "Disassembly [D]",
				short_label = "󰒓 [D]",
			},

			-- 为逐指令级单步执行添加自定义 REPL 命令
			repl_commands = true,

			-- 在 winbar（窗口标题栏）中显示用于逐指令级调试的按钮
			-- 如果启用了 dapview 集成并安装了插件，该设置将被覆盖（禁用）
			winbar = true,

			-- 程序执行停止时用于标记当前指令的符号
			sign = "DapStopped",

			-- 在内存引用前显示的指令数量
			ins_before_memref = 16,

			-- 在内存引用后显示的指令数量
			ins_after_memref = 16,

			-- winbar（窗口标题栏）中按钮的标签
			controls = {
				step_into = "Step Into",
				step_over = "Step Over",
				step_back = "Step Back",
			},

			-- 在反汇编视图中显示的列
			columns = {
				"address", -- 地址
				"instructionBytes", -- 指令字节
				"instruction", -- 指令文本
			},
		})

		require("dap-view").setup({
			winbar = {
				sections = {
					"disassembly",
				},
			},
		})
	end,
}
