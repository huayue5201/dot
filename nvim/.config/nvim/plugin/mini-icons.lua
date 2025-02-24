-- https://github.com/echasnovski/mini.icons?tab=readme-ov-file#features

vim.g.now(function()
	vim.g.add("echasnovski/mini.icons")

	require("mini.icons").setup()
	MiniIcons.mock_nvim_web_devicons()
end)
