-- https://github.com/huayue5201/ask-agent.nvim
-- 「在 nvim 里写问题，连同锚点发给外部 agent」的通道（:AskAgent / <leader>aq）。
-- 批量模式：<leader>ab 入队（源码行留 sign + 虚拟文本）、<leader>aB 一次全发。
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
			keymaps = {
				ask = "<leader>aq",
				ask_visual = "<leader>aq",
				alias = "<leader>ai",
				-- 批量：<leader>ab 入队，<leader>aB 逐条全发；:AskAgentBatchList 管理队列
				batch = "<leader>ab",
				batch_visual = "<leader>ab",
				batch_send = "<leader>aB",
			},
		})

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
