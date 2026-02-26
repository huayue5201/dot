-- https://github.com/huayue5201/todo2/tree/main/lua/todo2

return {
	dir = "~/todo2",
	"huayue5201/todo2",
	dev = true,
	-- event = "VeryLazy", -- 延迟加载，保证启动速度
	lazy = true,
	dependencies = { "nvim-store3" },
	name = "todo2",
	config = function()
		require("todo2").setup({
			ui = {
				conceal = {
					enable = true,
				},
			},
		})
		vim.keymap.set("n", "<C-k>", "<cmd>SmartPreview<cr>", { desc = "todo预览" })
	end,
}
