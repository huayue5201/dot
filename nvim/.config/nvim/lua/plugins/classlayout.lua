-- https://github.com/J-Cowsert/classlayout.nvim

return {
	"J-Cowsert/classlayout.nvim",
	ft = { "c", "cpp" },
	config = function()
		require("classlayout").setup({
			keymap = "<leader>zc",
			compiler = "clang",
			args = {},
			compile_commands = true,
		})
	end,
}
