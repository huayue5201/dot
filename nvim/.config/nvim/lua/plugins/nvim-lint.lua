-- https://github.com/mfussenegger/nvim-lint

return {
	"mfussenegger/nvim-lint",
	ft = { "make", "json" },
	config = function()
		require("lint").linters_by_ft = {
			make = "checkmake",
			json = "jsonlint",
		}

		vim.api.nvim_create_autocmd({ "InsertLeave" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	end,
}
