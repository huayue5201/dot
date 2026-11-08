-- https://github.com/smart-splits-nvim/smart-splits.nvim
--
-- v3 把复用器后端拆成独立插件。herdr / rex 都用本仓库自维护的 vendor 后端
-- （lua/vendor/smart-splits-backend-{herdr,rex}.lua，实现 v3 协议）。

return {
	"smart-splits-nvim/smart-splits.nvim",
	tag = "v3.0.0", -- 锁定 v3 大版本，避免再次被动跨大版本升级
	config = function()
		local ss = require("smart-splits")

		ss.setup({
			move = {
				-- 到达整个终端最外层边缘（无相邻 herdr/Rex pane）时原地不动，
				-- 避免 wrap 悄悄绕到对面 nvim 窗口。有相邻 pane 时仍会切过去。
				at_edge = "stop",
			},
			resize = {
				amount = 1, -- 每次 resize 1 行/列，更精细（默认 3 太粗）；原 default_amount
			},
			mux = {
				-- 按顺序探测，取第一个 detect() 为真的：
				--   herdr 面板内 → 自维护后端 vendor.smart-splits-backend-herdr
				--   Rex block 内 → 自维护后端 vendor.smart-splits-backend-rex
				-- 顺序即嵌套优先级：herdr 跑在 Rex 的 block 里时，最内层是 herdr。
				-- 跨 pane resize 的「格数 → 比例」换算已收进各自后端内部。
				-- 只用 Rex（Ghostty 适配器已移除，Ghostty 上游也不再更新）。
				backend = function()
					local list = { "vendor.smart-splits-backend-herdr" }
					if (vim.env.REX_SESSION or "") ~= "" then
						list[#list + 1] = "vendor.smart-splits-backend-rex"
					end
					return list
				end,
			},
			log = { file = false }, -- v3 默认写日志文件，这里关掉
		})

		local map = vim.keymap.set

		-- [diffbandit-compat] 绕过 diffbandit focusable=false 窗格导致的 winnr 导航失效
		-- diffbandit 的自绘 gutter（行号 / connector / overview）都是 focusable=false 的
		-- nvim_open_win 窗格，win_id2win() 返回 0，于是 winnr('l') 把它们当不存在、
		-- 甚至返回当前窗口 —— smart-splits 据此判定「已经在边缘」就不再移动，
		-- 所以在 diff 面板里 <C-h>/<C-l> 失效（<C-w>l 走原生 nav 仍是好的）。
		-- 这里先按 session 的 left_win / right_win（以及 git 面板的 nav_win）直接跳转，
		-- 跳不动再交回 smart-splits（这时才是真的到边，可能该跨到 herdr/Rex pane）。
		local function db_move(dir)
			local ok, state = pcall(require, "diffbandit.state")
			if not ok then
				return false
			end
			local tab = vim.api.nvim_get_current_tabpage()
			local win = vim.api.nvim_get_current_win()
			local hosts = {}
			for _, s in pairs(state.sessions or {}) do
				hosts[#hosts + 1] = s
			end
			for _, p in pairs(state.panels or {}) do
				hosts[#hosts + 1] = p
			end
			local function valid(w)
				return w and vim.api.nvim_win_is_valid(w) and w or nil
			end
			for _, h in ipairs(hosts) do
				if not h.disposed and h.tabpage == tab then
					local left, right = valid(h.left_win), valid(h.right_win)
					local nav = valid(h.panel and h.panel.nav_win)
					local target
					if dir == "left" then
						target = win == right and left or (win == left and nav)
					elseif dir == "right" then
						target = win == nav and left or (win == left and right)
					end
					if target and target ~= win then
						vim.api.nvim_set_current_win(target)
						return true
					end
				end
			end
			return false
		end
		-- [/diffbandit-compat]

		-- 移动光标到相邻窗口（ctrl+hjkl，单修饰符，与 herdr 统一）
		-- （<C-h>/<C-l> 的外层包装属 diffbandit 兼容层，见上）
		map({ "n", "x" }, "<C-h>", function()
			if not db_move("left") then
				ss.move_cursor_left()
			end
		end, { desc = "Smart-splits: move cursor to left window" })
		map({ "n", "x" }, "<C-j>", ss.move_cursor_down, { desc = "Smart-splits: move cursor to down window" })
		map({ "n", "x" }, "<C-k>", ss.move_cursor_up, { desc = "Smart-splits: move cursor to up window" })
		map({ "n", "x" }, "<C-l>", function()
			if not db_move("right") then
				ss.move_cursor_right()
			end
		end, { desc = "Smart-splits: move cursor to right window" })

		-- 调整窗口大小（ctrl+alt+hjkl）。
		-- 不用裸 alt：macOS 下 Option 会被终端组合成特殊字符，且 alt 以 ESC 前缀传输时
		-- 与真正的 Esc 同前缀，经 herdr 消歧义后可能被拆成 esc+字母而失效。
		-- ctrl+alt 是 herdr 官方推荐、跨终端最稳的直接修饰键家族。
		-- herdr 侧同步把 ctrl+alt+hjkl 绑到 smart-splits.nvim.resize-*（见 dotfiles/herdr）：
		-- 焦点在 vim pane 时转发回下面的 <C-A-*> 映射，在非 vim pane 时直接 resize herdr 面板。
		map("n", "<C-A-h>", ss.resize_left, { desc = "Smart-splits: resize left boundary left (wider)" })
		map("n", "<C-A-j>", ss.resize_down, { desc = "Smart-splits: resize bottom boundary down (taller)" })
		map("n", "<C-A-k>", ss.resize_up, { desc = "Smart-splits: resize top boundary up (taller)" })
		map("n", "<C-A-l>", ss.resize_right, { desc = "Smart-splits: resize right boundary right (wider)" })

		-- 交换窗口 buffer（<leader><leader> + hjkl）
		map("n", "<leader><leader>h", ss.swap_buf_left, { desc = "Smart-splits: swap buffer with left window" })
		map("n", "<leader><leader>j", ss.swap_buf_down, { desc = "Smart-splits: swap buffer with down window" })
		map("n", "<leader><leader>k", ss.swap_buf_up, { desc = "Smart-splits: swap buffer with up window" })
		map("n", "<leader><leader>l", ss.swap_buf_right, { desc = "Smart-splits: swap buffer with right window" })
	end,
}
