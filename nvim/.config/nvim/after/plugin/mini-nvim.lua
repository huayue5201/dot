-- https://github.com/echasnovski/mini.icons?tab=readme-ov-file#features

vim.g.later(function()
	vim.g.add("echasnovski/mini.icons")
	vim.g.add({ source = "echasnovski/mini.bufremove" })

	require("mini.icons").setup()
	MiniIcons = MiniIcons.mock_nvim_web_devicons()
end)
