-- https://github.com/Jorenar/nvim-dap-disasm

return {
	"Jorenar/nvim-dap-disasm",
	-- dependencies = { "mfussenegger/nvim-dap", "rcarriga/nvim-dap-ui" },
	dependencies = "igorlfs/nvim-dap-view",
	event = "VeryLazy",
	config = function()
		local disasm = require("dap-disasm")

		disasm.setup({
			-- 反汇编视图中当前行上方显示几条指令
			ins_before_memref = 10, -- 默认 20，这里适当减少性能更好

			-- 当前行下方显示几条指令
			ins_after_memref = 10,

			-- 使用 dap-ui 自动注册
			-- dapui_register = true,

			-- 如果你使用 nvim-dap-view，也可以开启
			dapview_register = true,

			-- 显示窗口顶栏，提供指令级单步调试的按钮
			-- 如果启用了 dapview 集成且插件已安装，此设置将被覆盖（禁用）
			-- winbar = {
			-- 	enabled = true, -- 是否启用顶栏
			-- 	labels = { -- 按钮标签文字
			-- 		step_into = "Step Into", -- 单步进入（指令级）
			-- 		step_over = "Step Over", -- 单步跳过（指令级）
			-- 		step_back = "Step Back", -- 向后单步（指令级）
			-- 	},
			-- 	order = { -- 按钮显示顺序
			-- 		"step_into",
			-- 		"step_over",
			-- 		"step_back",
			-- 	},
			-- },
			--
			-- 用于标记当前执行指令位置的符号
			sign = "DapStopped",

			-- 反汇编视图中显示的列
			columns = {
				"address", -- 内存地址
				"instructionBytes", -- 指令字节码
				"instruction", -- 汇编指令
			},

			-- REPL 中加入汇编命令 (si/ni)
			repl_commands = true,
		})

		-- 可选：给一个快捷键打开反汇编窗口
		-- vim.keymap.set("n", "<localleader>dh", "<cmd>DapDisasm<cr>", { desc = "DAP: 打开反汇编窗口 (Disasm)" })
	end,
}
