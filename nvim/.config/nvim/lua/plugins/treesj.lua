-- https://github.com/Wansmer/treesj

return {
	"Wansmer/treesj",
	event = "VeryLazy",
	dependencies = { "nvim-treesitter/nvim-treesitter" }, -- if you install parsers with `nvim-treesitter`
	config = function()
		require("treesj").setup({--[[ your config ]]
		})
		vim.keymap.set("n", "<c-j>", require("treesj").toggle)
		-- For extending default preset with `recursive = true`
		vim.keymap.set("n", "<s-c-j>", function()
			require("treesj").toggle({ split = { recursive = true } })
		end)
	end,
}
