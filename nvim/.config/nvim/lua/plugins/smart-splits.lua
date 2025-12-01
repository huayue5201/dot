-- https://github.com/mrjones2014/smart-splits.nvim

return {
	"mrjones2014/smart-splits.nvim",
	event = "WinNew",
	config = function()
		-- 配置 smart-splits.nvim 插件
		require("smart-splits").setup({
			-- 鼠标拖动支持 (optional)
			mouse_support = true,

			-- 默认快捷键配置
			keymaps = {
				-- 通过快捷键切换窗口
				left = "<C-h>",
				down = "<C-j>",
				up = "<C-k>",
				right = "<C-l>",

				-- 通过快捷键调整窗口大小
				increase_width = "<C-S-h>",
				decrease_width = "<C-S-l>",
				increase_height = "<C-S-j>",
				decrease_height = "<C-S-k>",
			},

			-- 窗口大小的最小值
			resize_step = 2,

			-- 调整窗口大小时是否开启平滑动画
			smooth_resize = true,
		})
		-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
		vim.keymap.set("n", "<A-Left>", require("smart-splits").resize_left)
		vim.keymap.set("n", "<A-Down>", require("smart-splits").resize_down)
		vim.keymap.set("n", "<A-Up>", require("smart-splits").resize_up)
		vim.keymap.set("n", "<A-Right>", require("smart-splits").resize_right)
	end,
}
