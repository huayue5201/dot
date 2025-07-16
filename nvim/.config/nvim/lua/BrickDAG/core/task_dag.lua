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

--- 获取任务执行层级（用于并行分组）
--- @return table[] 按执行层级分组的任务列表
function TaskDAG:get_execution_levels()
	local indegree = self:calculate_indegrees()
	local levels = {}
	local current_level = 1
	levels[current_level] = {}

	-- 初始化：入度为0的节点加入第一层
	for node_id, deg in pairs(indegree) do
		if deg == 0 then
			table.insert(levels[current_level], {
				id = node_id,
				task = self:get_task(node_id),
			})
		end
	end

	-- 层级遍历
	while #levels[current_level] > 0 do
		levels[current_level + 1] = {}

		-- 处理当前层级的每个任务
		for _, task_info in ipairs(levels[current_level]) do
			local node_id = task_info.id

			-- 更新后继节点的入度
			if self.reverse_edges[node_id] then
				for successor in pairs(self.reverse_edges[node_id]) do
					indegree[successor] = indegree[successor] - 1

					-- 入度为0的任务加入下一层
					if indegree[successor] == 0 then
						table.insert(levels[current_level + 1], {
							id = successor,
							task = self:get_task(successor),
						})
					end
				end
			end
		end

		current_level = current_level + 1
	end

	-- 移除空的最后一层
	if #levels[current_level] == 0 then
		levels[current_level] = nil
	end

	return levels
end

--- 计算所有节点的入度
--- @return table<string, number> 节点ID到入度的映射
function TaskDAG:calculate_indegrees()
	local in_degree = {}

	-- 初始化所有节点入度为0
	for node_id in pairs(self.nodes) do
		in_degree[node_id] = 0
	end

	-- 计算实际入度
	for _, deps in pairs(self.edges) do
		for dep_id in pairs(deps) do
			in_degree[dep_id] = (in_degree[dep_id] or 0) + 1
		end
	end

	return in_degree
end

return TaskDAG
