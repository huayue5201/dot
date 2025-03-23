-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	cmd = { "OverseerRun", "OverseerToggle" },
	config = function()
		require("overseer").setup()
	end,
}
