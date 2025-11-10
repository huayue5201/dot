local registry = require("env.registry")

registry.register_env("nrf52", {
	name = "nRF52833",
	type = "chip",

	svdFile = os.getenv("HOME") .. "/MCU-Project/cmsis-svd-data/data/STMicro/nrf52.svd",
	configFiles = { "interface/cmsis-dap.cfg", "target/nrf52.cfg" },

	detect = function()
		if vim.fn.filereadable("platformio.ini") == 1 then
			local content = table.concat(vim.fn.readfile("platformio.ini"), "\n")
			if content:match("nrf52") then
				return "nrf52"
			end
		end
	end,

	apply = function()
		vim.notify("nRF52833 环境已激活", vim.log.levels.INFO)
	end,
})
