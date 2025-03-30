local M = {}

M.icons = {
	diagnostic = {
		ERROR = "󰅚 ",
		WARN = "󰀪 ",
		HINT = " ",
		INFO = " ",
	},
}

M.close_commands = {
	help = ":close<cr>",
	qf = ":close<cr>",
	checkhealth = ":close<cr>",
	man = ":quit<cr>",
	toggleterm = ":close<cr>",
	["grug-far"] = ":bdelete<cr>",
	terminal = ":close<cr>",
	git = ":bdelete<cr>",
	["dap-repl"] = ":close<cr>",
	["dap-float"] = ":close<cr>",
	nofile = ":bdelete<cr>",
	["dap-view"] = ":DapViewClose!<cr>",
	["dap-view-term"] = ":close<cr>",
	acwrite = ":bdelete<cr>",
}

-- 查询 LSP 客户端是否支持指定的方法
-- @param buf number: 缓冲区 ID
-- @param methods table: 需要查询的 LSP 方法列表（如 { "textDocument/documentHighlight", "textDocument/foldingRange" }）
-- @return table: 一个键值对表，键是方法名，值是 `true` 或 `false`
function M.get_supported_lsp_methods(buf, methods)
	local supported_methods = {}
	local clients = vim.lsp.get_clients({ bufnr = buf })
	-- 初始化方法查询表
	for _, method in ipairs(methods) do
		supported_methods[method] = false
	end
	-- 遍历所有 LSP 客户端，查询是否支持指定的方法
	for _, client in ipairs(clients) do
		for _, method in ipairs(methods) do
			if client:supports_method(method) then
				supported_methods[method] = true
			end
		end
	end
	return supported_methods
end

return M
