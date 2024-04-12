-- https://github.com/jinh0/eyeliner.nvim

return {
	"jinh0/eyeliner.nvim",
	keys = { "f", "F", "t", "T" },
	config = function()
		require("eyeliner").setup({
			highlight_on_key = true, -- show highlights only after keypress
			dim = false, -- dim all other characters if set to true (recommended!)
		})
	end,
}
