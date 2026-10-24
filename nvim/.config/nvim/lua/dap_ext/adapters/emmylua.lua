-- https://github.com/EmmyLuaLs/emmylua_dap
-- Lua 调试器（配合 emmy_core，调试独立 Lua 程序，非 Neovim 本身）
--
-- 使用方法：
--   1. 在目标 Lua 程序里 require emmy_core 并 tcpListen（见 README）
--   2. 运行 Lua 程序
--   3. 在 Neovim 里 :DapContinue 选择 "EmmyLua Debug"

return {
	setup = function(dap)
		-- 优先使用 PATH 中的 emmylua_dap，否则用本地下载的二进制
		local emmylua_dap_path = vim.fn.expand("~/Downloads/bin/emmylua_dap")
		if vim.fn.executable("emmylua_dap") == 1 then
			emmylua_dap_path = "emmylua_dap"
		end

		dap.adapters.emmylua = {
			type = "executable",
			command = emmylua_dap_path,
			args = {},
		}

		-- 追加到已有的 lua 配置，避免覆盖 nlua 等
		dap.configurations.lua = dap.configurations.lua or {}
		table.insert(dap.configurations.lua, {
			type = "emmylua",
			request = "launch",
			name = "EmmyLua Debug",
			host = "localhost",
			port = 9966,
			sourcePaths = { vim.fn.getcwd() }, -- 源码根目录，按需修改
			ext = { ".lua", ".lua.txt", ".lua.bytes" },
			ideConnectDebugger = true,
		})
	end,
}
