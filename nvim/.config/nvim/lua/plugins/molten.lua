-- https://github.com/benlubas/molten-nvim?tab=readme-ov-file

return {
	"benlubas/molten-nvim",
	build = ":UpdateRemotePlugins",
	ft = { "python" },
	dependencies = { "3rd/image.nvim" },
	init = function()
		-- these are examples, not defaults. Please see the readme
		vim.g.molten_image_provider = "image.nvim"
		vim.g.molten_output_win_max_height = 20
	end,
}
