-- 创建一个名为 M 的模块
local M = {}

-- 设置 Lua LSP 的配置
M.setupLuaLs = function()
	require("lspconfig").lua_ls.setup({
		settings = {
			Lua = {
				runtime = {
					version = "LuaJIT", -- Lua 运行时版本
				},
				diagnostics = {
					globals = { "vim" }, -- 全局变量
				},
				workspace = {
					library = vim.api.nvim_get_runtime_file("", true), -- 工作区库
				},
				telemetry = {
					enable = false, -- 禁用遥测
				},
				hint = {
					enable = true, -- 启用提示
				},
				format = {
					enable = false, -- 禁用格式化
				},
			},
		},
	})
end

return M -- 返回模块 M
