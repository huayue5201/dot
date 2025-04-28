-- https://github.com/mbbill/undotree

return {
	"mbbill/undotree",
	keys = "<leader>eu",
	config = function()
		vim.g.undotree_WindowLayout = 2 -- UI布局
		vim.g.undotree_SplitWidth = 45 -- 窗口大小
		vim.g.undotree_SetFocusWhenToggle = 1 -- 自动聚焦光标
		vim.keymap.set("n", "<leader>eu", vim.cmd.UndotreeToggle)
	end,
}
