-- https://github.com/j-hui/fidget.nvim

return {
	"j-hui/fidget.nvim",
	event = "LspAttach",
	config = function(_, opts)
		require("fidget").setup({})
	end,
}
