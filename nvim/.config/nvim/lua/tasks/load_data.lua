return {
	name = "Load Date",
	label = "Load Date (make + openocd)",
	project_type = "make",
	run = function()
		local run_job = require("utils.neotask").run_job
		return run_job("make", {
			on_exit = function(_, code)
				if code ~= 0 then
					vim.notify("❌ make 构建失败，终止 Load Date", vim.log.levels.ERROR)
					return
				end
				local program_binary = require("utils.program_binary")
				local elf_file = program_binary.safe_get_program_binary("elf")
				if not elf_file or elf_file == "" then
					vim.notify("找不到 ELF 文件，终止 Load Date", vim.log.levels.ERROR)
					return
				end
				local openocd_cmd = {
					"openocd",
					"-f",
					"interface/stlink.cfg",
					"-f",
					"target/stm32f1x.cfg",
					"-c",
					"program " .. elf_file .. " verify reset exit",
				}
				run_job(openocd_cmd, {
					on_exit = function(_, ocd_code)
						if ocd_code == 0 then
							vim.notify("✔️ Load Date 任务完成", vim.log.levels.INFO)
						else
							vim.notify("❌ Load Date 任务失败", vim.log.levels.ERROR)
						end
					end,
				})
			end,
		})
	end,
}
