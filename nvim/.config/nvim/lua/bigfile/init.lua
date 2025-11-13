local M = {}

M.autocmd = require("bigfile.autocmd")
M.info = require("bigfile.info")
M.state = require("bigfile.state") -- 导出状态管理，方便调试
local commands = require("bigfile.commands")

function M.setup(opts)
	opts = opts or {}
	M.autocmd.setup(opts)
	commands.setup_commands()
end

-- 添加手动状态检查命令（用于调试）
function M.get_state(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	return M.state.get_rule_state(buf, "size"),
		M.state.get_rule_state(buf, "lines"),
		M.state.get_rule_state(buf, "long_line")
end

return M
