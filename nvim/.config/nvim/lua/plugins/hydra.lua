-- https://github.com/anuvyklack/hydra.nvim

return {
	"anuvyklack/hydra.nvim",
	event = "VeryLazy",
	config = function()
		local Hydra = require("hydra")

		Hydra({
			name = "Side scroll",
			mode = "n",
			body = "z",
			heads = {
				{ "h", "5zh" },
				{ "l", "5zl", { desc = "←/→" } },
				{ "H", "zH" },
				{ "L", "zL", { desc = "half screen ←/→" } },
			},
		})
	end,
}
