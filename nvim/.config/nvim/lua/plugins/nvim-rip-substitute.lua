-- https://github.com/chrisgrieser/nvim-rip-substitute?tab=readme-ov-file

return {
	"chrisgrieser/nvim-rip-substitute",
	cmd = "RipSubstitute",
	keys = {
		{
			"<leader>fs",
			function()
				require("rip-substitute").sub()
			end,
			mode = { "n", "x" },
			desc = " rip substitute",
		},
	},
}
