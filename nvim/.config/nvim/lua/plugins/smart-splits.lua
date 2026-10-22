-- https://github.com/smart-splits-nvim/smart-splits.nvim
--
-- v3 把复用器后端拆成独立插件。herdr 没有官方后端，用本仓库自维护的
-- lua/vendor/smart-splits-backend-herdr.lua（实现 v3 协议）。

return {
	"smart-splits-nvim/smart-splits.nvim",
	tag = "v3.0.0", -- 锁定 v3 大版本，避免再次被动跨大版本升级
	-- backend-ghostty 必须在 smart-splits 激活前 setup（加载器会先加载 dependencies）。
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
				--
				-- 用函数而不用固定列表：backend-ghostty 的 detect 会跑
				-- scripts/ghostty.js（osascript/JXA）找宿主进程，在 Ghostty 之外
				-- 会往 stderr 吐 `No owning Ghostty or cmux process found (-2700)`。
				backend = function()
					local list = { "vendor.smart-splits-backend-herdr" }
					local prog = (vim.env.TERM_PROGRAM or ""):lower()
					if prog == "ghostty" or (vim.env.GHOSTTY_RESOURCES_DIR or "") ~= "" then
						list[#list + 1] = "smart-splits-backend-ghostty"
					end
					return list
				end,
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

		-- backend-ghostty 只在第一次 attach 时抓一次「Ghostty 当前焦点 terminal」当目标：
		-- Ghostty 的 AppleScript 模型里 terminal 只有 id/name/index/selected，没有 pid/tty，
		-- 无法反查「哪个 surface 拥有本进程」。于是 nvim 在非焦点分屏/后台标签里启动时，
		-- 抓到的是别人的 id，而且之后永不重抓 → 那个 nvim 整个生命周期都跳不动。
		-- FocusGained 恰好是本 surface 拿到焦点的时刻（focus 转义序列由它自己发出），
		-- 在这里清掉可能抓错的 id 和 claim 状态，让后端重新 attach + claim。
		local refresh_group = vim.api.nvim_create_augroup("smart_splits_ghostty_refocus", { clear = true })
		vim.api.nvim_create_autocmd("FocusGained", {
			group = refresh_group,
			desc = "Smart-splits: 重新绑定 Ghostty terminal_id",
			callback = function()
				local ok, backend = pcall(function()
					return require("smart-splits.backend").resolve()
				end)
				if not ok or backend == nil or backend.name ~= "smart-splits-backend-ghostty" then
					return
				end
				local ok_ghostty, ghostty = pcall(require, "smart-splits-backend-ghostty.ghostty")
				local ok_lifecycle, lifecycle = pcall(require, "smart-splits-backend-ghostty.lifecycle")
				if not (ok_ghostty and ok_lifecycle) then
					return
				end
				lifecycle.reset() -- 清 claimed/active 和旧 autocmd（activate 会重建）
				ghostty.reset() -- 清可能抓错的 terminal_id，下次 attach 重抓
				pcall(backend.activate)
			end,
		})
	end,
}
