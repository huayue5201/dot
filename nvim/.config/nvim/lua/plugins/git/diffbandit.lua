-- https://github.com/CoreyKaylor/diffbandit.nvim
-- 三栏 diff（左内容 / 连接带 / 右内容），不做行内对齐填充。
-- 需要 nvim 0.10+；连接带用 image（Kitty graphics，nvim 0.12+）时才是贝塞尔曲线，
-- 否则退回 Unicode 单元格渲染（tmux / iTerm2 / Terminal.app 走这条路）。
--
-- 与 codediff.nvim 并存：codediff 用 <leader>h*（常用），diffbandit 让到 <leader>H*（同字母，大写前缀）。
-- 本插件负责的键：
--   <leader>Hf  git 变更队列
--   <leader>Hh  仓库提交历史
--   <leader>Hd  当前文件 vs 工作区
--   <leader>HH  当前文件的历史
--   <leader>HD  git 工作流菜单（暂存/提交/比较/切分支）
--   <leader>Hm  冲突三路解决器（codediff 冲突视图的替代）
--   <leader>HP  提交面板（<leader>hc 已被 neogit 的提交信息占用）
-- codediff 的「选区行范围历史」用它自己的 visual <leader>hh。

return {
	"CoreyKaylor/diffbandit.nvim",
	config = function()
		-- 按终端宽度自适应：MacBook 小屏（Ghostty 默认 120 列）下三栏 + 9 列连接带 + 42 列 git 面板
		-- 会挤到每边只剩 ~47 列代码，所以小屏把 connector / 面板让出的列还给内容。
		-- 插件自身没有列数自适应（主 diff 的宽度取自 config.ui.connector_width，
		-- 只有 merge 视图 merge/init.lua:372 参考 vim.o.columns），因此这里直接改配置表：
		-- start_session 每次新建 session 都读 state.get_config()（diffbandit/init.lua:57），
		-- 所以新开的 session 生效，已打开的 session 不会中途重排。
		local function fit_to_width(cfg)
			local cols = vim.o.columns
			local connector, panel
			if cols >= 160 then
				connector, panel = 9, 42
			elseif cols >= 130 then
				connector, panel = 7, 38
			else
				connector, panel = 5, 34
			end
			cfg.ui.connector_width = connector
			cfg.ui.connector_max_width = connector
			cfg.git.panel.width = panel
		end

		local config = require("diffbandit").setup({
			diff = {
				ignore_whitespace = false,
			},
			ui = {
				connector_renderer = "auto", -- auto | kitty | cells
				status = { enabled = true },
				overview = { enabled = true, width = 1, cursor = true },
				-- 连接带（kitty 图像渲染时）的曲线宽度：默认 1.45 行高在窄栏下
				-- 只剩一条很细的带子，加宽后更接近插件演示图里的粗丝带。
				kitty = { divider_width = 2.2 },
			},
			git = {
				default_mode = "all",
				include_untracked = true,
				find_renames = true,
				panel = {
					width = 42,
					commit_height = 10,
					preview_on_cursor = true,
				},
			},
			navigation = {
				initial_focus = "right",
				align_on_jump = true,
				-- 到最后一处改动时问一句是否打开下一个文件（git 队列里很顺手）
				on_request_next_file = nil,
			},
			minimap = {
				auto = true, -- editor-window minimaps
				git = true,
				diagnostics = { enabled = true, min_severity = "warn" },
				min_window_width = 60,
			},
		})

		fit_to_width(config)
		vim.api.nvim_create_autocmd("VimResized", {
			group = vim.api.nvim_create_augroup("diffbandit_width_fit", { clear = true }),
			callback = function()
				fit_to_width(config)
			end,
		})

		-- [diffbandit-compat] 上游 bug 兜底
		-- 上游 bug 兜底（diffbandit f190e33，session/init.lua:218 render_overviews）：
		-- CursorMoved 的 overview 防抖（ui.overview.debounce_ms=32）可能在 diff 窗口/标签已被关掉
		-- 之后才触发；该函数只校验了 overview 两个窗口，却直接对 self.left_win / self.right_win
		-- 调 nvim_win_get_height，于是报 "Invalid window id: 1041"。
		-- 这里补上内容窗口与 tabpage 的有效性校验（窗口没了 overview 本来也画不了）。
		-- 上游修好后可整段删掉。
		do
			local Session = require("diffbandit.session")
			local orig_render_overviews = Session.render_overviews
			function Session:render_overviews(...)
				if self.disposed then
					return
				end
				if
					not (vim.api.nvim_tabpage_is_valid(self.tabpage) and vim.api.nvim_win_is_valid(self.left_win))
					or not vim.api.nvim_win_is_valid(self.right_win)
				then
					return
				end
				return orig_render_overviews(self, ...)
			end
		end
		-- [/diffbandit-compat]

		-- [diffbandit-compat] ]c/[c 文件内循环（上游 goto_*_chunk 在边界会 confirm 跨文件）
		-- ]c/[c 改成在文件内循环：到最后一个 hunk 后回到第一个（反向同理），不再弹
		-- 「end of this file / already at first changed file」这类边界提示，也不自动跨文件
		-- （跨文件仍用 ]f/[f）。上游 goto_next_chunk 在边界处会走 confirm_file_boundary，
		-- 所以直接包一层，边界时自己调用 goto_chunk(1)/(#chunks)。
		do
			local Session = require("diffbandit.session")
			local orig_next = Session.goto_next_chunk
			local orig_prev = Session.goto_prev_chunk

			function Session:goto_next_chunk()
				local chunks = self.view and self.view.chunks
				if chunks and #chunks > 0 and (self.current_chunk or 0) >= #chunks then
					self.pending_file_boundary = nil
					self:goto_chunk(1)
					return
				end
				return orig_next(self)
			end

			function Session:goto_prev_chunk()
				local chunks = self.view and self.view.chunks
				if chunks and #chunks > 0 and (self.current_chunk or 0) <= 1 then
					self.pending_file_boundary = nil
					self:goto_chunk(#chunks)
					return
				end
				return orig_prev(self)
			end
		end
		-- [/diffbandit-compat]

		-- [diffbandit-compat] 清掉 diff 窗格的 winbar
		-- 上游只在 merge 视图清了 winbar（merge/init.lua:388），主 diff 视图没管：
		-- 右侧内容是真实文件 buffer 时，dropbar 会在该窗口挂上 winbar，而左侧是 nofile buffer
		-- 不会挂 → 右窗口多一行，色块/连接带整体错位一行。
		-- 这里在布局完成、换右侧 buffer 之后各清一次；dropbar 自己那边另有 enable 黑名单。
		do
			local Layout = require("diffbandit.session.layout")
			local function clear_winbar(session)
				for _, win in ipairs({ session.left_win, session.right_win }) do
					if win and vim.api.nvim_win_is_valid(win) then
						pcall(vim.api.nvim_set_option_value, "winbar", "", { scope = "local", win = win })
					end
				end
			end

			local orig_open = Layout.open
			function Layout.open(session)
				orig_open(session)
				clear_winbar(session)
			end

			local orig_apply_right = Layout.apply_right_source_window_options
			function Layout.apply_right_source_window_options(session)
				orig_apply_right(session)
				clear_winbar(session)
			end

			-- 队列切文件 / 重新进入窗口时 dropbar 可能再次挂上（它监听 BufEnter/BufWinEnter）
			vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "WinEnter" }, {
				group = vim.api.nvim_create_augroup("diffbandit_no_winbar", { clear = true }),
				callback = function()
					local session = require("diffbandit.state").sessions[vim.api.nvim_get_current_tabpage()]
					if session then
						clear_winbar(session)
					end
				end,
			})
		end
		-- [/diffbandit-compat]

		local keymap = vim.keymap.set
		local function map(lhs, rhs, desc)
			keymap("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
		end

		map("<leader>Hf", "<cmd>DiffBanditGit<cr>", "Diff: Git 变更队列")
		map("<leader>Hh", "<cmd>DiffBanditGitLog<cr>", "Diff: 仓库提交历史")
		map("<leader>Hd", "<cmd>DiffBanditGitCurrent<cr>", "Diff: 当前文件 vs HEAD")
		-- 注意：DiffBanditGitLog 的 pathspec 不展开 %，这里手动展开成当前文件名
		map("<leader>HH", function()
			local file = vim.fn.expand("%")
			if file == "" then
				return vim.notify("当前 buffer 没有文件名", vim.log.levels.WARN)
			end
			vim.cmd("DiffBanditGitLog -- " .. vim.fn.fnameescape(file))
		end, "Diff: 当前文件历史")
		map("<leader>HD", "<cmd>DiffBanditGitMenu<cr>", "Diff: Git 工作流菜单")
		map("<leader>Hm", "<cmd>DiffBanditMerge<cr>", "Diff: 冲突解决（三路）")
		map("<leader>HP", "<cmd>DiffBanditCommitPanel<cr>", "Diff: 提交面板")
	end,
}
