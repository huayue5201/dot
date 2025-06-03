-- lua/tasks/make.lua

return {
	name = "Make",
	label = "make",
	project_type = "make",
	run = function()
		local run_job = require("utils.neotask").run_job
		return run_job("make", {
			on_exit = function(_, code)
				if code == 0 then
					vim.notify("✔️ make 构建成功", vim.log.levels.INFO)
				else
					vim.notify("❌ make 构建失败，请查看 Quickfix", vim.log.levels.ERROR)
				end
			end,
		})
	end,
}
