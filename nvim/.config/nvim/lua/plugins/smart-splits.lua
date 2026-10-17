-- https://github.com/smart-splits-nvim/smart-splits.nvim
--
-- v3 把复用器后端拆成独立插件。herdr 没有官方后端，用本仓库自维护的
-- lua/vendor/smart-splits-backend-herdr/init.lua（实现 v3 协议）。

return {
	"smart-splits-nvim/smart-splits.nvim",
	tag = "v3.0.0", -- 锁定 v3 大版本，避免再次被动跨大版本升级
	event = "VeryLazy",
	-- backend-ghostty 必须在 smart-splits 激活前 setup（lazy 会先加载依赖）。
	-- key_table 默认 'nvim'，与 ~/.config/ghostty/config 里的 `nvim/` 前缀一致。
	-- https://github.com/smart-splits-nvim/backend-ghostty
	dependencies = { { "smart-splits-nvim/backend-ghostty", main = "smart-splits-backend-ghostty", opts = {} } },
	config = function()
		local ss = require("smart-splits")

		ss.setup({
			move = {
				-- 到达整个终端最外层边缘（无相邻 herdr/Ghostty pane）时原地不动，
				-- 避免 wrap 悄悄绕到对面 nvim 窗口。有相邻 pane 时仍会切过去。
				at_edge = "stop",
			},
			resize = {
				amount = 1, -- 每次 resize 1 行/列，更精细（默认 3 太粗）；原 default_amount
			},
			mux = {
				-- 按顺序探测，取第一个 detect() 为真的：
				--   herdr 面板内 → 自维护后端 vendor.smart-splits-backend-herdr
				--   裸 Ghostty 面板 → 官方 backend-ghostty
				-- 跨 pane resize 的「格数 → 比例」换算已收进 herdr 后端内部。
				backend = { "vendor.smart-splits-backend-herdr", "smart-splits-backend-ghostty" },
			},
			log = { file = false }, -- v3 默认写日志文件，这里关掉
		})

		local map = vim.keymap.set

		-- 移动光标到相邻窗口（ctrl+hjkl，单修饰符，与 herdr 统一）
		map({ "n", "x" }, "<C-h>", ss.move_cursor_left, { desc = "Smart-splits: 光标去左窗口" })
		map({ "n", "x" }, "<C-j>", ss.move_cursor_down, { desc = "Smart-splits: 光标去下窗口" })
		map({ "n", "x" }, "<C-k>", ss.move_cursor_up, { desc = "Smart-splits: 光标去上窗口" })
		map({ "n", "x" }, "<C-l>", ss.move_cursor_right, { desc = "Smart-splits: 光标去右窗口" })

		-- 调整窗口大小（ctrl+alt+hjkl）。
		-- 不用裸 alt：macOS 下 Option 会被终端组合成特殊字符，且 alt 以 ESC 前缀传输时
		-- 与真正的 Esc 同前缀，经 herdr 消歧义后可能被拆成 esc+字母而失效。
		-- ctrl+alt 是 herdr 官方推荐、跨终端最稳的直接修饰键家族。
		-- herdr 侧同步把 ctrl+alt+hjkl 绑到 smart-splits.nvim.resize-*（见 dotfiles/herdr）：
		-- 焦点在 vim pane 时转发回下面的 <C-A-*> 映射，在非 vim pane 时直接 resize herdr 面板。
		map("n", "<C-A-h>", ss.resize_left, { desc = "Smart-splits: 左边界左移(变宽)" })
		map("n", "<C-A-j>", ss.resize_down, { desc = "Smart-splits: 下边界下移(变高)" })
		map("n", "<C-A-k>", ss.resize_up, { desc = "Smart-splits: 上边界上移(变高)" })
		map("n", "<C-A-l>", ss.resize_right, { desc = "Smart-splits: 右边界右移(变宽)" })

		-- 交换窗口 buffer（<leader><leader> + hjkl）
		map("n", "<leader><leader>h", ss.swap_buf_left, { desc = "Smart-splits: 与左窗口换 buffer" })
		map("n", "<leader><leader>j", ss.swap_buf_down, { desc = "Smart-splits: 与下窗口换 buffer" })
		map("n", "<leader><leader>k", ss.swap_buf_up, { desc = "Smart-splits: 与上窗口换 buffer" })
		map("n", "<leader><leader>l", ss.swap_buf_right, { desc = "Smart-splits: 与右窗口换 buffer" })
	end,
}
