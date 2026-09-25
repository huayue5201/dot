-- 导航模块聚合入口
-- 拆分为：settings（数据）、keymaps（数据）、errors（逻辑）、
-- smart_close（逻辑）、dispatch（分发器）
local M = {}

-- 数据
M.settings = require("user.navigation.settings")
M.buf_keymaps = require("user.navigation.keymaps")

-- 错误跳转
local errors = require("user.navigation.errors")
M.error_patterns = errors.error_patterns
M.get_error_lines = errors.get_error_lines
M.next_error = errors.next_error
M.prev_error = errors.prev_error
M.next_error_repeatable = errors.next_error_repeatable
M.prev_error_repeatable = errors.prev_error_repeatable
M._repeat_jump_callback = errors._repeat_jump_callback

-- 智能关闭
M.smart_close = require("user.navigation.smart_close").smart_close

-- 命令分发
M.dispatch_command = require("user.navigation.dispatch").dispatch_command

return M
