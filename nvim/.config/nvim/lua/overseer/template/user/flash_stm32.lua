local program_binary = require("utils.program_binary")

return {
	name = "Load Date",
	builder = function()
		-- 先执行 make 命令
		local make_result = vim.fn.system("make")

		-- 检查 make 是否成功
		if vim.v.shell_error ~= 0 then
			-- 如果 make 执行失败，返回错误
			return {
				status = "FAILURE",
				result = make_result,
			}
		end

		-- 获取 ELF 文件路径
		local elf_file = program_binary.safe_get_program_binary()

		-- 返回 openocd 命令
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
