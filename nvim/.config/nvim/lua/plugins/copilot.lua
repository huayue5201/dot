-- https://github.com/zbirenbaum/copilot.lua
-- cmd:Copilot setup

return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	-- event = "InsertEnter",
	lazy = true,
	keys = {
		{ "<leader>ap", desc = "Copilot Panel" },
		{ "<leader>at", desc = "Copilot Suggestion" },
	},
	config = function()
		require("copilot").setup({
			panel = {
				enabled = true,
				auto_refresh = false,
				keymap = {
					jump_prev = "[[",
					jump_next = "]]",
					accept = "<CR>",
					refresh = "gr",
					open = "<M-CR>",
				},
				layout = {
					position = "bottom", -- | top | left | right | horizontal | vertical
					ratio = 0.4,
				},
			},
			suggestion = {
				enabled = true,
				auto_trigger = false,
				hide_during_completion = true,
				debounce = 75,
				trigger_on_accept = true,
				keymap = {
					accept = "<M-p>",
					accept_word = "<M-w>",
					accept_line = "<M-l>",
					next = "<M-]>",
					prev = "<M-[>",
					dismiss = "<C-]>",
				},
			},
		})

		vim.keymap.set("n", "<leader>ap", function()
			require("copilot.panel").toggle()
		end, { desc = "Copilot Panel" })

		vim.keymap.set("n", "<leader>toc", function()
			require("copilot.suggestion").toggle_auto_trigger()
		end, { desc = "Copilot Suggestion" })

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuOpen",
			callback = function()
				vim.b.copilot_suggestion_hidden = true
			end,
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuClose",
			callback = function()
				vim.b.copilot_suggestion_hidden = false
			end,
		})
	end,
}
