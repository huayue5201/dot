-- lua/dap_ext/prompt.lua
---@brief 可取消的命令行输入
--
-- vim.fn.input(prompt, text, completion) 在用户按 <Esc>/<C-c> 时会返回
-- {text}（给了默认值时）或空串，调用方无法区分「取消」和「确认」，于是按
-- Esc 依然会带着默认值继续启动调试。
--
-- 这里改用 input({opts}) 的 dict 形式 + 哨兵 cancelreturn，把「取消」映射成
-- nil；调用方拿到 nil 时返回 dap.ABORT 即可让 nvim-dap 干净地中止本次运行。
local M = {}

-- 不可能被用户正常输入的值（Ctrl-A）
local SENTINEL = "\1"

---读取一行输入；用户取消（Esc / Ctrl-C）时返回 nil
---@param prompt string
---@param default? string
---@param completion? string|fun(...): any
---@return string|nil
function M.input(prompt, default, completion)
	local opts = {
		prompt = prompt,
		default = default or "",
		cancelreturn = SENTINEL,
	}
	if completion ~= nil then
		opts.completion = completion
	end

	local ok, value = pcall(vim.fn.input, opts)
	if not ok or value == SENTINEL then
		return nil
	end
	return value
end

return M
