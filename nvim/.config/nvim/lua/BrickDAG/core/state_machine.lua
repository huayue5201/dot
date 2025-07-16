-- core/state_machine.lua
local StateMachine = {}
StateMachine.__index = StateMachine

-- 状态常量
StateMachine.STATE_PENDING = "pending"
StateMachine.STATE_RUNNING = "running"
StateMachine.STATE_SUCCESS = "success"
StateMachine.STATE_FAILED = "failed"
StateMachine.STATE_SKIPPED = "skipped"

-- 状态转换表：当前状态 → 可转移状态集合
local valid_transitions = {
	[StateMachine.STATE_PENDING] = {
		[StateMachine.STATE_RUNNING] = true,
		[StateMachine.STATE_SKIPPED] = true,
	},
	[StateMachine.STATE_RUNNING] = {
		[StateMachine.STATE_SUCCESS] = true,
		[StateMachine.STATE_FAILED] = true,
		[StateMachine.STATE_SKIPPED] = true,
	},
	[StateMachine.STATE_SUCCESS] = {},
	[StateMachine.STATE_FAILED] = {},
	[StateMachine.STATE_SKIPPED] = {},
}

--- 创建状态机实例
--- @param initial_state string? 初始状态，默认 "pending"
--- @return StateMachine 实例
function StateMachine.new(initial_state)
	local self = setmetatable({}, StateMachine)
	self.state = initial_state or StateMachine.STATE_PENDING
	self.listeners = {}
	return self
end

--- 获取当前状态
function StateMachine:get_state()
	return self.state
end

--- 尝试转换状态
--- @param new_state string
--- @return boolean success, string? error_message
function StateMachine:transition(new_state)
	if not valid_transitions[self.state] or not valid_transitions[self.state][new_state] then
		return false, ("非法状态转换：%s → %s"):format(self.state, new_state)
	end

	local old_state = self.state
	self.state = new_state

	-- 通知监听器
	for _, callback in ipairs(self.listeners) do
		callback(old_state, new_state)
	end

	return true
end

--- 注册状态变化监听器
--- @param callback fun(old_state: string, new_state: string)
function StateMachine:on_state_change(callback)
	table.insert(self.listeners, callback)
end

--- 检查是否允许从当前状态转换到目标状态
--- @param new_state string
--- @return boolean
function StateMachine:can_transition(new_state)
	return valid_transitions[self.state] and valid_transitions[self.state][new_state] or false
end

--- 获取所有可能的状态转换
--- @return table
function StateMachine:get_possible_transitions()
	return valid_transitions[self.state] and vim.tbl_keys(valid_transitions[self.state]) or {}
end

return StateMachine
