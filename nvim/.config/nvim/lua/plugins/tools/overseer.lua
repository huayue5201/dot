-- https://github.com/stevearc/overseer.nvim
-- 任务框架：构建/测试/lint/一次性命令。常驻多服务由 procman 管（见 tools/procman.lua）。
-- 模板：builtin（make/npm/cargo/just/vscode tasks.json…）+ 本配置 lua/overseer/template/user/*
--       + 工作区声明的 w.task()（见 lua/feat/tab_workspace/local_settings.lua:251）。
-- dap = true 是 overseer 默认值（lua/overseer/config.lua:3），配合 nvim-dap 可一键调试任务。

return {
	"stevearc/overseer.nvim",
	config = function()
		require("overseer").setup({
			-- 交互式/长驻命令要 TTY；纯构建模板想省 buffer 可在 builder 里单独写 jobstart
			strategy = "terminal",
			task_list = {
				-- 左侧留给 neo-tree，任务列表放底部
				direction = "bottom",
				min_height = 10,
				max_height = 0.3,
				-- 默认键全部保留，只补高频动作（<CR> 仍是 action 菜单，? 看全部键位）
				keymaps = {
					["r"] = { "keymap.run_action", opts = { action = "restart" }, desc = "重启任务" },
					["x"] = { "keymap.run_action", opts = { action = "stop" }, desc = "停止任务" },
					["P"] = { "keymap.open", opts = { dir = "float" }, desc = "浮窗看输出" },
				},
			},
			-- 模板输入框 / 任务编辑框
			form = { border = "rounded" },
		})

		vim.keymap.set("n", "<leader>ru", "<cmd>OverseerRun<CR>", { desc = "运行任务（模板）" })
		vim.keymap.set("n", "<leader>rc", "<cmd>OverseerShell<CR>", { desc = "临时 shell 命令" })
		vim.keymap.set("n", "<leader>ro", "<cmd>OverseerToggle<CR>", { desc = "打开任务列表" })
		vim.keymap.set("n", "<leader>rb", "<cmd>OverseerTaskAction<CR>", { desc = "对任务执行操作" })

		-- :ProbeRsDetectChip / :ProbeRsChip（probe-rs 芯片自动识别与缓存）
		require("lib.probe_rs").setup()
		-- 手动从 probe-rs chip list 挑芯片（不依赖硬件识别）
		vim.keymap.set("n", "<leader>rC", "<cmd>ProbeRsPickChip<CR>", { desc = "probe-rs: 手动选择芯片" })
	end,
}
