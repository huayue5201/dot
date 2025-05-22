-- https://github.com/atiladefreitas/dooing

return {
	"atiladefreitas/dooing",
	keys = { "<leader>td", desc = "todo任务" },
	config = function()
		require("dooing").setup({
			-- your custom config here (optional)
		})
		vim.keymap.set("n", "<Leader>td", "<cmd>Dooing<cr>", { desc = "todo任务" })
	end,
}
