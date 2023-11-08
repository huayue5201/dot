-- https://github.com/gennaro-tedesco/nvim-possession

return {
	"gennaro-tedesco/nvim-possession",
	dependencies = {
		"ibhagwan/fzf-lua",
	},
	config = true,
	init = function()
		local possession = require("nvim-possession")
		vim.keymap.set("n", "<leader>wl", function()
			possession.list()
		end, { desc = "查看会话" })
		vim.keymap.set("n", "<leader>wn", function()
			possession.new()
		end, { desc = "添加会话" })
		vim.keymap.set("n", "<leader>wu", function()
			possession.update()
		end, { desc = "更新会话" })
		vim.keymap.set("n", "<leader>wd", function()
			possession.delete()
		end, { desc = "删除会话" })
	end,
}
