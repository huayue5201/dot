-- https://github.com/monaqa/dial.nvim?tab=readme-ov-file
-- TODO:https://github.com/monaqa/dial.nvim/pull/107

return {
	"monaqa/dial.nvim",
	event = "VeryLazy",
	dependencies = "nvim-lua/plenary.nvim",
	config = function()
		local augend = require("dial.augend")
		require("dial.config").augends:register_group({
			default = {
				augend.integer.alias.decimal,
				augend.integer.alias.hex,
				augend.integer.alias.binary,
				augend.date.alias["%Y/%m/%d"],
				augend.constant.alias.bool,
			},
		})

		vim.keymap.set("n", "<C-a>", function()
			require("dial.map").manipulate("increment", "normal")
		end, { desc = "Dial: increment" })

		vim.keymap.set("n", "<C-x>", function()
			require("dial.map").manipulate("decrement", "normal")
		end, { desc = "Dial: decrement" })

		vim.keymap.set("n", "g<C-a>", function()
			require("dial.map").manipulate("increment", "gnormal")
		end, { desc = "Dial: increment g" })

		vim.keymap.set("n", "g<C-x>", function()
			require("dial.map").manipulate("decrement", "gnormal")
		end, { desc = "Dial: decrement g" })

		vim.keymap.set("v", "<C-a>", function()
			require("dial.map").manipulate("increment", "visual")
		end, { desc = "Dial: increment visual" })

		vim.keymap.set("v", "<C-x>", function()
			require("dial.map").manipulate("decrement", "visual")
		end, { desc = "Dial: decrement visual" })

		vim.keymap.set("v", "g<C-a>", function()
			require("dial.map").manipulate("increment", "gvisual")
		end, { desc = "Dial: increment gvisual" })

		vim.keymap.set("v", "g<C-x>", function()
			require("dial.map").manipulate("decrement", "gvisual")
		end, { desc = "Dial: decrement gvisual" })
	end,
}
