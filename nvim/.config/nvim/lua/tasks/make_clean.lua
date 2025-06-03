return {
	name = "Make Clean",
	label = "make clean",
	project_type = "make",
	run = function()
		local run_job = require("utils.neotask").run_job
		return run_job("make clean", {
			on_exit = function(_, code)
				if code == 0 then
					vim.notify("✔️ clean 成功", vim.log.levels.INFO)
				else
					vim.notify("❌ clean 失败", vim.log.levels.ERROR)
				end
			end,
		})
	end,
}
