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

		-- 只在 Lua buffer 中出现：这是启动 osv 服务端，不是通用调试动作，
		-- 因此不放 <leader>d 命名空间（避免在 rust/c 等文件里制造噪音）。
		require("dap_ext.ft_keys").map("<leader>rl", function()
			require("osv").launch({ port = 8086 })
		end, { filetypes = { "lua" }, desc = "[R]un [L]ua: 启动 osv（Lua 调试服务端）" })
	end,
}
