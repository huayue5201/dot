-- smart-splits.nvim 的 herdr 后端（v3 协议）。
--
-- 上游 v3 不再内置复用器后端（herdr 也没官方实现），这里自维护一份。
-- 协议：smart-splits.nvim 仓库的 PROTOCOL.md；逻辑移植自上游 v2 的
-- lua/smart-splits/mux/herdr.lua，去掉核心已负责的 window 操作。
--
-- 由 lua/plugins/smart-splits.lua 里的
--   mux = { backend = { "vendor.smart-splits-backend-herdr", ... } }
-- 按模块名加载。

local DIRS = { left = "left", right = "right", up = "up", down = "down" }

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

---@type SmartSplitsBackend
local M = {
	name = "herdr",
	protocol_version = "3.0.0",
}

-- 协议要求：便宜、无副作用、不 shell out。
function M.detect()
	return vim.env.HERDR_ENV ~= nil and vim.env.HERDR_ENV ~= ""
end

---@param direction "left"|"right"|"up"|"down"
---@param opts? { at_edge?: "stop"|"wrap"|"split" }
function M.move(direction, opts)
	if not M.detect() or DIRS[direction] == nil then
		return false
	end

	local data = exec_json({ "pane", "focus", "--direction", DIRS[direction], "--current" })
	local focus = data and data.result and data.result.focus
	-- herdr 不会 wrap：到边界时返回 changed=false / reason="no_neighbor"。
	-- 返回 false 即把 at_edge（stop/wrap/split）交给核心处理。
	return focus ~= nil and focus.changed == true
end

---@param direction "left"|"right"|"up"|"down"
---@param opts? { amount?: number }
function M.resize(direction, opts)
	if not M.detect() or DIRS[direction] == nil then
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
		DIRS[direction],
		"--amount",
		tostring(ratio),
		"--current",
	})
	local resize = data and data.result and data.result.resize
	return resize ~= nil and resize.changed == true
end

function M.health()
	if M.detect() then
		vim.health.ok("HERDR_ENV is set; running inside herdr")
	else
		vim.health.info("HERDR_ENV is not set; not running inside herdr")
	end

	local bin = herdr_bin()
	if vim.fn.executable(bin) == 1 then
		vim.health.ok(("herdr executable found: %s"):format(bin))
	else
		vim.health.warn(("herdr executable not found: %s"):format(bin))
	end
end

return M
