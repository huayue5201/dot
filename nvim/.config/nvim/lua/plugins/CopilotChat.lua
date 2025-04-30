-- https://github.com/CopilotC-Nvim/CopilotChat.nvim

return {
	"CopilotC-Nvim/CopilotChat.nvim",
	cmd = { "CopilotChatToggle", "CopilotChatExplain" },
	keys = {
		{ "<leader>ac", desc = "CopilotChat" },
	},
	dependencies = {
		{ "zbirenbaum/copilot.lua" },
		{ "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
	},
	build = "make tiktoken", -- Only on MacOS or Linux
	config = function()
		require("CopilotChat").setup({
			window = {
				layout = "float", -- "float" or "horizontal" or "vertical"
				relative = "cursor",
			},
			-- 插件初始化配置
		})
		vim.keymap.set("n", "<leader>ac", "<cmd>CopilotChatToggle<cr>", { desc = "CopilotChat" })
	end,
}
