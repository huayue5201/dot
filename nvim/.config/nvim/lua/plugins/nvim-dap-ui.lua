-- https://github.com/rcarriga/nvim-dap-ui

return {
	"rcarriga/nvim-dap-ui",
	lazy = true,
	dependencies = {
		"mfussenegger/nvim-dap", -- 核心调试插件[citation:2]
		"nvim-neotest/nvim-nio", -- 新增的必需依赖[citation:1]
	},
	config = function()
		-- 关键初始化步骤[citation:5]
		local dapui = require("dapui")
		dapui.setup({
			icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
			mappings = {
				expand = { "<CR>", "<2-LeftMouse>" },
				open = "o",
				remove = "d",
				edit = "e",
				repl = "r",
				toggle = "t",
			},
			expand_lines = vim.fn.has("nvim-0.7") == 1,
			layouts = {
				{
					elements = {
						{ id = "scopes", size = 0.25 },
						"breakpoints",
						"stacks",
						"watches",
					},
					size = 40, -- 40 columns wide
					position = "left",
				},
				{
					elements = {
						"repl",
						"console",
					},
					size = 0.25, -- 25% of total lines
					position = "bottom",
				},
			},
			controls = {
				enabled = true,
				element = "repl",
				icons = {
					pause = "⏸",
					play = "▶",
					step_into = "⏎",
					step_over = "⏭",
					step_out = "⏮",
					run_last = "↻",
					terminate = "⏹",
				},
			},
			floating = {
				max_height = nil,
				max_width = nil,
				border = "single",
				mappings = {
					close = { "q", "<Esc>" },
				},
			},
			windows = { indent = 1 },
			render = {
				max_type_length = nil,
				max_value_lines = 100,
			},
		})

		vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "DAP UI: Toggle" })
		vim.keymap.set("n", "<leader>df", dapui.float_element, { desc = "DAP UI: Float element" })
		vim.keymap.set("n", "<leader>de", dapui.eval, { desc = "DAP UI: Eval under cursor" })
		vim.keymap.set("v", "<leader>de", dapui.eval, { desc = "DAP UI: Eval selection" })
		vim.keymap.set("n", "<leader>dE", function()
			dapui.eval(vim.fn.input("Expression: "))
		end, { desc = "DAP UI: Eval input expression" })
	end,
}
