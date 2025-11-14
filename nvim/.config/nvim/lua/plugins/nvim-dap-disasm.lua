-- https://github.com/Jorenar/nvim-dap-disasm

return {
	"Jorenar/nvim-dap-disasm",
	dependencies = { "mfussenegger/nvim-dap", "rcarriga/nvim-dap-ui" },

	config = function()
		local disasm = require("dap-disasm")

		disasm.setup({
			-- 反汇编视图中当前行上方显示几条指令
			ins_before_memref = 10, -- 默认 20，这里适当减少性能更好

			-- 当前行下方显示几条指令
			ins_after_memref = 10,

			-- 反汇编窗口显示哪些列
			columns = {
				"address", -- 指令地址
				"instructionBytes", -- 指令机器码（十六进制)
				"instruction", -- 汇编指令
			},

			-- 使用 dap-ui 自动注册
			dapui_register = true,

			-- 如果你使用 nvim-dap-view，也可以开启
			dapview_register = true,

			-- 顶部显示当前指令信息
			winbar = {
				enabled = true,
				show_address = true,
			},

			-- REPL 中加入汇编命令 (si/ni)
			repl_commands = true,
		})

		-- 可选：给一个快捷键打开反汇编窗口
		vim.keymap.set("n", "<localleader>da", "<cmd>DapDisasm<cr>", { desc = "DAP: 打开反汇编窗口 (Disasm)" })
	end,
}
