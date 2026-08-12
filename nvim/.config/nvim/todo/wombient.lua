-- https://github.com/wom/wombient

return {
	"wom/wombient",
	config = function()
		require("wombient").setup({
			stripe = {
				enabled = true,
			},
		})
	end,
}
