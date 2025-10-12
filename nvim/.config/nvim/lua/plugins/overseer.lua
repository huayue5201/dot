-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	event = { "BufWritePre" },
	config = function()
		require("overseer").setup()
	end,
}
