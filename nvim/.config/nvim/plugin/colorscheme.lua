-- https://github.com/oxfist/night-owl.nvim

vim.g.now(function()
	vim.g.add({ source = "oxfist/night-owl.nvim" })

	require("night-owl").setup()
	vim.cmd.colorscheme("night-owl")
end)
