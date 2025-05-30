-- https://ravitemer.github.io/mcphub.nvim/installation.htmlZZ

return {
	"ravitemer/mcphub.nvim",
	lazy = true,
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	build = "npm install -g mcp-hub@latest", -- Installs `mcp-hub` node binary globally
	config = function()
		require("mcphub").setup()
	end,
}
