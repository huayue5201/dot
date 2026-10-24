-- lua/feat/unsaved.lua
-- 「未保存 buffer」的公共查询：忽略规则 + 列表。
-- 由 statusline.save_status() 与 feat.save_panel 共用，避免两处各维护一份 ignore。
local M = {}

-- 需要忽略的缓冲区（沿用 statusline 原有规则）
M.ignore = {
	filetype = {
		"dap",
		"fugitive",
		"terminal",
		"log",
		"help",
		"dapui-scopes",
		"dapui-stacks",
		"dapui-breakpoints",
		"dapui-watches",
		"dap-repl",
		"dapui-console",
		"snacks_picker_input",
		"pager",
		"msgmore",
		"*.todo.md", -- 注：此处为精确匹配，glob 实际不生效（保留原样）
		"neo-tree-popup",
	},
	buftype = {
		"terminal",
		"nofile",
		"quickfix",
		"qf",
	},
	bufname = {
		"dap-terminal",
		-- otter.nvim 为 markdown 代码块建的影子 buffer（.otter.rs / .otter.py / .otter.lua），
		-- 内容是嵌入代码的副本，永远 modified，不能算进「未保存」
		"%.otter%.[%w]+$",
	},
}

---@param buf integer
---@return boolean
function M.ignored(buf)
	local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
	if vim.list_contains(M.ignore.filetype, ft) then
		return true
	end

	local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
	if vim.list_contains(M.ignore.buftype, bt) then
		return true
	end

	local name = vim.fn.bufname(buf)
	for _, pat in ipairs(M.ignore.bufname) do
		if name:match(pat) then
			return true
		end
	end

	return false
end

--- 未保存的 buffer 列表。
--- writable = 能安全 `:write`（有名字且非特殊 buftype）；面板只用 writable 的，
--- statusline 计数则与旧逻辑一致（不过滤 writable）。
---@return { buf: integer, name: string, ft: string, writable: boolean }[]
function M.list()
	local out = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_get_option_value("modified", { buf = buf }) and not M.ignored(buf) then
			local name = vim.fn.bufname(buf)
			local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
			out[#out + 1] = {
				buf = buf,
				name = name,
				ft = vim.api.nvim_get_option_value("filetype", { buf = buf }),
				writable = name ~= "" and bt == "",
			}
		end
	end
	return out
end

---@return integer
function M.count()
	return #M.list()
end

return M
