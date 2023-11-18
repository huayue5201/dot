-- https://github.com/numToStr/Comment.nvim

return {
	"numToStr/Comment.nvim",
	dependencies = {
		-- https://github.com/JoosepAlviste/nvim-ts-context-commentstring
		"JoosepAlviste/nvim-ts-context-commentstring",
	},
	keys = {
		"gcc",
		"gbc",
		"gcO",
		"gco",
		"gcA",
		{ "gc", "gb", mode = "v" },
	},
	config = function()
		require("Comment").setup({
			pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
		})
	end,
}
