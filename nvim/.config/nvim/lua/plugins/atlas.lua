-- https://github.com/emrearmagan/atlas.nvim

return ---@module "atlas"
{
	"emrearmagan/atlas.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons", -- optional but recommended
		"MeanderingProgrammer/render-markdown.nvim", -- optional but recommended
		"esmuellert/codediff.nvim", -- optional (PullRequest diff)
	},
	-- See Configuration below
	---@type AtlasConfig
	opts = {},
	config = function()
		local actions = require("atlas.pulls.actions")

		keymaps = {
			pulls = {
				custom = {
					{
						key = "gP",
						desc = "Open pipelines",
						callback = function(context, done)
							actions.run("open_pipelines", context, done)
						end,
					},
				},
			},
			issues = {
				custom = {
					{
						key = "<leader>as",
						desc = "Atlas search",
						callback = function()
							vim.cmd("Atlas search")
						end,
					},
				},
			},
		}
	end,
}
