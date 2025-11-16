-- 官方文档: https://github.com/gbprod/yanky.nvim#ringhistory_length

return {
	"gbprod/yanky.nvim",
	dependencies = { "nvimtools/hydra.nvim" },
	event = "VeryLazy",
	config = function()
		require("yanky").setup({
			ring = {
				storage = "shada",
			},
			preserve_cursor_position = {
				enabled = true,
			},
			highlight = {
				on_put = true,
				on_yank = true,
				timer = 500,
			},
		})

		-- 普通/可视模式 y → Yanky yank
		vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)", {
			desc = "Yank using Yanky",
		})

		-- 打开 yank 历史
		vim.keymap.set("n", "<leader>yl", "<cmd>YankyRingHistory<cr>", {
			silent = true,
			desc = "打开 Yank 历史列表",
		})

		-- 上/下一条记录
		vim.keymap.set("n", "<c-p>", "<Plug>(YankyPreviousEntry)", {
			desc = "上一条 yank 记录",
		})
		vim.keymap.set("n", "<c-n>", "<Plug>(YankyNextEntry)", {
			desc = "下一条 yank 记录",
		})

		local Hydra = require("hydra")

		local function t(str)
			return vim.api.nvim_replace_termcodes(str, true, true, true)
		end

		-- Hydra: yank ring
		local yanky_hydra = Hydra({
			name = "Yank ring",
			mode = "n",
			heads = {
				{ "p", "<Plug>(YankyPutAfter)", { desc = "Put After" } },
				{ "P", "<Plug>(YankyPutBefore)", { desc = "Put Before" } },
			},
		})

		-- put 系列
		for key, putAction in pairs({
			["p"] = "<Plug>(YankyPutAfter)",
			["P"] = "<Plug>(YankyPutBefore)",
			["gp"] = "<Plug>(YankyGPutAfter)",
			["gP"] = "<Plug>(YankyGPutBefore)",
		}) do
			vim.keymap.set({ "n", "x" }, key, function()
				vim.fn.feedkeys(t(putAction))
				yanky_hydra:activate()
			end, {
				desc = "Yanky put: " .. key,
			})
		end

		-- indent + filter put 系列
		for key, putAction in pairs({
			["]p"] = "<Plug>(YankyPutIndentAfterLinewise)",
			["[p"] = "<Plug>(YankyPutIndentBeforeLinewise)",
			["]P"] = "<Plug>(YankyPutIndentAfterLinewise)",
			["[P"] = "<Plug>(YankyPutIndentBeforeLinewise)",

			[">p"] = "<Plug>(YankyPutIndentAfterShiftRight)",
			["<p"] = "<Plug>(YankyPutIndentAfterShiftLeft)",
			[">P"] = "<Plug>(YankyPutIndentBeforeShiftRight)",
			["<P"] = "<Plug>(YankyPutIndentBeforeShiftLeft)",

			["=p"] = "<Plug>(YankyPutAfterFilter)",
			["=P"] = "<Plug>(YankyPutBeforeFilter)",
		}) do
			vim.keymap.set("n", key, function()
				vim.fn.feedkeys(t(putAction))
				yanky_hydra:activate()
			end, {
				desc = "Yanky put (indent/filter): " .. key,
			})
		end
	end,
}
