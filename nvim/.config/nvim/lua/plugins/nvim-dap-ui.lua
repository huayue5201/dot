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

		---@diagnostic disable: missing-fields
		dapui.setup({
			expand_lines = true, -- 当当前行内容过长时，是否自动展开到悬停窗口
			-- force_buffers = true, -- 防止其他缓冲区加载到 dap-ui 的专属窗口
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
