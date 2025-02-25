-- https://github.com/oxfist/night-owl.nvim

vim.g.now(function()
	vim.g.add({ source = "oxfist/night-owl.nvim" })
	-- vim.g.add({ source = "dgox16/oldworld.nvim" })

	require("night-owl").setup()
	vim.cmd.colorscheme("night-owl")
	-- vim.cmd.colorscheme("oldworld")
end)
