-- lua/lsp-config/features/runnables.lua
-- run/debug 代码透镜的通用分发层。
--
-- 语言后端在 lua/lsp-config/features/runnables/<lang>.lua 里声明：
--   commands: { [LSP 命令名] = fun(command, bufnr) }  -- 点击透镜/执行命令时调用
--   keymaps:  { { lhs, fn(client, bufnr), desc } }     -- 该语言 buffer 的键位
-- 本模块只负责：按 client.name 找到后端、注册 vim.lsp.commands、挂 buffer 键位。
-- 展示/点击/hover 由 features/code_lens.lua 处理，与语言无关。

local M = {}

---@type table<string, { commands: table, keymaps: table[] }>
local providers = {}

---注册一个语言后端
---@param client_name string 与 vim.lsp.Client.name 一致
---@param provider table
function M.register(client_name, provider)
	providers[client_name] = provider
end

local registered = false
local function register_commands()
	if registered then
		return
	end
	registered = true
	for _, provider in pairs(providers) do
		for cmd, handler in pairs(provider.commands or {}) do
			vim.lsp.commands[cmd] = function(command)
				handler(command, vim.api.nvim_get_current_buf())
			end
		end
	end
end

---@param client vim.lsp.Client
---@param bufnr integer
function M.setup(client, bufnr)
	local provider = providers[client.name]
	if not provider then
		return
	end
	register_commands()
	local opts = { buffer = bufnr, noremap = true, silent = true }
	for _, k in ipairs(provider.keymaps or {}) do
		vim.keymap.set("n", k.lhs, function()
			k.fn(client, bufnr)
		end, vim.tbl_extend("force", opts, { desc = k.desc }))
	end
end

M.register("rust-analyzer", require("lsp-config.features.runnables.rust"))

return M
