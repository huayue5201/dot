-- https://github.com/danymat/neogen
-- TODO:备选:https://github.com/jeangiraldoo/codedocs.nvim

return {
	"jeangiraldoo/codedocs.nvim",
	config = function()
		require("codedocs").setup({
			-- 调试模式（日常使用时关闭）
			debug = false,

			-- 语言配置
			languages = {
				-- Python 使用 Google 风格（可选：reST, NumPy）
				python = {
					default_style = "Google",
				},
				-- Lua 使用 EmmyLua 风格
				lua = {
					default_style = "EmmyLua",
				},
				-- JavaScript 使用 JSDoc
				javascript = {
					default_style = "JSDoc",
				},
				-- TypeScript 使用 TSDoc
				typescript = {
					default_style = "TSDoc",
				},
				-- Go 使用 Godoc
				go = {
					default_style = "Godoc",
				},
				-- Rust 使用 RustDoc
				rust = {
					default_style = "RustDoc",
				},
				-- Java 使用 JavaDoc
				java = {
					default_style = "JavaDoc",
				},
				-- C/C++ 使用 Doxygen
				c = {
					default_style = "Doxygen",
				},
				cpp = {
					default_style = "Doxygen",
				},
			},

			-- 文件类型别名（例如 .sh 文件使用 bash 配置）
			aliases = {
				sh = "bash",
				zsh = "bash",
				["c++"] = "cpp",
			},
		})

		-- 键位绑定
		local opts = { noremap = true, silent = true, desc = "Generate documentation" }
		-- 自动检测类型并生成注释
		vim.keymap.set("n", "gC", "<cmd>Codedocs<CR>", opts)

		-- 也可以分类型绑定（如果需要）
		vim.keymap.set("n", "gcF", "<cmd>Codedocs func<CR>", { desc = "Generate function comment" })
		vim.keymap.set("n", "gcC", "<cmd>Codedocs class<CR>", { desc = "Generate class comment" })
	end,
}
