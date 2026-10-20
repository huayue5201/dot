-- lua/lsp-config/features/hover_scroll.lua
---@brief 不进入浮窗就能滚动 LSP hover 内容
--
-- neovim 的 hover 浮窗（`vim.lsp.buf.hover` → `vim.lsp.util.open_floating_preview`）
-- 是 `api.nvim_open_win(buf, false, opts)` 打开的（runtime/lua/vim/lsp/util.lua:1659），
-- 焦点留在源码窗口，所以普通滚动键滚的是代码而不是浮窗；浮窗本身只在 buffer 上绑了
-- 一个 `q -> bdelete`（util.lua:1668-1675）。
--
-- 内置的替代路径是"再按一次 K"：hover 设了 `focus_id = 'textDocument/hover'`，
-- 第二次调用会 `nvim_set_current_win` 进到同一个浮窗（util.lua:1604-1618），
-- 之后光标在浮窗里，C-d/C-u 等原生滚动即可。但那等于"进入弹窗"。
--
-- 这里做的是不进入版本：浮窗 winid 缓存在源码 buffer 的 `vim.b[buf].lsp_floating_preview`
-- （util.lua:1687），拿到后在本窗口用 `nvim_win_call` 把滚动命令送进去。
--
-- 注意：映射**不能**用 expr 映射——expr 回调运行在 textlock 里，里面调用 `:normal`
-- 会报 `E523: Not allowed here`。所以用普通映射 + 无 hover 时 `:normal!` 补回原生行为。
local M = {}

-- 值都是按键本身（控制字符），`:normal!` 需要的是这种，不是 <C-d> 写法。
--   scroll = hover 浮窗里的滚动键（<C-e>/<C-y> = 内容上下滚一行）
--   native = 没有 hover 时补回的原生按键
local KEYS = {
	["<C-n>"] = { scroll = "\5", native = "\14" }, -- <C-n> 原生 = 下移一行
	["<C-p>"] = { scroll = "\25", native = "\16" }, -- <C-p> 原生 = 上移一行
	["<C-d>"] = { scroll = "\4", native = "\4" },
	["<C-u>"] = { scroll = "\21", native = "\21" },
}

--- 当前 buffer 上是否开着 LSP hover 浮窗
---@param buf integer
---@return integer|nil
local function hover_win(buf)
	local win = vim.b[buf].lsp_floating_preview
	if type(win) ~= "number" or not vim.api.nvim_win_is_valid(win) then
		return nil
	end
	-- 只认浮窗，防止变量残留时误滚普通窗口
	if vim.api.nvim_win_get_config(win).relative == "" then
		return nil
	end
	return win
end

function M.setup()
	for lhs, keys in pairs(KEYS) do
		vim.keymap.set("n", lhs, function()
			local win = hover_win(0)
			if not win then
				vim.cmd.normal({ args = { keys.native }, bang = true })
				return
			end
			vim.api.nvim_win_call(win, function()
				vim.cmd.normal({ args = { keys.scroll }, bang = true })
			end)
		end, { silent = true, desc = "滚动 LSP 悬停窗" })
	end
end

return M
