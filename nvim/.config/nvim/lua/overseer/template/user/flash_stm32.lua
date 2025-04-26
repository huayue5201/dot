-- 引入之前定义的模块（用于查找 ELF 文件）
local program_binary = require("utils.program_binary")

return {
	name = "Load Date",
	builder = function()
		-- 获取 ELF 文件
		local elf_file = program_binary.safe_get_program_binary()

		return {
			cmd = { "openocd" },
			args = {
				"-f",
				"interface/stlink.cfg",
				"-f",
				"target/stm32f1x.cfg",
				"-c",
				"program " .. elf_file .. " verify reset exit", -- 使用动态 ELF 文件
			},
			components = {
				{ "on_output_quickfix", set_diagnostics = false, open = true },
				"default",
			},
		}
	end,
	condition = {
		filetype = { "c", "cpp" }, -- 适用 C/C++ 文件类型
	},
}
