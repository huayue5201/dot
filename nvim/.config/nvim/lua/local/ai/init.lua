-- lua/local/ai/init.lua
---@brief 「在 nvim 里写问题，连同当前锚点发给外部 AI agent」的入口。
--
-- 结构：
--   context.lua   采集锚点（cwd/tab/文件:行/选区）—— 不认识 agent
--   message.lua   渲染成最终文本 —— 所有后端共用同一种格式
--   ui.lua        浮窗输入 —— 不认识 agent
--   backends/*    只负责「把文本送出去」：pi 是 unix socket，generic 是 tmux/命令
--
-- 加一个新 agent：写 lua/local/ai/backends/<name>.lua 实现 { id, label, targets(), send() }，
-- 或者直接用 backends/generic.lua 的 tmux() 工厂在 setup 里声明（限定：投递给已存在的进程）。
-- 两种方式都不需要改本文件。

local backends = require("local.ai.backends")
local generic = require("local.ai.backends.generic")
local context = require("local.ai.context")
local message = require("local.ai.message")
local ui = require("local.ai.ui")

local M = {}

--- 当前默认后端 id
local current = "pi"
--- 匹配宽松度：exact（默认，只认 cwd 相同）/ related（允许父子目录）/ single（只有一个就用）
local matching = "exact"
--- 手动 pin 的目标（:AiTarget），比 cwd 匹配优先
local pinned = nil

local function pick_opts()
	return {
		related = matching == "related" or matching == "single",
		single = matching == "single",
	}
end

--- 解析「后端 + 目标」。两端任一不可用就返回错误，让调用方在开窗之前就失败
---@param id string|nil
---@param target_id string|nil
---@return table|nil mod, table|nil target, string|nil err
local function resolve(id, target_id)
	local mod = backends.get(id or current)
	if not mod then
		return nil, nil, ("没有注册名为 %s 的后端"):format(id or current)
	end
	-- 显式选中一个被托管的实例（如 codecompanion 里的 pi）：允许，但先讲清后果
	local function note_avoid(t)
		if t and t.avoid then
			vim.notify(("[%s] %s"):format(mod.label or mod.id, t.avoid), vim.log.levels.WARN)
		end
	end
	if target_id then
		for _, t in ipairs(mod.targets()) do
			if tostring(t.id) == target_id then
				note_avoid(t)
				return mod, t
			end
		end
		return nil,
			nil,
			("目标 %s 不在 %s 的当前实例里（可能已退出）"):format(target_id, mod.label or mod.id)
	end
	-- 手动 pin 优先：pin 的目标失效就当没有 pin
	if pinned and pinned.backend == mod.id then
		for _, t in ipairs(mod.targets()) do
			if tostring(t.id) == tostring(pinned.target) then
				note_avoid(t)
				return mod, t
			end
		end
		pinned = nil
	end
	local target, err = backends.pick(mod, vim.fn.getcwd(), pick_opts())
	if not target then
		return nil, nil, err
	end
	return mod, target
end

--- 交互式选目标：pin > 唯一候选（直接发）> 弹选择器。
--- 同一个 cwd 下同时有终端 pi 和 codecompanion 里的 pi 时就是靠这里区分。
---@param mod table
---@param cb fun(target: table|nil)
local function choose_target(mod, cb)
	local function note_avoid(t)
		if t and t.avoid then
			vim.notify(("[%s] %s"):format(mod.label or mod.id, t.avoid), vim.log.levels.WARN)
		end
	end
	if pinned and pinned.backend == mod.id then
		for _, t in ipairs(mod.targets()) do
			if tostring(t.id) == tostring(pinned.target) then
				note_avoid(t)
				return cb(t)
			end
		end
		pinned = nil -- 目标已退出，pin 自然失效
	end

	local cands = backends.candidates(mod, vim.fn.getcwd(), pick_opts())
	if #cands == 0 then
		local _, reason = backends.status(mod)
		vim.notify(("[%s] %s"):format(mod.label or mod.id, reason or "没有可用实例"), vim.log.levels.WARN)
		return cb(nil)
	end
	if #cands == 1 and cands[1].tier == 1 and not cands[1].target.avoid then
		return cb(cands[1].target)
	end

	vim.ui.select(cands, {
		prompt = ("发到哪个 %s？（:AiTarget 可记住选择）"):format(mod.label or mod.id),
		format_item = function(c)
			local t = c.target
			local parts = { t.label or t.id, vim.fn.fnamemodify(t.cwd or "?", ":~") }
			if c.tier > 1 then
				table.insert(parts, "(不在当前项目)")
			end
			if t.avoid then
				table.insert(parts, "— 回复只到它的宿主 UI，不回 nvim")
			end
			return table.concat(parts, "  ")
		end,
	}, function(c)
		if not c then
			return cb(nil) -- 取消：什么都不做
		end
		note_avoid(c.target)
		cb(c.target)
	end)
end

--- 直接把一段文本发给当前后端（供别的命令/插件复用，不经过浮窗）
---@param text string
---@param opts { backend?: string, target?: string }|nil
---@return boolean ok, string? err
function M.send(text, opts)
	local mod, target, err = resolve(opts and opts.backend, opts and opts.target)
	if not mod then
		return false, err
	end
	local ok, send_err = mod.send(target, text)
	if not ok then
		return false, send_err
	end
	return true, nil
end

--- 打开浮窗提问。opts.visual=true 时带上当前选区
---@param opts { visual?: boolean, backend?: string }|nil
function M.ask(opts)
	opts = opts or {}
	local mod = backends.get(opts.backend or current)
	if not mod then
		vim.notify(("[ai] 没有注册名为 %s 的后端"):format(opts.backend or current), vim.log.levels.WARN)
		return
	end
	-- 锚点必须在任何 UI 之前取：选择器/浮窗都会改变当前窗口
	local anchor = context.capture(opts.visual)
	choose_target(mod, function(target)
		if not target then
			return
		end
		ui.input({
			title = ("问 %s（%s）· %s"):format(mod.label, target.label or "?", context.describe(anchor)),
			on_submit = function(prompt)
				local ok, send_err = mod.send(target, message.render(anchor, prompt))
				if not ok then
					vim.notify(("[%s] %s"):format(mod.label, send_err), vim.log.levels.WARN)
					return
				end
				local where = target.cwd and vim.fn.fnamemodify(target.cwd, ":~") or "?"
				vim.notify(
					("[%s] 已发送 → %s (%s)"):format(mod.label, target.label or "?", where),
					vim.log.levels.INFO
				)
			end,
		})
	end)
end

--- 切换默认后端
---@param id string
---@return boolean ok, string? err
function M.use(id)
	if not backends.get(id) then
		return false, ("没有注册名为 %s 的后端"):format(id)
	end
	current = id
	return true
end

---@return string
function M.current()
	return current
end

---@return table[]
function M.list()
	return backends.list()
end

--- 列出当前后端的候选目标
---@param id string|nil
---@return table[]
function M.targets(id)
	local mod = backends.get(id or current)
	if not mod then
		return {}
	end
	local ok, list = pcall(mod.targets)
	return ok and list or {}
end

--- 手动指定/清除目标（:AiTarget / :AiTarget!）。比 cwd 匹配优先
---@param target_id string|nil nil = 清除
---@return boolean ok, string? err
function M.pin(target_id)
	if not target_id then
		pinned = nil
		return true
	end
	local mod, target, err = resolve(current, target_id)
	if not target then
		return false, err
	end
	pinned = { backend = mod.id, target = target.id }
	return true
end

---@return { backend: string, target: string }|nil
function M.pinned()
	return pinned
end

--- 现成的后端工厂（tmux），方便在 setup 里几行声明新 agent
M.generic = generic

--- 注册后端 + 装命令和快捷键
---@param opts { default?: string, extra?: table[], matching?: string }|nil
function M.setup(opts)
	opts = opts or {}
	matching = opts.matching or "exact"
	backends.register(require("local.ai.backends.pi"))
	for _, mod in ipairs(opts.extra or {}) do
		backends.register(mod)
	end
	current = opts.default or "pi"

	vim.api.nvim_create_user_command("AiAsk", function()
		M.ask()
	end, { desc = "AI: 浮窗写问题，连同锚点发给当前后端" })
	vim.api.nvim_create_user_command("AiAskVisual", function()
		M.ask({ visual = true })
	end, { desc = "AI: 同 AiAsk，并带上当前选区" })
	-- 兼容旧名字
	vim.api.nvim_create_user_command("PiAsk", function()
		M.ask()
	end, { desc = "同 :AiAsk（旧名）" })
	vim.api.nvim_create_user_command("AiBackend", function(args)
		if args.args ~= "" then
			local ok, err = M.use(args.args)
			if not ok then
				vim.notify("[ai] " .. err, vim.log.levels.WARN)
			else
				vim.notify("[ai] 当前后端 → " .. args.args, vim.log.levels.INFO)
			end
			return
		end
		local items = M.list()
		vim.ui.select(items, {
			prompt = "AI 后端（当前：" .. current .. "）",
			format_item = function(item)
				return ("%s%s"):format(item.label, item.available and "" or "（不可用）")
			end,
		}, function(item)
			if item then
				M.use(item.id)
			end
		end)
	end, {
		nargs = "?",
		complete = function()
			local out = {}
			for _, item in ipairs(M.list()) do
				table.insert(out, item.id)
			end
			return out
		end,
		desc = "AI: 选择/切换默认后端",
	})

	vim.api.nvim_create_user_command("AiTarget", function(args)
		if args.bang then
			M.pin(nil)
			vim.notify("[ai] 已清除手动指定的目标", vim.log.levels.INFO)
			return
		end
		local items = M.targets()
		if args.args ~= "" then
			local ok, err = M.pin(args.args)
			if not ok then
				vim.notify("[ai] " .. err, vim.log.levels.WARN)
			else
				vim.notify("[ai] 目标固定为 " .. args.args, vim.log.levels.INFO)
			end
			return
		end
		if #items == 0 then
			vim.notify("[ai] 当前后端没有可用目标", vim.log.levels.WARN)
			return
		end
		vim.ui.select(items, {
			prompt = "固定发往哪个目标（:AiTarget! 取消）",
			format_item = function(item)
				return ("%s  %s"):format(item.label or item.id, item.cwd or "?")
			end,
		}, function(item)
			if item then
				M.pin(tostring(item.id))
			end
		end)
	end, { nargs = "?", bang = true, desc = "AI: 手动指定/清除提交通道的目标" })

	vim.keymap.set("n", "<leader>aq", function()
		M.ask()
	end, { desc = "AI: 问当前后端（光标锚点）" })
	vim.keymap.set("v", "<leader>aq", function()
		M.ask({ visual = true })
	end, { desc = "AI: 问当前后端（选区锚点）" })
end

return M
