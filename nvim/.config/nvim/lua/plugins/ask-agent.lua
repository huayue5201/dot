-- https://github.com/huayue5201/ask-agent.nvim
-- 「在 nvim 里写问题，连同锚点发给外部 agent」的通道（:AskAgent / <leader>aq）。
-- 本地开发用 dir，稳定后改成 "huayue5201/ask-agent.nvim" 走远端。

return {
	dir = "~/neovim-plugins/ask-agent.nvim",
	-- 地图模式要读 rex 的分屏几何，列表模式要 dropbar 的菜单（vim.ui.select 的全局覆盖）
	dependencies = { "Bekaboo/dropbar.nvim" },
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
