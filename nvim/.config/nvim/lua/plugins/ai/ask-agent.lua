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
			-- 小地图：画布大小 = 屏幕的 width/height 比例，再夹到 min/max_* 个字符格；
			-- 只有光标所在那一格会从字母换成 agent 名字（放不下就用 … 截断，
			-- 再放不下回到字母），其它格始终是一个字母，名字再长也不会把地图挤变形。
			map = {
				width = 0.25, -- 编辑器宽度的 25%
				min_width = 12, -- 太小的屏幕上至少 12 列，否则地图看不清
				max_width = 32, -- 再大的屏幕上最多 32 列，避免地图铺满视野
				height = 0.20, -- 编辑器高度的 20%
				min_height = 3,
				max_height = 9,
				name = true, -- false = 只显示字母
				name_min = 3, -- 截断后不足 3 列就退回字母（少于 3 列读不出信息）
				name_over_badge = true, -- 名字和状态徽标抢地方时，先丢徽标保住名字
			},
			-- busy 图标复用 ui-menu 的帧与节奏（list 与 map 两处 picker 都走这两个值），
			-- 改 ui_menu 的 M.frames / M.config.tick 即可同步，不用再动插件。
			spinner = require("ui_menu").frames,
			tick = require("ui_menu").config.tick,
			-- Claude Code：tmux 里的 CLI 走通用 paste+enter；busy 由它自己的 hooks 写标记
			-- （~/.claude/ask-agent-state.sh，见 ask-agent.nvim/extensions/）。
			-- 用 :AskAgentBackend claude 切过去。
			extra = { require("ask_agent.backends.claude").new() },
			-- 答案回写（默认关）：打开后 agent 本轮的最后一条回复会按 task_id 回到发出它的
			-- 那条任务上——面板里 o 看问答、v 看这一轮的 diff（不再依赖插件自己记的 turn）。
			-- pi：走 socket 回传（改了 extensions/nvim-context.ts，需重启 pi 才生效）；
			-- Claude：走 Stop hook 的 done 模式写文件邮箱（见 ~/.claude/settings.json）。
			results = true,
			-- 提问时携带的上下文：未保存 buffer / 无路径 buffer（diff）会把光标上下
			-- total 行源码一起发出去（存盘的普通文件不复制，agent 自己读更准）；
			-- 选区超长会截断并标 (clipped)。根目录/分支/光标行诊断总是带上。
			context_lines = 20, -- 0 = 不内联源码
			max_selection = 200, -- 选区最多 200 行 / 8KB
			max_selection_bytes = 8192,
			-- 提问时顺带一份「这是什么项目」的概要（project-overview.nvim 提供）：
			-- 结构/规模/构建入口/约定，没有源码。发送那一刻取，按 root 缓存 5 分钟，
			-- 省掉 agent 一轮 find/grep。没装该插件或采集失败就自动不带，不影响提问。
			project = { enabled = true, wait_ms = 1500, full = false, ttl = 300 },
			-- 状态层（:AskAgentDashboard / 状态栏 ⚠✓✗◐ 的唯一数据源）每 2s 探一次；
			-- rex 里的实例直接读 OSC 7501，比 busy 标记准。完成/等待确认会通知一次。
			state_interval = 2000,
			state_notify = true,
			-- 通知样式：按级别取 Diagnostic 色并加粗（装了 nvim-notify 等则交给它渲染）
			notify_style = true,
			-- 其余通知（发送失败、命令报错等）也响一声。
			-- 注意：neovim 默认 :set belloff=all，插件自己的 sound 开关才是静音开关，
			-- 所以这里不需要动 belloff；想恢复「belloff 说了算」就设 notify_belloff = true。
			notify_sound = true,
			-- 终端铃在很多终端里是静音的，用系统音效更靠谱（macOS 自带音效目录）。
			notify_sound_cmd = "afplay /System/Library/Sounds/Glass.aiff",
			-- 状态通知浮一张小卡片在右上角，3s 自动消失：cmdline 那一行太容易被下一次重绘盖掉。
			notify_popup = true,
			notify_popup_ms = 3000,
			-- 状态通知：每个状态一条可自定义的文案 + 级别 + 铃声。
			--   占位符 {backend} 后端名、{name} 实例名、{msg} agent 自己说的话（自带「: 」前缀，
			--   没说话就是空串）、{state}/{kind}/{was} 原始状态与「退出时在干什么」。
			--   level 用 vim.log.levels 的名字；sound 单独控制这条是否响铃。
			--   传字符串 = 只换文案；传 false = 这个状态彻底不通知。
			-- idle / working / unknown 是轮询噪声，插件本身就不通知。
			notify = {
				-- 干完了：不响，一天几十次会烦；想响就 sound = true
				done = {
					text = "✓ {name} 已完成{msg}",
					level = "INFO",
					sound = true,
				},
				-- 卡在等你（未知原因）：必须响，否则你就忘了它还在等
				blocked = {
					text = "⏸ {name} 正在等你：去它的终端看一眼{msg}",
					level = "WARN",
					sound = true,
				},
				-- 要权限（改文件、跑命令的最常见卡点）
				permission = {
					text = "⚠ {name} 请求权限：允许/拒绝要在它自己的终端里点{msg}",
					level = "WARN",
					sound = true,
				},
				-- 要你回答（选择题/追问）
				question = {
					text = "❓ {name} 有个问题要你回答{msg}",
					level = "WARN",
					sound = true,
				},
				-- 要凭据（登录过期、要 token）
				auth = {
					text = "🔑 {name} 需要凭据：去终端里登录或补 token{msg}",
					level = "WARN",
					sound = true,
				},
				-- 真出错：文案说清是谁、错在哪（agent 的 error 消息跟在后面）
				error = {
					text = "✗ {name} 出错了{msg}",
					level = "ERROR",
					sound = true,
				},
				-- 进程没了，且当时还欠你东西（在跑 / 在等）
				gone = {
					text = "○ {name} 退出了，它当时{was}{msg}",
					level = "WARN",
					sound = false,
				},
				-- {was} 的中文；{msg} 永远是 agent 自己的原话
				was = { blocked = "在等你", working = "在干活" },
			},
			-- 同一个 agent 的 done/error/gone 最多每 20s 一条（默认 30s）；
			-- blocked 系列永不节流——每次进入等待都值得说一次。
			notify_gap = 20000,
			-- 面板树线 + 指向「运行中任务」的动态路径。两者都用虚线字符
			-- （tree 里的 branch/corner/horizontal），dash 只负责沿这些格子走高亮。
			tree_lines = true,
			running_line = "dash",
			-- <CR> 浮窗查看 agent：第二显示端，不是副本——agent 仍在原 session/pane 里跑，
			-- 关窗只是 detach。打开时是 normal 模式，按 i 才把按键送进去；
			-- readonly = true 则连 i 也不放行（tmux 加 -r；rex 永远只读，输入回 Rex）。
			view = { readonly = false, width = 0.8, height = 0.75 },
			-- 图标全在这里：扁平字符串 = 某个 agent 的图标（键为 backend/实例 id，缺省回落
			-- fallback），ui 组 = 面板/状态栏/通知上的所有标记。下面是默认值，按需改。
			icons = {
				-- agent 图标
				pi = "π",
				claude = "✻", -- Claude Code 的星号
				generic = "", -- nf-fa-terminal
				fallback = "󰚩", -- nf-md-robot（未知 agent）
				ui = {
					-- dashboard winbar 与通知前缀
					header = "󰚩", -- nf-md-robot
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
					-- 树的折叠/展开/空行装饰 + 连接线。连接线全部用虚线字符：
					-- 与 running_line = "dash" 的高亮虚线动画同一套视觉语言，
					-- 也和 mini.indentscope 的 ┊ 导轨对得上。
					tree = {
						collapsed = "▸",
						expanded = "▾",
						leaf = "·",
						vertical = "┊", -- 竖直导轨
						branch = "┆", -- 中间的竖直分叉
						corner = "╰", -- 最后一个子项的圆角
						horizontal = "┄", -- 横向连接
					},
					-- 忙碌 spinner 帧（改了这里就不用再看上面的 spinner 选项；
					-- 顶层的 spinner = require("ui_menu").frames 优先级更高）
					spinner = {
						"",
						"",
						"",
						"",
						"",
						"",
					},
				},
			},
			-- agent 图标品牌色（hex），键与 icons 里的 agent 一致
			icon_colors = { claude = "#d97757" },
		})

		-- 映射：aq 直接提问，ab 入队（源码行留 sign + 虚拟文本），aB 逐条全发，
		-- ad 状态面板（高频），ax 删光标行入队项，au 反悔最近一次删除/清空，ar 命名实例。
		-- ah 历史提问（可搜索/重发/跳回），ap prompt 模板选择，aP 选区存为模板，
		-- av 审查最近一轮变更，aV 审查整个工作区 vs HEAD，ao 浮窗查看 agent 终端。
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
		-- 状态面板：所有实例按「谁在等我」排序；<CR> 浮窗查看该 agent（再 <CR> 到代码锚点）、
		-- v 看这条任务对应的那一轮 diff、o 看它的问题和答案（答案需 results = true）、
		-- s 发、S 发该实例名下队列、a 确认完成。状态栏的 ⚠✓✗◐ 段也来自同一个状态层。
		map("n", "<leader>ad", "<cmd>AskAgentDashboard<cr>", { desc = "AI: agent 状态面板" })
		-- 不进面板也能看：选一个实例，在浮窗里显示它的终端（rex / tmux / herdr 自动匹配）。
		map("n", "<leader>ao", function()
			local agents = ask.agents()
			if #agents == 0 then
				return vim.notify("[ask_agent] no agent instances", vim.log.levels.WARN)
			end
			vim.ui.select(agents, {
				prompt = "View agent",
				format_item = function(a)
					return ("%s  %s  %s"):format(a.id, ask.alias_of(a.target) or "", a.state)
				end,
			}, function(choice)
				if not choice then
					return
				end
				-- ask.view 是后加的 API；如果这次会话在它出现之前就 require 过 ask_agent，
				-- 模块是旧的，重开 nvim 才能拿到（配置 reload 不会刷新 Lua 模块缓存）。
				if type(ask.view) ~= "function" then
					return vim.notify("[ask_agent] viewer API missing — restart Neovim", vim.log.levels.WARN)
				end
				local ok, err = ask.view(choice.target)
				if not ok then
					vim.notify("[ask_agent] " .. tostring(err), vim.log.levels.WARN)
				end
			end)
		end, { desc = "AI: 浮窗查看 agent 终端" })

		-- 历史：发送成功的提问都带锚点记在本地，可搜索、原样重发、跳回当时那一行。
		map("n", "<leader>ah", "<cmd>AskAgentHistory<cr>", { desc = "AI: 历史提问（搜索/重发/跳回）" })
		-- prompt 库：全局模板 + 可提交到仓库的 .ask-agent/prompts.json。
		-- 占位符在发送时按当前锚点渲染：{{file}} {{line}} {{selection}} {{cwd}} …
		map("n", "<leader>ap", "<cmd>AskAgentPrompt<cr>", { desc = "AI: prompt 模板" })
		map("v", "<leader>ap", "<cmd>AskAgentPrompt!<cr>", { desc = "AI: prompt 模板（含选区）" })
		map(
			"v",
			"<leader>aP",
			":<C-u>AskAgentPromptSave ",
			{ desc = "AI: 选区存为 prompt 模板（输入名字）" }
		)
		-- 变更审查：两条 git tree 的 diff，渲染交给 diffbandit / nvim.difftool / codediff。
		map("n", "<leader>av", "<cmd>AskAgentDiff<cr>", { desc = "AI: 审查最近一轮变更" })
		map("n", "<leader>aV", "<cmd>AskAgentDiff head<cr>", { desc = "AI: 审查工作区 vs HEAD" })

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
