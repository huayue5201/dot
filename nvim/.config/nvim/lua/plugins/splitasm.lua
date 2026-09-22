-- https://github.com/NickTsaizer/splitasm.nvim

return {
	"NickTsaizer/splitasm.nvim",
	cmd = {
		"SplitAsm",
		"SplitAsmOpen",
		"SplitAsmSetup",
		"SplitAsmConfig",
		"SplitAsmToggleSync",
	},
	event = "VeryLazy",
	config = function()
		require("splitasm").setup()
		vim.keymap.set("n", "<Leader>zs", "<cmd>SplitAsmOpen<cr>", { desc = "splitasm: 查看汇编" })
	end,
}
