---@diagnostic disable: missing-fields
-- https://github.com/georgeguimaraes/review.nvim

return {
	"georgeguimaraes/review.nvim",
	dependencies = {
		"esmuellert/codediff.nvim",
	},
	cmd = { "Review" },
	keys = {
		{ "<leader>hcr", "<cmd>Review<cr>", desc = "Review" },
		{ "<leader>hcR", "<cmd>Review commits<cr>", desc = "Review commits" },
	},
	config = function()
		require("review").setup({
			comment_types = {
				note = { key = "n", name = "Note", icon = "📝", hl = "ReviewNote" },
				suggestion = { key = "s", name = "Suggestion", icon = "💡", hl = "ReviewSuggestion" },
				issue = { key = "i", name = "Issue", icon = "⚠️", hl = "ReviewIssue" },
				praise = { key = "p", name = "Praise", icon = "✨", hl = "ReviewPraise" },
			},
			keymaps = {
				add_note = "<leader>hcn",
				add_suggestion = "<leader>hcs",
				add_issue = "<leader>hci",
				add_praise = "<leader>hcp",
				delete_comment = "<leader>hcd",
				edit_comment = "<leader>hce",
				next_comment = "]n",
				prev_comment = "[n",
			},
			export = {
				context_lines = 3,
				include_file_stats = true,
			},
			codediff = {
				readonly = true,
			},
		})
	end,
}
