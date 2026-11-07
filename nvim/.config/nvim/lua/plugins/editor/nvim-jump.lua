-- https://github.com/yorickpeterse/nvim-jump
-- 极简跳转插件（<200 行），替代 flash.nvim。
-- 只有 jump 一个动作：输入若干字符缩小匹配 → 按标签跳转。
-- 无 treesitter / remote / search 模式（这些是 flash 独有功能，不迁移）。
-- 本地 fork：/Users/lijia/neovim-plugins/nvim-jump，含两处补丁：
--   1. 盲打（不再在消息行回显 "/"+输入）；
--   2. 修正 LSP inlay hint 导致的标签错位（inline vt 锚在匹配起点时用 win_col）。

return {
	dir = "~/neovim-plugins/nvim-jump",
	config = function()
		require("jump").setup({
			-- 默认标签序列（按偏好排序），保持默认即可
			-- labels = "fdsaghjklrewqtyuiopvcxzbnm",
			search = "Search",
			label = "FlashLabel", -- tokyonight 定义了该高亮组
		})

		vim.keymap.set({ "n", "x", "o" }, "s", function()
			require("jump").start()
		end, { desc = "Jump" })
	end,
}
