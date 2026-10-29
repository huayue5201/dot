-- lua/local/ai/backends/init.lua
---@brief 后端注册表 + 通用「选目标」策略。
--
-- 一个后端模块只要实现三个字段：
--   id      string                                 唯一标识（:AiBackend 用它）
--   label   string                                 给人看的名字
--   targets fun(): table[]                         可用目标列表，空 = 不可用
--   send    fun(target, text): ok, err              把渲染好的文本丢过去
-- 可选：
--   available fun(): boolean, reason?               默认 = #targets() > 0
--
-- target 是后端自己的数据（pi 是 pid/sock/cwd，tmux 是 pane…），
-- 只要求有 cwd 字段（可为 nil）和 label 字段供选择/提示用。
-- 加新 agent = 写一个 lua/local/ai/backends/<name>.lua，或直接用 generic.lua 的
-- generic.tmux() 工厂三行造一个，不需要动这里的任何逻辑。
-- 只支持「投递给已存在的进程」；spawn/收 stdout/会话管理交给 codecompanion，不做第二遍。

local M = {}

---@type table<string, table>
local registry = {}
---@type string[]
local order = {}

--- 注册后端。同 id 覆盖（方便重载/测试）
---@param mod table
function M.register(mod)
	assert(type(mod) == "table" and type(mod.id) == "string", "backend 需要 id")
	assert(type(mod.targets) == "function", ("backend %s 缺 targets()"):format(mod.id))
	assert(type(mod.send) == "function", ("backend %s 缺 send()"):format(mod.id))
	if not registry[mod.id] then
		table.insert(order, mod.id)
	end
	registry[mod.id] = mod
end

---@param id string
---@return table|nil
function M.get(id)
	return registry[id]
end

--- 后端是否可用（统一的容错入口：available() 可返回 available, reason）
---@param mod table
---@return boolean available, string? reason
function M.status(mod)
	local ok, avail, reason = pcall(mod.available or function()
		return #mod.targets() > 0
	end)
	if not ok then
		return false, tostring(avail)
	end
	return avail and true or false, reason
end

--- 按注册顺序列出所有后端（含不可用的，附原因）
---@return { id: string, label: string, available: boolean, reason: string? }[]
function M.list()
	local out = {}
	for _, id in ipairs(order) do
		local mod = registry[id]
		local available, reason = M.status(mod)
		out[#out + 1] = {
			id = id,
			label = mod.label or id,
			available = available,
			reason = reason,
		}
	end
	return out
end

--- 列出候选目标（供交互式选择用），按「同 cwd > 同项目 > 其他；非托管 > 被托管」排序。
--- tier=1 表示 cwd 完全相同（严格档允许直接发的那种）
---@param mod table
---@param cwd string|nil
---@param opts { related?: boolean, single?: boolean }|nil
---@return table[] {{ target: table, tier: integer }}
function M.candidates(mod, cwd, opts)
	opts = opts or {}
	local function norm(p)
		if not p then
			return nil
		end
		return vim.uv.fs_realpath(p) or p
	end
	local ok, targets = pcall(mod.targets)
	if not ok then
		return {}
	end
	cwd = norm(cwd or vim.fn.getcwd())
	local out = {}
	for _, t in ipairs(targets or {}) do
		local tcwd = norm(t.cwd)
		local tier = 3 -- 其他项目
		if tcwd == cwd then
			tier = 1
		elseif tcwd and (cwd:sub(1, #tcwd) == tcwd or tcwd:sub(1, #cwd) == cwd) then
			tier = 2
		end
		table.insert(out, { target = t, tier = tier })
	end
	table.sort(out, function(a, b)
		if a.tier ~= b.tier then
			return a.tier < b.tier
		end
		local aa, bb = a.target.avoid ~= nil, b.target.avoid ~= nil
		if aa ~= bb then
			return not aa
		end
		return (a.target.ts or 0) > (b.target.ts or 0)
	end)
	return out
end

--- 选目标。默认**严格**：只有 cwd 相同（realpath 归一化后）才发，避免把问题投进
--- 另一个项目的 agent、污染它的上下文。宽松档需显式打开。
--- 带 `avoid` 字段的目标（如被 ACP 客户端托管的 pi）默认不参与匹配：
--- 它有自己的宿主 UI，消息有去无回，静默投进去只会让人以为"没反应"。
---@param mod table
---@param cwd string|nil
---@param opts { related?: boolean, single?: boolean }|nil related=允许父子目录，single=只有一个目标就用它
---@return table|nil target, string|nil err
function M.pick(mod, cwd, opts)
	opts = opts or {}
	-- 归一化路径：macOS 上 /tmp 与 /private/tmp、符号链接目录都会写成同一个 cwd
	local function norm(p)
		if not p then
			return nil
		end
		return vim.uv.fs_realpath(p) or p
	end
	cwd = norm(cwd or vim.fn.getcwd())
	local ok, targets = pcall(mod.targets)
	if not ok then
		return nil, ("%s 后端取目标失败：%s"):format(mod.label or mod.id, tostring(targets))
	end
	targets = targets or {}
	if #targets == 0 then
		local _, reason = M.status(mod)
		return nil, ("%s 不可用：%s"):format(mod.label or mod.id, reason or "没有可用实例")
	end

	local usable, skipped = {}, {}
	for _, t in ipairs(targets) do
		table.insert(t.avoid and skipped or usable, t)
	end
	targets = usable
	if #targets == 0 then
		local lines = {}
		for _, t in ipairs(skipped) do
			table.insert(lines, ("  %s  %s  ← %s"):format(t.label or t.id, t.cwd or "?", t.avoid))
		end
		return nil,
			("%s 只找到被跳过的实例：\n%s\n用那个宿主自己的输入框（如 codecompanion 的聊天窗），或用 :AiTarget 显式选中它。"):format(
				mod.label or mod.id,
				table.concat(lines, "\n")
			)
	end

	-- 1) cwd 完全一致（targets 已按活跃度降序，取第一个）
	for _, t in ipairs(targets) do
		if norm(t.cwd) == cwd then
			return t
		end
	end

	-- 2) 互为父子目录且唯一 —— 只在显式开启时才算（仓库根 vs 子目录这种场景）
	if opts.related then
		local related = {}
		for _, t in ipairs(targets) do
			local tcwd = norm(t.cwd)
			if tcwd and (cwd:sub(1, #tcwd) == tcwd or tcwd:sub(1, #cwd) == cwd) then
				table.insert(related, t)
			end
		end
		if #related == 1 then
			return related[1]
		end
	end

	-- 3) 只有一个目标 —— 同样只在显式开启时才用，否则就是在往别的项目里乱投
	if opts.single and #targets == 1 then
		return targets[1]
	end

	local names = {}
	for _, t in ipairs(targets) do
		table.insert(names, ("  %s  %s"):format(t.label or t.id, t.cwd or "?"))
	end
	for _, t in ipairs(skipped) do
		table.insert(names, ("  %s  %s  (已跳过：%s)"):format(t.label or t.id, t.cwd or "?", t.avoid))
	end
	return nil,
		("%s 没有对应 %s 的目标（用 :AiTarget 显式指定，或 :AiBackend 换后端）。现有：\n%s"):format(
			mod.label or mod.id,
			cwd,
			table.concat(names, "\n")
		)
end

return M
