-- https://github.com/chrisgrieser/nvim-rip-substitute

return {
	"chrisgrieser/nvim-rip-substitute",
	cmd = "RipSubstitute",
	opts = {},
	keys = {
		{
			"<leader>gb",
			function()
				require("rip-substitute").sub()
			end,
			mode = { "n", "x" },
			desc = " rip substitute",
		},
	},
}
