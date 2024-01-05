-- https://github.com/altermo/ultimate-autopair.nvim

return {
	"altermo/ultimate-autopair.nvim",
	event = { "InsertEnter", "CmdlineEnter" },
	config = function()
		require("ultimate-autopair").setup({
			--Config goes here
		})
	end,
}
