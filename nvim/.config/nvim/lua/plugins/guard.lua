-- https://github.com/nvimdev/guard.nvim
-- WARN: 需依赖外部程序(MACOS:brew install ...)

return {
	"nvimdev/guard.nvim",
	keys = {
		{ ";F", mode = { "n", "v" }, "<cmd>GuardFmt<cr>", desc = "格式代码" },
	},
	config = function()
		local ft = require("guard.filetype")

		-- lua格式化程序
		ft("lua"):fmt("stylua")

		require("guard").setup({
			-- 格式化的时候保存文件
			fmt_on_save = true,
			-- Use lsp if no formatter was defined for this filetype
			lsp_as_default_formatter = true,
		})
	end,
}
