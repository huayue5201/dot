-- https://github.com/numToStr/Comment.nvim

return {
	"numToStr/Comment.nvim",
	dependencies = {
		-- https://github.com/JoosepAlviste/nvim-ts-context-commentstring
		"JoosepAlviste/nvim-ts-context-commentstring",
	},
	keys = {
		{ "gcc", desc = "行注释" },
		{ "gbc", desc = "块注释" },
		{ "gcO", desc = "添加注释(上)" },
		{ "gco", desc = "添加注释(下)" },
		{ "gcA", desc = "添加注释(后)" },
		{ "gc", mode = "v", desc = "行注释" },
		{ "gb", mode = "v", desc = "块注释" },
	},
	config = function()
		require("Comment").setup({
			pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
		})
	end,
}
