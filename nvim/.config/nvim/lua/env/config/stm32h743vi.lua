local registry = require("env.registry")

registry.register_env("stm32h743vi", {
	name = "STM32H743VI",
	type = "chip",

	svdFile = os.getenv("HOME") .. "/MCU-Project/cmsis-svd-data/data/STMicro/STM32H743x.svd",
	openocd_template = "openocd -f interface/stlink.cfg -f target/stm32h7x.cfg -c 'program {binary_file} verify reset exit'",
	probe = "0483:3754:0032003E3532510A31333430",
	configFiles = { "interface/stlink.cfg", "target/stm32h7x.cfg" },

	detect = function()
		if vim.fn.filereadable("Makefile") == 1 then
			local content = table.concat(vim.fn.readfile("Makefile"), "\n")
			if content:match("STM32H743") then
				return "stm32h743vi"
			end
		end
	end,

	apply = function()
		vim.notify("STM32H743VI 环境已激活", vim.log.levels.INFO)
	end,
})
