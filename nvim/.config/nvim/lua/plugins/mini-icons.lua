-- https://github.com/echasnovski/mini.icons?tab=readme-ov-file#features

return {
	"echasnovski/mini.icons",
	lazy = true,
	config = function()
		require("mini.icons").setup()
		MiniIcons = MiniIcons.mock_nvim_web_devicons()
	end,
}
