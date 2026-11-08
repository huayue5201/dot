-- https://github.com/nullromo/cash.nvim

return {
	"nullromo/cash.nvim",
	opts = {}, -- specify options here
	config = function(_, opts)
		local cash = require("cash")
		cash.setup(opts)
		vim.keymap.set("n", "<c-/>", "<cmd>Cash<cr>", { silent = true, desc = "Cash: 搜索寄存器" })
	end,
}
