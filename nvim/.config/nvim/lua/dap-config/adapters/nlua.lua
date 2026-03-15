return {
	setup = function(dap)
		dap.adapters.nlua = function(callback, conf)
			local adapter = {
				type = "server",
				host = conf.host or "127.0.0.1",
				port = conf.port or 8086,
			}

			if conf.start_neovim then
				-- 直接启动调试服务器
				require("osv").launch({
					port = adapter.port,
					host = adapter.host,
				})
			end

			callback(adapter)
		end

		dap.configurations.lua = {
			{
				type = "nlua",
				request = "attach",
				name = "Run this file",
				start_neovim = {}, -- 这会触发上面的 start_neovim 逻辑
			},
			{
				type = "nlua",
				request = "attach",
				name = "Attach to running Neovim instance (port = 8086)",
				port = 8086,
			},
		}

		vim.keymap.set("n", "<leader>dl", function()
			require("osv").launch({ port = 8086 })
		end, { noremap = true, desc = "启动lua dap服务器" })
	end,
}
