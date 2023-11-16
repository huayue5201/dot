-- https://github.com/altermo/ultimate-autopair.nvim

return {
	"altermo/ultimate-autopair.nvim",
	event = { "InsertEnter", "CmdlineEnter" },
	branch = "v0.6", --recomended as each new version will have breaking changes
	config = function()
		require("ultimate-autopair").setup({
			--Config goes here
		})
	end,
}
