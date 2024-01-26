-- https://github.com/norcalli/nvim-colorizer.lua

return {
	"norcalli/nvim-colorizer.lua",
	keys = {
		{ "<leader>oc", "<cmd>ColorizerToggle<CR>", desc = "显示css颜色" },
	},
	config = function()
		require("colorizer").setup()
	end,
}
