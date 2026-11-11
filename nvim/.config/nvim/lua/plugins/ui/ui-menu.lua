-- https://github.com/huayue5201/ui-menu.nvim
-- 贴光标的浮窗选择菜单，接管 vim.ui.select（:h ui-menu）。
-- priority 必须早于其它插件的 config：有些插件会在 setup 阶段调 vim.ui.select。
return {
	dir = "~/neovim-plugins/ui-menu.nvim",
	priority = 999,
	config = function()
		require("ui_menu").setup({ replace_select = true })
	end,
}
