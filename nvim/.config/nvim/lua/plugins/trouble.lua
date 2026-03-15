-- https://github.com/folke/trouble.nvim

return {
	"folke/trouble.nvim",
	event = "VeryLazy",
	cmd = "Trouble",
	config = function()
		require("trouble").setup({
			modes = {
				test = {
					mode = "diagnostics",
					preview = {
						type = "split",
						relative = "win",
						position = "right",
						size = 0.3,
					},
				},
			},
		})

		-- 设置快捷键
		local keymap = vim.keymap.set
		local opts = { noremap = true, silent = true }

		keymap("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", opts)
		keymap("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", opts)
		keymap("n", "<leader>xf", "<cmd>Trouble symbols toggle focus=false win.size=48<cr>", opts)
		keymap("n", "<leader>xF", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", opts)
		keymap("n", "<leader>xi", "<cmd>Trouble lsp_incoming_calls<cr>", opts)
		keymap("n", "<leader>xo", "<cmd>Trouble lsp_outgoing_calls<cr>", opts)

		-- 为快捷键添加描述（可选，需要 which-key 插件支持）
		if pcall(require, "which-key") then
			local wk = require("which-key")
			wk.add({
				{ "<leader>x", group = "Trouble" },
				{ "<leader>xx", desc = "诊断信息" },
				{ "<leader>xX", desc = "当前缓冲区诊断" },
				{ "<leader>xf", desc = "符号列表" },
				{ "<leader>xF", desc = "LSP 定义/引用/..." },
				{ "<leader>xi", desc = "LSP 被调用位置" },
				{ "<leader>xo", desc = "LSP 调用位置" },
			})
		end
	end,
}
