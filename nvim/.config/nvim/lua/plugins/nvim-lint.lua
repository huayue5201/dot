-- https://github.com/mfussenegger/nvim-lint

return {
	"mfussenegger/nvim-lint",
	event = "BufReadPost",
	config = function()
		require("lint").linters_by_ft = {
			makefile = { "checkmake" },
		}

		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	end,
}
