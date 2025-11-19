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

		-- normal/visual: Yank
		vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)", {
			desc = "Yanky: yank",
		})

		-- ring history
		vim.keymap.set("n", "<leader>yl", "<cmd>YankyRingHistory<cr>", {
			silent = true,
			desc = "Yanky: ring history",
		})

		-- prev/next entry
		vim.keymap.set("n", "<c-p>", "<Plug>(YankyPreviousEntry)", {
			desc = "Yanky: previous entry",
		})
		vim.keymap.set("n", "<c-n>", "<Plug>(YankyNextEntry)", {
			desc = "Yanky: next entry",
		})

		local Hydra = require("hydra")

		local function t(str)
			return vim.api.nvim_replace_termcodes(str, true, true, true)
		end

		-- Yank ring hydra
		local yanky_hydra = Hydra({
			name = "Yank ring",
			mode = "n",
			heads = {
				{ "p", "<Plug>(YankyPutAfter)", { desc = "Put after" } },
				{ "P", "<Plug>(YankyPutBefore)", { desc = "Put before" } },
			},
		})

		-- put actions
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
				desc = "Yanky: put " .. key,
			})
		end

		-- indent/filter put actions
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
				desc = "Yanky: put (indent/filter) " .. key,
			})
		end
	end,
}
