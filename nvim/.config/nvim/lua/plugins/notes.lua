-- https://github.com/huayue5201/notes.nvim
--
-- 极简「卡片盒」：把散落各处的文件（笔记库、日记目录、PDF、别的仓库）钉到当前
-- 项目上，用一棵 neo-tree 树聚拢展示。只记录路径 + 分组，不解析、不改写文件，
-- 也不往仓库里写任何东西。

return {
	dir = "~/neovim-plugins/notes.nvim",
	dependencies = { { dir = "~/neovim-plugins/nvim-store3" } },
	name = "notes",
	config = function()
		require("notes").setup()

		vim.keymap.set("n", "<leader>no", "<cmd>Note<CR>", { desc = "笔记: 打开项目锚点树" })
		vim.keymap.set("n", "<leader>na", "<cmd>Note anchor<CR>", { desc = "笔记: 锚定当前文件" })
		vim.keymap.set("n", "<leader>nu", "<cmd>Note unanchor<CR>", { desc = "笔记: 取消锚定" })
		vim.keymap.set("n", "<leader>nt", function()
			require("neo-tree.command").execute({ source = "notes", toggle = true })
		end, { desc = "笔记: 锚点树 (neo-tree)" })
	end,
}
