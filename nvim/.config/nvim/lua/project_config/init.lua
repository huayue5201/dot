-- lua/project_config/init.lua
local M = {}
local detect = require("project_config.detect")

function M.load(dap)
	local project = detect.detect()
	if not project then
		vim.notify("No project matched")
		return
	end

	-- 加载 DAP
	if project.dap then
		local ok, mod = pcall(require, "dap-config.adapters." .. project.dap)
		if ok then
			mod.setup(dap)
		end
	end

	-- 加载 LSP
	for _, lsp in ipairs(project.lsp or {}) do
		local ok, mod = pcall(require, "lsp." .. lsp)
		if ok then
			mod.setup()
		end
	end

	-- 设置环境变量
	for k, v in pairs(project.env or {}) do
		vim.fn.setenv(k, v)
	end

	vim.notify("Loaded project config: " .. project.name)
end

return M
