-- https://github.com/otavioschwanck/arrow.nvim

return {
	"otavioschwanck/arrow.nvim",
	keys = { ";", "," },
	config = function()
		require("arrow").setup({
			show_icons = true,
			leader_key = ";", -- Recommended to be a single key
			buffer_leader_key = ",", -- Per Buffer Mappings
		})
		vim.keymap.set("n", "<C-h>", require("arrow.persist").previous)
		vim.keymap.set("n", "<C-l>", require("arrow.persist").next)
		vim.keymap.set({ "i", "n" }, "<C-a>", require("arrow.persist").toggle)
	end,
}
