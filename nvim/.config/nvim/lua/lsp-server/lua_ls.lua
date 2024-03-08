local M = {}

M.setupLuaLs = function()
	require("lspconfig").lua_ls.setup({
		settings = {
			Lua = {
				runtime = {
					version = "LuaJIT",
				},
				diagnostics = {
					globals = { "vim" },
				},
				workspace = {
					library = vim.api.nvim_get_runtime_file("", true),
				},
				telemetry = {
					enable = false,
				},
				hint = {
					enable = true,
				},
				format = {
					enable = false,
				},
			},
		},
	})
end

return M
