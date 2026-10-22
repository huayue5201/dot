-- https://github.com/propilideno/buffer-preview.nvim

return {
	"propilideno/buffer-preview.nvim",
	dependencies = {
		"3rd/image.nvim", -- only needed for image preview (PDF / presentation)
	},
	config = function()
		require("buffer-preview").setup({
			-- "pdftoppm" (default) or "pdftocairo"
			rasterizer = "pdftoppm",
			-- Rasterization DPI (higher = sharper but slower)
			dpi = 200,
			-- Where rendered page PNGs are cached
			cache_dir = vim.fn.stdpath("cache") .. "/buffer-preview.nvim",
		})
	end,
}
