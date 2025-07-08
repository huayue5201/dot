-- core/task_dag.lua
local TaskDAG = {}
TaskDAG.__index = TaskDAG

function TaskDAG.new()
	local self = setmetatable({}, TaskDAG)
	self.nodes = {} -- 任务节点 (task_id => task)
	self.edges = {} -- 依赖关系 (task_id => {dep_id => true})
	self.reverse_edges = {} -- 反向依赖 (dep_id => {task_id => true})
	return self
end

-- 添加任务节点
--- @param task table 任务配置
--- @param parent_prefix string? 父任务前缀
--- @return string 任务ID
function TaskDAG:add_task(task, parent_prefix)
	assert(task.name, "Task must have a name")
	local id = parent_prefix and (parent_prefix .. "/" .. task.name) or task.name

	-- 避免重复添加
	if self.nodes[id] then
		return id
	end

	-- 添加节点
	self.nodes[id] = task
	self.edges[id] = {}
	self.reverse_edges[id] = self.reverse_edges[id] or {}

	-- 添加依赖
	if task.deps then
		for _, dep in ipairs(task.deps) do
			local dep_id = parent_prefix and (parent_prefix .. "/" .. dep) or dep

			-- 确保依赖节点存在
			if not self.nodes[dep_id] then
				self:add_task({ name = dep_id }, parent_prefix)
			end

			-- 添加边
			self.edges[id][dep_id] = true
			self.reverse_edges[dep_id] = self.reverse_edges[dep_id] or {}
			self.reverse_edges[dep_id][id] = true
		end
	end

	return id
end

-- 拓扑排序 (Kahn算法)
--- @return string[] 排序后的任务ID列表
function TaskDAG:topo_sort()
	local sorted = {}
	local queue = {}
	local in_degree = {}

	-- 计算入度
	for node_id in pairs(self.nodes) do
		in_degree[node_id] = 0
	end

	for node_id, deps in pairs(self.edges) do
		for dep_id in pairs(deps) do
			in_degree[dep_id] = (in_degree[dep_id] or 0) + 1
		end
	end

	-- 找到所有入度为0的节点
	for node_id, deg in pairs(in_degree) do
		if deg == 0 then
			table.insert(queue, node_id)
		end
	end

	-- 处理队列
	while #queue > 0 do
		local node_id = table.remove(queue, 1)
		table.insert(sorted, node_id)

		-- 减少后继节点的入度
		for successor in pairs(self.reverse_edges[node_id] or {}) do
			in_degree[successor] = in_degree[successor] - 1
			if in_degree[successor] == 0 then
				table.insert(queue, successor)
			end
		end
	end

	-- 检查是否有环
	if #sorted < #self.nodes then
		local remaining = {}
		for node_id in pairs(self.nodes) do
			if not vim.tbl_contains(sorted, node_id) then
				table.insert(remaining, node_id)
			end
		end
		error("存在循环依赖: " .. table.concat(remaining, ", "))
	end

	return sorted
end

-- 获取任务
--- @param task_id string 任务ID
--- @return table? 任务配置
function TaskDAG:get_task(task_id)
	return self.nodes[task_id]
end

return TaskDAG
