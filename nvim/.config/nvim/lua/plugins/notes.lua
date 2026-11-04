-- https://github.com/huayue5201/notes.nvim
--
-- 极简笔记：md 文件都在 ~/notes，项目笔记按项目身份绑到
-- ~/notes/projects/<slug>--<hash8>/；不往仓库里写任何东西。
-- 只负责「项目绑定」与「捕获」，文件管理交给 neo-tree。

return {
	dir = "~/neovim-plugins/notes.nvim",
	dependencies = { { dir = "~/neovim-plugins/nvim-store3" } },
	name = "notes",
	config = function()
		require("notes").setup()

		vim.keymap.set("n", "<leader>No", "<cmd>Note<CR>", { desc = "笔记: 打开项目笔记" })
		vim.keymap.set("n", "<leader>Nn", "<cmd>Note new<CR>", { desc = "笔记: 新建" })
		vim.keymap.set("n", "<leader>Na", "<cmd>Note all<CR>", { desc = "笔记: 全部笔记" })
		vim.keymap.set({ "n", "x" }, "<leader>Nf", "<cmd>Note from<CR>", { desc = "笔记: 捕获选区到项目笔记" })
		vim.keymap.set("n", "<leader>Nt", function()
			require("neo-tree.command").execute({ source = "notes", toggle = true })
		end, { desc = "笔记: 笔记树 (neo-tree)" })
	end,
}
