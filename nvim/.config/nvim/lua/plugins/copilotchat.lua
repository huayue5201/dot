-- https://github.com/CopilotC-Nvim/CopilotChat.nvim

return {
	"CopilotC-Nvim/CopilotChat.nvim",
	event = "UIEnter",
	dependencies = {
		{ "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
		{ "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
	},
	build = "make tiktoken", -- Only on MacOS or Linux
	config = function()
		require("CopilotChat").setup({
			-- See Configuration section for options
		})
	end,
}
