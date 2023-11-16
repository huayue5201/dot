-- https://github.com/mfussenegger/nvim-lint

return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("lint").linters_by_ft = {
			-- https://github.com/Riverside-Healthcare/djLint
			html = { "djlint" },
			-- https://github.com/zaach/jsonlint
			json = { "jsonlint" },
		}
		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	end,
}
