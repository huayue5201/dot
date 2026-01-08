-- https://github.com/serhez/bento.nvim

return {
	"serhez/bento.nvim",
	event = "BufWinEnter",
	config = function()
		require("bento").setup({
			main_keymap = "<tab>", -- Main toggle/expand key
			actions = {
				git_stage = {
					key = "g",
					hl = "DiffAdd", -- Optional: custom label color
					action = function(buf_id, buf_name)
						vim.cmd("!git add " .. vim.fn.shellescape(buf_name))
					end,
				},
			},
		})
	end,
}
