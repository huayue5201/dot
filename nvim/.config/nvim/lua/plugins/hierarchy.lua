-- https://github.com/lafarr/hierarchy.nvim

return {
	"lafarr/hierarchy.nvim",
	event = "LspAttach",
	lazy = true,
	config = function()
		local opts = {
			-- Determines how many levels deep the call hierarchy shows
			depth = 3,
		}
		require("hierarchy").setup(opts)

		vim.keymap.set("n", "grf", "<cmd>FunctionReferences<cr>", { desc = "查看函数调用结构" })
	end,
}
