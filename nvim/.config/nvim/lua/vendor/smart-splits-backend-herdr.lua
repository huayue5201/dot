-- smart-splits.nvim 的 herdr 后端（v3 协议）。
--
-- 上游 v3 不再内置复用器后端（herdr 也没官方实现），这里自维护一份。
-- 协议：smart-splits.nvim 仓库的 PROTOCOL.md；逻辑移植自上游 v2 的
-- lua/smart-splits/mux/herdr.lua，去掉核心已负责的 window 操作。
--
-- 由 lua/plugins/smart-splits.lua 里的
--   mux = { backend = { "vendor.smart-splits-backend-herdr", ... } }
-- 按模块名加载。

local function herdr_bin()
	local bin = vim.env.HERDR_BIN_PATH
	return (bin ~= nil and bin ~= "") and bin or "herdr"
end

--- 运行 herdr 并解析 JSON 输出；任何失败都返回 nil（协议要求绝不抛错）。
---@param args string[]
---@return table|nil
local function exec_json(args)
	local argv = { herdr_bin() }
	vim.list_extend(argv, args)

	local ok, res = pcall(function()
		return vim.system(argv, { text = true, timeout = 200 }):wait()
	end)
	if not ok or res == nil or res.code ~= 0 or res.stdout == nil or #res.stdout == 0 then
		return nil
	end

	local decoded_ok, decoded = pcall(vim.json.decode, res.stdout)
	if not decoded_ok then
		return nil
	end
	return decoded
end

--- herdr 后端的 v3 协议实现（core 侧的接口定义见 smart-splits.nvim 的 PROTOCOL.md）。
--- 这里用 @class 而不是 @type：@type 指向外部类只是「引用」，下面 M.move / M.resize /
--- M.health 的赋值会被 lua-ls 判成 inject-field 警告。
---@class HerdrBackend
local M = {
	name = "herdr",
	protocol_version = "3.0.0",
}

-- herdr 调子进程时把 HERDR_ENV 置为 "1"（herdr 自己的探测就是
-- `test "${HERDR_ENV:-}" = 1`），并顺带注入 HERDR_SOCKET_PATH / HERDR_PANE_ID 等。
-- 注意「变量存在」不能当判据：外部遗留的 HERDR_ENV="" 也会被继承下来，
-- 而 Neovim 的 vim.env 连空串都读成 nil，所以只认具体的值。
-- 协议要求：便宜、无副作用、不 shell out。
function M.detect()
	return vim.env.HERDR_ENV == "1" and vim.fn.executable(herdr_bin()) == 1
end

---@param direction "left"|"right"|"up"|"down"
---@param opts? { at_edge?: "stop"|"wrap"|"split" }
function M.move(direction, opts)
	if not M.detect() then
		return false
	end

	local data = exec_json({ "pane", "focus", "--direction", direction, "--current" })
	local focus = data and data.result and data.result.focus
	-- herdr 不会 wrap：到边界时返回 changed=false / reason="no_neighbor"。
	-- 返回 false 即把 at_edge（stop/wrap/split）交给核心处理。
	return focus ~= nil and focus.changed == true
end

---@param direction "left"|"right"|"up"|"down"
---@param opts? { amount?: number }
function M.resize(direction, opts)
	if not M.detect() then
		return false
	end

	-- 核心传「格数」，herdr 的 --amount 要「比例增量」：按窗口列/行数换算成比例，
	-- 并按 herdr 内部上限 clamp 到 0.5，避免一下跳半个屏幕。
	local amount = (opts or {}).amount or 1
	local horizontal = direction == "left" or direction == "right"
	local cells = horizontal and vim.o.columns or vim.o.lines
	local ratio = math.min(amount / math.max(cells, 1), 0.5)

	local data = exec_json({
		"pane",
		"resize",
		"--direction",
		direction,
		"--amount",
		tostring(ratio),
		"--current",
	})
	local resize = data and data.result and data.result.resize
	return resize ~= nil and resize.changed == true
end

function M.health()
	local env = vim.env.HERDR_ENV
	local bin = herdr_bin()

	if env == "1" then
		vim.health.ok("herdr env markers present; running inside herdr")
	elseif env ~= nil then
		vim.health.warn(('HERDR_ENV=%q is not "1" (stale/herdr-less env)'):format(env))
	else
		vim.health.info("HERDR_ENV is not set; not running inside herdr")
	end

	if vim.fn.executable(bin) == 1 then
		vim.health.ok(("herdr executable found: %s"):format(bin))
	else
		vim.health.warn(("herdr executable not found: %s"):format(bin))
	end
end

return M
