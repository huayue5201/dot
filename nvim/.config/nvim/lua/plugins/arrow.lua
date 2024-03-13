-- https://github.com/otavioschwanck/arrow.nvim

return {
	"otavioschwanck/arrow.nvim",
	keys = { ";", { "<leader>aa", desc = "添加标记" } },
	config = function()
		require("arrow").setup({
			show_icons = true,
			leader_key = ";", -- Recommended to be a single key
			separate_by_branch = true,
		})
		vim.keymap.set("n", "<leader>aa", require("arrow.persist").toggle)
	end,
}
