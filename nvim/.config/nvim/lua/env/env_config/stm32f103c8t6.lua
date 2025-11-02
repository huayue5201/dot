local registry = require("env.registry")

registry.register_env("stm32f103c8t6", {
	name = "STM32F103C8",
	type = "chip",

	svdFile = "/Users/lijia/MCU-Project/cmsis-svd-data/data/STMicro/STM32F103xx.svd",
	openocd_template = "openocd -f interface/stlink.cfg -f target/stm32f1x.cfg -c 'program {binary_file} verify reset exit'",
	probe = "0483:3752:066AFF494982654867254648",
	configFiles = { "interface/stlink.cfg", "target/stm32f1x.cfg" },

	detect = function()
		if vim.fn.filereadable("Makefile") == 1 then
			local content = table.concat(vim.fn.readfile("Makefile"), "\n")
			if content:match("STM32F103") then
				return "stm32f103c8t6"
			end
		end
	end,

	apply = function()
		vim.notify("STM32F103C8 环境已激活", vim.log.levels.INFO)
	end,
})
