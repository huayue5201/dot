-- https://github.com/williamboman/mason.nvim

return {
	"williamboman/mason.nvim",
	event = "VeryLazy",
	cmd = {
		"Mason",
		"MasonUpdate",
		"MasonInstall",
		"MasonUninstall",
	},
	config = function()
		require("mason").setup()
	end,
}
