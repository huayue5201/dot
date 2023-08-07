-- https://github.com/cbochs/grapple.nvim

return {
	"cbochs/grapple.nvim",
	keys = {
		{ "<leader>a", "<cmd>GrappleToggle<cr>", desc = "标记文件" },
		{ "<leader>k", "<cmd>GrapplePopup tags<cr>", desc = "标记列表" },
		{ "<leader>tp", "<cmd>GrapplePopup scopes<cr>", desc = "标记列表" },
	},
	dependencies = { "nvim-lua/plenary.nvim" },
	opts = {},
}
