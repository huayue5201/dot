-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	keys = {
		{ "<leader>or", desc = "Run overseer" },
		{ "<leader>ot", desc = "Overseer任务列表" },
	},
	config = function()
		local overseer = require("overseer")
		overseer.setup({
			templates = { "builtin", "user" }, -- 添加自定义模板
		})
		overseer.run_template({ name = "npm serve", autostart = false }, function(task)
			if task then
				task:add_component({
					"dependencies",
					task_names = {
						"npm build",
						-- You can also pass in params to the task
						{ "shell", cmd = "sleep 10" },
					},
					sequential = true,
				})
				task:start()
			end
		end)

		vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Run overseer" })
		vim.keymap.set("n", "<leader>ot", "<cmd>OverseerToggle<cr>", { desc = "Overseer任务列表" })
	end,
}
