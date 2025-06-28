return {
	label = "Load Date (make + openocd)",
	project_type = "make",
	steps = {
		{
			label = "构建项目",
			cmd = { "make" },
			on_complete = function(output)
				vim.notify("✔️ make 构建成功", vim.log.levels.INFO)
			end,
			on_fail = function(output)
				vim.notify("❌ make 构建失败，终止 Load Date", vim.log.levels.ERROR)
			end,
		},
		{
			label = "加载程序",
			cmd = function()
				local program_binary = require("utils.program_binary")
				local binary_file = program_binary.safe_get_program_binary("elf")

				if not binary_file or binary_file == "" then
					vim.notify("找不到 ELF 文件，终止 Load Date", vim.log.levels.ERROR)
					return {} -- 返回空命令表示跳过此步骤
				end

				local openocd_template = vim.g.selected_chip_config.openocd_template
				local openocd_cmd = openocd_template:gsub("{binary_file}", binary_file)

				-- 将命令字符串拆分为表
				local cmd_parts = {}
				for word in openocd_cmd:gmatch("%S+") do
					table.insert(cmd_parts, word)
				end

				return cmd_parts
			end,
			on_complete = function(output)
				vim.notify("✔️ Load Date 任务完成", vim.log.levels.INFO)
			end,
			on_fail = function(output)
				vim.notify("❌ Load Date 任务失败", vim.log.levels.ERROR)
			end,
		},
	},
}
