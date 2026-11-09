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
		})

		-- 映射：aq 直接提问，ab 入队（源码行留 sign + 虚拟文本），aB 逐条全发，ai 命名实例。
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
		map("n", "<leader>ai", "<cmd>AskAgentAlias<cr>", { desc = "AI: 给 agent 实例命名" })

		-- 上下文桥的扩展动作：让外部 agent 能拉「项目概览」紧凑摘要。
		-- 这个摘要依赖本配置里的 local.project，所以留在配置侧注册。
		require("ask_agent.bridge").extend("project", function(req)
			local ok, project = pcall(require, "local.project")
			if not ok then
				return { ok = false, error = "local.project not loaded: " .. tostring(project) }
			end
			return project.bridge(req)
		end)
	end,
}
