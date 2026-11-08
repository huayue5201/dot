-- https://github.com/jbyuki/one-small-step-for-vimkind

return {
	setup = function(dap)
		dap.adapters.nlua = function(callback, config)
			callback({
				type = "server",
				host = config.host or "127.0.0.1",
				port = config.port or 8086,
			})
		end

		dap.configurations.lua = {
			{
				type = "nlua",
				request = "attach",
				name = "Attach to running Neovim instance",
			},
		}

		vim.keymap.set("n", "<leader>dR", function()
			require("osv").launch({ port = 8086 })
		end, { noremap = true, desc = "启动 osv" })
	end,
}
