-- https://github.com/mg979/vim-visual-multi/wiki/Mappings

return {
	"mg979/vim-visual-multi",
	keys = { "<c-n>" },
	config = function()
		-- vim.g.VM_theme = "iceblue" -- 设置 Visual Multi 插件的主题
		vim.g.VM_theme = "purplegray" -- 设置 Visual Multi 插件的主题
		vim.g.VM_mouse_mappings = 1 -- 启用鼠标支持
		vim.g.VM_maps["Undo"] = "u" -- 将 'u' 键映射为撤销操作（Undo）。
		vim.g.VM_maps["Redo"] = "<C-r>" -- 将 'Ctrl + r' 映射为重做操作（Redo）。
		vim.g.VM_default_mappings = 0 -- 禁用插件的默认快捷键，以便自定义。
		vim.g.VM_maps["Select Cursor Down"] = "<M-C-Down>" -- 使用 Alt + Ctrl + 下箭头来选择下一个光标。
		vim.g.VM_maps["Select Cursor Up"] = "<M-C-Up>" -- 使用 Alt + Ctrl + 上箭头来选择上一个光标。
		vim.g.VM_maps["Erase Regions"] = "\\gr" -- 使用 \\gr 快捷键来清除选中的光标区域。
	end,
}
