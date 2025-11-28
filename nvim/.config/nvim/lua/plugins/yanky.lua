-- 官方文档: https://github.com/gbprod/yanky.nvim#ringhistory_length

return {
	"gbprod/yanky.nvim",
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

		local function t(str)
			return vim.api.nvim_replace_termcodes(str, true, true, true)
		end

		-- Yank ring mappings
		local yanky_mappings = {
			-- Put actions
			["p"] = "<Plug>(YankyPutAfter)",
			["P"] = "<Plug>(YankyPutBefore)",
			["gp"] = "<Plug>(YankyGPutAfter)",
			["gP"] = "<Plug>(YankyGPutBefore)",

			-- Indent/Filter Put actions
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
		}

		-- Apply the mappings for normal mode and visual mode (where applicable)
		for key, putAction in pairs(yanky_mappings) do
			vim.keymap.set({ "n", "x" }, key, function()
				vim.fn.feedkeys(t(putAction))
			end, {
				desc = "Yanky: put " .. key,
			})
		end
	end,
}
