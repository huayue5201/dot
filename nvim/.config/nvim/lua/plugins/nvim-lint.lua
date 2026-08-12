-- https://github.com/mfussenegger/nvim-lint

return {
	"mfussenegger/nvim-lint",
	ft = { "lua" },
	config = function()
		require("lint").linters_by_ft = {
			lua = { "luacheck" },
		}
		-- 3. 自动触发 lint 的 autocmd
		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				-- 仅当缓冲区有对应的 linter 配置时才尝试 lint
				require("lint").try_lint()
			end,
		})
	end,
}
