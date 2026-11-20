-- https://github.com/huayue5201/ui-menu.nvim
-- 贴光标的浮窗选择菜单，接管 vim.ui.select（:h ui-menu）。
-- 本地仓库就是远端仓库的工作区（改完提交/推送即同步，不需要 :Lazy sync）。
-- priority 必须早于其它插件的 config：有些插件会在 setup 阶段调 vim.ui.select。
-- 鼠标默认开（点行选中 / 滚轮移动 / 右键取消），高亮组 UiMenu* 全部 link 到
-- Pmenu/PmenuSel/FloatBorder/Title，跟随 colorscheme，不用在这里配色。
return {
	dir = "~/neovim-plugins/ui-menu.nvim",
	priority = 999,
	config = function()
		require("ui_menu").setup({ replace_select = true })
	end,
}
