return {
	label = "compiledb make",
	name = "compiledb make",
	project_type = "make",
	run = function()
		local run_job = require("utils.neotask").run_job
		return run_job({ "compiledb", "make" }, {
			on_exit = function(_, code)
				if code == 0 then
					vim.notify("✔️ compiledb make 执行成功", vim.log.levels.INFO)
				else
					vim.notify("❌ compiledb make 执行失败", vim.log.levels.ERROR)
				end
			end,
		})
	end,
}
