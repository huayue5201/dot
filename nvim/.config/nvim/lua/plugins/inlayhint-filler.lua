-- https://github.com/Davidyz/inlayhint-filler.nvim

return {
	"Davidyz/inlayhint-filler.nvim",
	keys = {
		{
			"<Leader>I", -- Use whatever keymap you want.
			function()
				require("inlayhint-filler").fill()
			end,
			desc = "Insert the inlay-hint under cursor into the buffer.",
			mode = { "n", "v" }, -- include 'v' if you want to use it in visual selection mode
		},
	},
}
