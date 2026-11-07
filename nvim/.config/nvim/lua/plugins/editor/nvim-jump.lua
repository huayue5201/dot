-- https://github.com/yorickpeterse/nvim-jump
-- 极简跳转插件，替代 flash.nvim。
-- 只有 jump 一个动作：输入若干字符缩小匹配 → 按标签跳转。
-- 无 treesitter / remote / search 模式（这些是 flash 独有功能，不迁移）。
-- 本地 fork：/Users/lijia/neovim-plugins/nvim-jump，相对上游含：
--   1. 盲打（不再在消息行回显 "/"+输入）；
--   2. 修正 LSP inlay hint 导致的标签错位（inline vt 锚在匹配起点时用 win_col）；
--   3. 中文按拼音首字母匹配（nh → 你好，nhsj → 你好世界），无需切输入法；
--      多音字可匹配任一读音（行 x/h、重 z/c、长 c/z）；
--   4. 多字节修复（退格按字符删、标签用显示列、下一个字符不再切半）；
--   5. 可插拔 codec（keys/parse/normalize），可扩展其他非拉丁文字；
--   6. 查询先做 NFC 归一化（分解重音、Hangul jamo 也能匹配），最长匹配优先。
-- 测试：cd 到插件目录，nvim --headless --clean -l tests/run.lua

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
