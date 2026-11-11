-- 把「dap 的终端不是普通 shell 终端」这条插件知识注册给 tab_terminal。
--
-- 终端模块（tab-terminal.nvim 的 lua/tab_terminal/foreign.lua）只认通用判据（filetype / winfixbuf），
-- 不硬编码任何插件；dap 专属的识别放在这里，两边保持解耦：
--   * nvim-dap 的集成终端 buffer 名是 "[dap-terminal] <name>"
--   * nvim-dap-view 的 console 窗口带 vim.w.dapview_win_term
--
-- 注意时序：nvim-dap 是在 termopen 之后才设名字（dap/session.lua:285），
-- dap-view 也是之后才设 ft / 窗口变量（console/view.lua:211,230）。
-- tab_terminal 的收编判定本身就是延迟一拍的，所以这里按「最终状态」判断即可。

local foreign = require("tab_terminal.foreign")

local M = {}

local registered = false

function M.setup()
	if registered then
		return
	end
	registered = true

	foreign.register({
		name = "dap-terminal-name",
		desc = "nvim-dap 的集成终端（[dap-terminal] …）",
		match = function(ctx)
			return ctx.buftype == "terminal" and ctx.name:find("%[dap%-") ~= nil
		end,
	})

	foreign.register({
		name = "dap-view-term-win",
		desc = "显示在 nvim-dap-view 的 console 窗口里",
		match = function(ctx)
			for _, win in ipairs(ctx.wins) do
				if vim.w[win].dapview_win_term then
					return true
				end
			end
			return false
		end,
	})
end

return M
