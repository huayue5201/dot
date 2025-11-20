-- https://github.com/ahkohd/buffer-sticks.nvim

return {
	"ahkohd/buffer-sticks.nvim",
	event = "VeryLazy",
	keys = {
		{
			"gb",
			function()
				BufferSticks.jump()
			end,
			desc = "Jump to buffer",
		},
		{
			"<leader>rb",
			function()
				BufferSticks.list({ action = "close" })
			end,
			desc = "Close buffer",
		},
		-- {
		-- 	"<leader>p",
		-- 	function()
		-- 		BufferSticks.list({
		-- 			action = function(buffer, leave)
		-- 				print("Selected: " .. buffer.name)
		-- 				leave()
		-- 			end
		-- 		})
		-- 	end,
		-- 	desc = "Buffer picker",
		-- },
	},
	config = function()
		local sticks = require("buffer-sticks")
		sticks.setup({
			filter = { buftypes = { "terminal" } },
			preview = {
				enabled = false, -- Enable buffer preview during navigation
				mode = "float", -- Preview mode: "float", "current", or "last_window"
				float = {
					position = "right", -- Float position: "right", "left", or "below"
					width = 0.5, -- Width as fraction of screen (0.0 to 1.0)
					height = 0.8, -- Height as fraction of screen (0.0 to 1.0)
					border = "single", -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
					title = nil, -- Window title: nil/true = filename, false = no title, "string" = custom (default: nil/filename)
					title_pos = "center", -- Title position: "left", "center", "right"
					footer = nil, -- Window footer (string or nil)
					footer_pos = "center", -- Footer position: "left", "center", "right"
				},
			},
			highlights = {
				active = { link = "Statement" },
				alternate = { link = "StorageClass" },
				inactive = { link = "Whitespace" },
				active_modified = { link = "Constant" },
				alternate_modified = { link = "Constant" },
				inactive_modified = { link = "Constant" },
				label = { link = "Comment" },
				filter_selected = { link = "Statement" },
				filter_title = { link = "Comment" },
				list_selected = { link = "Statement" },
			},
		})
		sticks.show()
	end,
}
