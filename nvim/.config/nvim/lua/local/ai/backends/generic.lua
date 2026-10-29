-- lua/local/ai/backends/generic.lua
---@brief 通用后端工厂：以后接 opencode / claude code / codex 之类，
-- 只要它已经在某个 tmux pane 里跑着，就能几行声明出来，不用写新文件、更不用动 ai/ 的结构。
--
--   local ai = require("local.ai")
--   local generic = ai.generic   -- 或 require("local.ai.backends.generic")
--   ai.setup({
--     default = "pi",
--     extra = {
--       generic.tmux({ id = "opencode", label = "opencode", panes = generic.tmux_panes_by_cmd("opencode") }),
--       generic.tmux({ id = "claude", label = "claude", panes = generic.tmux_panes_by_cmd("claude") }),
--     },
--   })
--
-- 刻意只做「投递给已存在的进程」这一种传输。spawn 子进程、收 stdout、回显、会话管理
-- 一律不在这里实现 —— 那是 codecompanion（含 ACP 适配器）的活儿，不要重复造。

local M = {}

--- 通用后端：把文本 + 回车打进 tmux pane。
-- 用 load-buffer/paste-buffer 而不是 send-keys 打字，避免多行文本被当成多个 Enter、
-- 也避免 shell/引号转义问题。
---@param opts { id: string, label: string, panes: fun(): table[], keys_after?: string }
---@return table backend
function M.tmux(opts)
	local id, label = opts.id, opts.label
	local keys_after = opts.keys_after or "Enter"

	local function tmux(args, stdin)
		local ok, res = pcall(function()
			return vim.system({ "tmux", unpack(args) }, { text = true, stdin = stdin }):wait()
		end)
		if not ok then
			return false, tostring(res)
		end
		if res.code ~= 0 then
			return false, (res.stderr or ""):gsub("%s+$", "")
		end
		return true
	end

	local backend = {
		id = id,
		label = label,
		targets = function()
			local ok, list = pcall(opts.panes)
			return ok and list or {}
		end,
	}

	function backend.send(target, text)
		local buffer = ("ai-ask-%s"):format(id)
		local ok, err = tmux({ "load-buffer", "-b", buffer, "-" }, text)
		if not ok then
			return false, ("tmux load-buffer 失败：%s"):format(err)
		end
		ok, err = tmux({ "paste-buffer", "-b", buffer, "-d", "-t", target.pane })
		if not ok then
			return false, ("tmux paste-buffer 失败：%s"):format(err)
		end
		ok, err = tmux({ "send-keys", "-t", target.pane, keys_after })
		if not ok then
			return false, ("tmux send-keys 失败：%s"):format(err)
		end
		return true
	end

	return backend
end

--- 小工具：按命令名筛 tmux pane，返回 panes() 工厂。
--- 例如 tmux_panes_by_cmd("opencode") → 每个正在跑 opencode 的 pane 一个目标。
---@param pattern string Lua 模式，匹配 pane_current_command
---@return fun(): table[]
function M.tmux_panes_by_cmd(pattern)
	return function()
		local ok, res = pcall(function()
			return vim.system({
				"tmux",
				"list-panes",
				"-a",
				"-F",
				"#{pane_id}\t#{pane_current_command}\t#{pane_current_path}",
			}, { text = true }):wait()
		end)
		if not ok or res.code ~= 0 then
			return {}
		end
		local out = {}
		for line in (res.stdout or ""):gmatch("[^\n]+") do
			local pane, command, path = line:match("^(%S+)\t(%S+)\t(.*)$")
			if pane and command and command:find(pattern) then
				table.insert(out, { id = pane, label = pane, pane = pane, cwd = path })
			end
		end
		return out
	end
end

return M
