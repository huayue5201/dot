-- https://github.com/huayue5201/ask-agent.nvim
-- 「在 nvim 里写问题，连同锚点发给外部 agent」的通道（:AskAgent / <leader>aq）。
-- 插件只提供命令，不装按键；映射在这里由本配置决定。
-- 本地开发用 dir，稳定后改成 "huayue5201/ask-agent.nvim" 走远端。

return {
	dir = "~/neovim-plugins/ask-agent.nvim",
	-- 无硬依赖：地图模式按需 pcall rex 的分屏几何；列表模式走 vim.ui.select，
	-- 由本配置里接管它的插件（当前是 dropbar）决定长什么样
	config = function()
		local ask = require("ask_agent")

		ask.setup({
			-- 只有 cwd 完全一致的实例才算候选（related / single 是更宽松的两档）
			matching = "exact",
			-- map = rex 分屏地图（默认），list = 列表
			picker = "map",
			-- busy 图标复用 ui-menu 的帧与节奏（list 与 map 两处 picker 都走这两个值），
			-- 改 ui_menu 的 M.frames / M.config.tick 即可同步，不用再动插件。
			spinner = require("ui_menu").frames,
			tick = require("ui_menu").config.tick,
			-- Claude Code：tmux 里的 CLI 走通用 paste+enter；busy 由它自己的 hooks 写标记
			-- （~/.claude/ask-agent-state.sh，见 ask-agent.nvim/extensions/）。
			-- 用 :AskAgentBackend claude 切过去。
			extra = { require("ask_agent.backends.claude").new() },
			-- 状态层（:AskAgentDashboard / 状态栏 ⚠✓✗◐ 的唯一数据源）每 2s 探一次；
			-- rex 里的实例直接读 OSC 7501，比 busy 标记准。完成/等待确认会通知一次。
			state_interval = 2000,
			state_notify = true,
			-- 通知样式：按级别取 Diagnostic 色并加粗（装了 nvim-notify 等则交给它渲染）
			notify_style = true,
			-- 每次通知响终端警告声；:set belloff=all 可临时静音
			notify_sound = true,
			-- 图标全在这里：扁平字符串 = 某个 agent 的图标（键为 backend/实例 id，缺省回落
			-- fallback），ui 组 = 面板/状态栏/通知上的所有标记。下面是默认值，按需改。
			icons = {
				-- agent 图标
				pi = "π",
				claude = vim.fn.nr2char(0x273B), -- Claude Code 的星号
				generic = vim.fn.nr2char(0xF120), -- nf-fa-terminal
				fallback = vim.fn.nr2char(0xF06A9), -- nf-md-robot（未知 agent）
				ui = {
					-- dashboard winbar 与通知前缀
					header = vim.fn.nr2char(0xF06A9),
					-- 状态栏 / 面板里每个 agent 的状态标记
					state = {
						blocked = "⚠", -- 等你确认/回答
						done = "✓", -- 完成且未确认
						error = "✗",
						working = "◐", -- 有 spinner 时用 spinner 帧
						idle = "●",
						unknown = "◌",
						gone = "○", -- 进程已退出
					},
					-- 面板树里每条任务的标记
					task = { queued = "◐", done = "✓", error = "✗" },
					-- 树的折叠/展开/空行装饰
					tree = { collapsed = "▸", expanded = "▾", leaf = "·" },
					-- 忙碌 spinner 帧（改了这里就不用再看上面的 spinner 选项；
					-- 顶层的 spinner = require("ui_menu").frames 优先级更高）
					spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
				},
			},
			-- agent 图标品牌色（hex），键与 icons 里的 agent 一致
			icon_colors = { claude = "#d97757" },
		})

		-- 映射：aq 直接提问，ab 入队（源码行留 sign + 虚拟文本），aB 逐条全发，
		-- ad 状态面板（高频），ax 删光标行入队项，au 反悔最近一次删除/清空，ar 命名实例。
		-- 批量队列管理用命令：:AskAgentBatchList / :AskAgentBatchClear。
		local map = vim.keymap.set
		map("n", "<leader>aq", function()
			ask.ask()
		end, { desc = "AI: 提问（光标锚点）" })
		map("v", "<leader>aq", function()
			ask.ask({ visual = true })
		end, { desc = "AI: 提问（选区锚点）" })
		map("n", "<leader>ab", function()
			ask.batch_ask()
		end, { desc = "AI: 入队提问（光标锚点）" })
		map("v", "<leader>ab", function()
			ask.batch_ask({ visual = true })
		end, { desc = "AI: 入队提问（选区锚点）" })
		map("n", "<leader>aB", function()
			ask.batch_send()
		end, { desc = "AI: 发送全部入队提问" })
		map("n", "<leader>ax", "<cmd>AskAgentBatchDelete<cr>", { desc = "AI: 删除光标行的入队提问" })
		map("n", "<leader>au", "<cmd>AskAgentBatchUndo<cr>", { desc = "AI: 反悔（恢复刚删的入队提问）" })
		map("n", "<leader>ar", "<cmd>AskAgentRename<cr>", { desc = "AI: 给 agent 实例命名" })
		-- 状态面板：所有实例按「谁在等我」排序；<CR> 跳过去、s 发、S 发该实例名下队列、
		-- a 确认完成、C 看输出（rex）。状态栏的 ⚠✓✗◐ 段也来自同一个状态层。
		map("n", "<leader>ad", "<cmd>AskAgentDashboard<cr>", { desc = "AI: agent 状态面板" })

		-- 上下文桥的扩展动作：让外部 agent 能拉「项目概览」紧凑摘要。
		-- project-overview.nvim 提供 digest，所以在配置侧注册。
		require("ask_agent.bridge").extend("project", function(req)
			local ok, project = pcall(require, "project_overview")
			if not ok then
				return { ok = false, error = "project_overview not loaded: " .. tostring(project) }
			end
			return project.bridge(req)
		end)
	end,
}
