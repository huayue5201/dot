-- https://github.com/smart-splits-nvim/smart-splits.nvim

return {
	"smart-splits-nvim/smart-splits.nvim",
	version = "^3.0.0", -- 锁定 v3 大版本，比 branch = "v3" 更稳定
	-- 注意：herdr 集成依赖插件在「加载时」检测 HERDR_ENV 并注册按键映射，
	-- 所以这里刻意不懒加载（不用 keys/event），保证 Neovim 启动即注册。
	config = function()
		local ss = require("smart-splits")

		ss.setup({
			log = { file = false }, -- v3 默认会写日志文件，这里关掉
			default_amount = 1, -- 每次 resize 1 行/列，更精细（默认 3 太粗）
			multiplexer_integration = "herdr", -- 显式启用 herdr 集成（自动探测可能因 $TERM_PROGRAM=ghostty 失败）
			disable_multiplexer_nav_when_zoomed = true, -- 当前 herdr 面板放大时不做跳转
		})

		-- 修正 herdr 跨 pane resize 的语义：
		-- smart-splits 把「格数」传给 mux.resize_pane（default_amount=1 即 1 列/行），
		-- 但 herdr 的 `pane resize --amount` 期望的是「比例增量」（0.05 = 5%），
		-- 传 1 会被当成 100% 再 clamp 到 50%，一下跳半屏。这里按窗口列/行数换算成比例，
		-- 让跨 pane 的 resize 也是 1 格一档（可叠加 count 前缀）。
		local ok_herdr, herdr_mux = pcall(require, "smart-splits.mux.herdr")
		if ok_herdr and herdr_mux then
			local herdr_resize_orig = herdr_mux.resize_pane
			herdr_mux.resize_pane = function(direction, amount)
				amount = amount or 1
				local horizontal = direction == "left" or direction == "right"
				local cells = horizontal and vim.o.columns or vim.o.lines
				local ratio = amount / math.max(cells, 1)
				if ratio > 0.5 then
					ratio = 0.5 -- herdr 内部对 delta 的 clamp 上限
				end
				return herdr_resize_orig(direction, ratio)
			end
		end

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
