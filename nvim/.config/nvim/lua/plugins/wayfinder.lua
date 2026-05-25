-- https://github.com/error311/wayfinder.nvim

return {
	"error311/wayfinder.nvim",
	event = "VeryLazy",
	config = function()
		require("wayfinder").setup({
			performance = "fast",
			scope = {
				mode = "package",
				package_markers = {
					"package.json",
					"tsconfig.json",
					"pyproject.toml",
					"go.mod",
					"Cargo.toml",
					".git",
				},
			},
			limits = {
				refs = { max_results = 200, timeout_ms = 1200 },
				text = { enabled = true, max_results = 100, timeout_ms = 800 },
				tests = { max_results = 50, timeout_ms = 700 },
				git = { enabled = true, max_commits = 15, timeout_ms = 400 },
			},
		})
		vim.keymap.set("n", "grw", "<Plug>(WayfinderOpen)", { desc = "Wayfinder" })
		vim.keymap.set("n", "[w", "<Plug>(WayfinderTrailNext)", { desc = "Wayfinder Trail Next" })
		vim.keymap.set("n", "]w", "<Plug>(WayfinderTrailPrev)", { desc = "Wayfinder Trail Prev" })
		vim.keymap.set("n", "<leader>xwo", "<Plug>(WayfinderTrailOpen)", { desc = "Wayfinder Trail Open" })
		vim.keymap.set("n", "<leader>xws", "<Plug>(WayfinderTrailShow)", { desc = "Wayfinder Trail Show" })
	end,
}
