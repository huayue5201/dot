-- https://github.com/williamboman/mason.nvim

return {
	"williamboman/mason.nvim",
	build = ":MasonUpdate", -- :MasonUpdate updates registry contents
	opts = {
		ui = { border = "double" },
	},
}
