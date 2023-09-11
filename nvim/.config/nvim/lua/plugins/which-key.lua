-- https://github.com/folke/which-key.nvim

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	opts = {
		marks = true, -- shows a list of your marks on ' and `
		key_labels = {
			-- override the label used to display some keys. It doesn't effect WK in any other way.
			-- For example:
			["<space>"] = "SPC",
			["<cr>"] = "RET",
			["<tab>"] = "TAB",
		},
		window = {
			border = "double", -- none, single, double, shadow
		},
		layout = {
			height = { min = 4, max = 25 }, -- min and max height of the columns
			width = { min = 20, max = 50 }, -- min and max width of the columns
			spacing = 3, -- spacing between columns
			align = "center", -- align columns left, center or right
		},
	},
}
