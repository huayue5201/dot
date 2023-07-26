-- https://github.com/nvimdev/guard.nvim

return {
	"nvimdev/guard.nvim",
	cmd = "GuardFmt",
	config = function()
		local ft = require("guard.filetype")
		-- use stylua to format lua files and no linter
		ft("lua"):fmt("stylua")

		-- call setup LAST
		require("guard").setup({
			-- the only option for the setup function
			fmt_on_save = true,
		})
	end,
}
