-- https://github.com/serhez/bento.nvim

return {
	"serhez/bento.nvim",
	opts = {},
	config = function()
		require("bento").setup({
			main_keymap = "<S-tab>", -- Main toggle/expand key
			actions = {
				git_stage = {
					key = "g",
					hl = "DiffAdd", -- Optional: custom label color
					action = function(buf_id, buf_name)
						vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
					end,
				},
				-- Copy path
				copy_path = {
					key = "y",
					action = function(_, buf_name)
						vim.fn.setreg("+", buf_name)
					end,
				},
			},
		})
	end,
}
