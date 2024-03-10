-- https://github.com/mfussenegger/nvim-lint

return {
	"mfussenegger/nvim-lint", -- 使用 nvim-lint 插件
	event = { "BufReadPre", "BufNewFile" }, -- 在 BufReadPre 和 BufNewFile 事件触发时执行
	dependencies = {
		"williamboman/mason.nvim", -- 依赖于 mason.nvim 插件
	},
	config = function()
		-- 配置 lint 插件的 linters_by_ft 表，用于指定不同文件类型的 linter
		require("lint").linters_by_ft = {
			-- 在这里添加需要使用的 linters，例如：
			-- html = { "djlint" }, -- 使用 djlint 进行 HTML 文件的 lint
			-- json = { "jsonlint" }, -- 使用 jsonlint 进行 JSON 文件的 lint
		}

		-- 当保存 buffer 时自动运行 lint
		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	end,
}
