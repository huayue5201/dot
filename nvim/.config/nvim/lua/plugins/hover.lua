-- https://github.com/lewis6991/hover.nvim
-- 统一的上下文感知 hover 框架：K 一个键，按 enabled + priority 自动选 provider。
-- 调试会话激活时 DAP provider（priority 1002）自动接管 K，
-- 因此无需再像以前那样在 event_initialized/event_terminated 里保存/删除/恢复 K 映射。

return {
	"lewis6991/hover.nvim",
	event = "VeryLazy",
	config = function()
		require("hover").config({
			providers = {
				"todo2.hover", -- priority 1005：任务上优先显示 todo2 任务信息
				"hover.providers.dap", -- priority 1002：调试时接管 K
				"hover.providers.diagnostic", -- priority 1001
				"hover.providers.lsp", -- priority 1000
				"hover.providers.man",
				"hover.providers.dictionary",
			},
			preview_opts = {
				border = "rounded",
			},
			title = true,
		})

		vim.keymap.set("n", "K", function()
			require("hover").open()
		end, { desc = "hover.nvim (open)" })

		vim.keymap.set("n", "gK", function()
			require("hover").enter()
		end, { desc = "hover.nvim (enter)" })

		vim.keymap.set("n", "<C-p>", function()
			require("hover").switch("previous")
		end, { desc = "hover.nvim (previous source)" })

		vim.keymap.set("n", "<C-n>", function()
			require("hover").switch("next")
		end, { desc = "hover.nvim (next source)" })
	end,
}
