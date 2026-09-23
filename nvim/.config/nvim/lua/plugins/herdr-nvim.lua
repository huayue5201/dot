-- https://github.com/ChmaraX/herdr-nvim

return {
	"ChmaraX/herdr-nvim",
	config = function()
		require("herdr-nvim").setup({
			prefix = "<localleader>h", -- keymap prefix
			keymaps = true, -- set false to define your own
			clear_after_send = true, -- comments are ephemeral by design
		})
	end,
}
