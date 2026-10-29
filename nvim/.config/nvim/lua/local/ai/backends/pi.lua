-- lua/local/ai/backends/pi.lua
---@brief pi 后端：往终端里跑着的 pi 实例的 unix socket 写一行 JSON。
--
-- 约定（pi 侧 extensions/nvim-context.ts）：
--   ~/.cache/pi-agent/ask/<pid>.sock   unix socket，收一行 JSON {"text": "..."}
--   ~/.cache/pi-agent/ask/<pid>.json   登记 {pid, sock, cwd, ts, embedded}
-- 其中 embedded=true 表示这个 pi 是 `pi --mode rpc`（由 codecompanion 之类 ACP 客户端
-- 拉起并拥有会话）：往它发消息，回复只会回到那个客户端，不会出现在 nvim 里。
-- 这类实例默认不参与 cwd 匹配（见 backends/init.lua 的 avoid）。
-- 文本在 nvim 侧就渲染好了，pi 只负责 sendUserMessage 进自己的会话。

local M = { id = "pi", label = "pi" }

local function ask_dir()
	local cache = os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")
	return cache .. "/pi-agent/ask"
end

--- 扫描登记目录，返回活着的 pi 实例（活跃度降序）
---@return table[]
function M.targets()
	local dir = ask_dir()
	local out = {}
	if vim.fn.isdirectory(dir) == 0 then
		return out
	end
	for _, name in ipairs(vim.fn.readdir(dir) or {}) do
		if name:match("%.json$") then
			local ok, entry = pcall(function()
				return vim.json.decode(table.concat(vim.fn.readfile(dir .. "/" .. name), "\n"))
			end)
			if ok and type(entry) == "table" and entry.sock then
				-- pid 还活着才认（uv.kill 不走子进程，~0.001ms vs vim.fn.system 的 ~1.9ms）
				if pcall(vim.uv.kill, tonumber(entry.pid) or -1, 0) then
					local embedded = entry.embedded == true
					table.insert(out, {
						id = tostring(entry.pid),
						label = ("pid %s%s"):format(entry.pid, embedded and " (acp)" or ""),
						cwd = entry.cwd,
						sock = entry.sock,
						ts = entry.ts or 0,
						embedded = embedded,
						avoid = embedded and "嵌入式 pi（codecompanion/ACP 驱动，回复不回到 nvim）" or nil,
					})
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.ts > b.ts
	end)
	return out
end

function M.available()
	if #M.targets() > 0 then
		return true
	end
	return false, "没有活着的 pi（先在终端启动 `pi`，扩展会自动登记 socket）"
end

---@param target table
---@param text string
---@return boolean ok, string? err
function M.send(target, text)
	local ok, chan = pcall(vim.fn.sockconnect, "pipe", target.sock, {
		rpc = false,
		-- 异步收 ack：写失败（如实例刚死）时补一条告警，不阻塞 UI
		on_data = function(_, data)
			local line = data and data[1] or ""
			if line:find('"ok":false', 1, true) then
				vim.schedule(function()
					vim.notify("[pi] 发送失败: " .. line, vim.log.levels.WARN)
				end)
			end
		end,
	})
	if not ok or chan == 0 then
		return false, ("连不上 pi 的 socket：%s（实例可能已退出）"):format(target.sock)
	end
	vim.fn.chansend(chan, vim.json.encode({ text = text }) .. "\n")
	-- 留窗口收 ack；不阻塞 nvim
	vim.defer_fn(function()
		pcall(vim.fn.chanclose, chan)
	end, 1500)
	return true
end

return M
