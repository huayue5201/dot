-- https://github.com/jose-elias-alvarez/null-ls.nvim

return {
	"jose-elias-alvarez/null-ls.nvim",
	config = function()
		local null_ls = require("null-ls")
		-- 格式化sources
		local formatting = null_ls.builtins.formatting
		-- 诊断sources
		local diagnostics = null_ls.builtins.diagnostics
		-- code补全searches
		local completion = null_ls.builtins.completion
		-- 悬停文档sources
		local hover = null_ls.builtins.hover
		-- code actions sources
		local code_actions = null_ls.builtins.code_actions

		-- sources
		local sources = {
			-- https://github.com/dprint/dprint
			-- 格式化框架
			formatting.dprint,
			-- https://github.com/JohnnyMorganz/StyLua
			formatting.stylua,
		}

		-- 注册sources
		null_ls.setup({ sources = sources })
	end,
}

-- sources列表
-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md
-- sources设置
-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTIN_CONFIG.md
