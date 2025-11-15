-- lua/fast_linecheck.lua
local M = {}

-- 默认配置
local DEFAULTS = {
	max_length = 10000,
	workers = 4,
	chunk_size = nil, -- nil 表示自动计算
	min_chunk = 500, -- 最小 chunk 大小
	max_chunk = 20000, -- 最大 chunk 大小
	schedule_delay = 0, -- 每次 worker 下一步使用的 defer 延迟(ms)
}

-- simple promise implementation: supports then(fn) and await() (coroutine yield)
local function make_promise()
	local p = {
		done = false,
		result = nil,
		callbacks = {},
		cancelled = false,
	}

	function p:resolve(ok, msg)
		if self.done then
			return
		end
		self.done = true
		self.result = { ok = ok, msg = msg }
		for _, cb in ipairs(self.callbacks) do
			vim.defer_fn(function()
				cb(ok, msg)
			end, 0)
		end
		self.callbacks = {}
	end

	function p:then_(fn)
		if self.done then
			vim.defer_fn(function()
				fn(self.result.ok, self.result.msg)
			end, 0)
		else
			table.insert(self.callbacks, fn)
		end
		return self
	end

	function p:await()
		if self.done then
			return self.result.ok, self.result.msg
		end
		local co = coroutine.running()
		if not co then
			error("promise:await must be called from a coroutine")
		end
		self:then_(function(ok, msg)
			coroutine.resume(co, ok, msg)
		end)
		return coroutine.yield()
	end

	function p:cancel()
		if not self.done then
			self.cancelled = true
			self:resolve(false, "cancelled")
		end
	end

	return p
end

-- 自动计算 chunk_size
local function compute_chunk_size(total_lines, workers, opts)
	local base = math.floor(total_lines / (workers * 12))
	if base < (opts.min_chunk or DEFAULTS.min_chunk) then
		base = opts.min_chunk or DEFAULTS.min_chunk
	end
	if base > (opts.max_chunk or DEFAULTS.max_chunk) then
		base = opts.max_chunk or DEFAULTS.max_chunk
	end
	return base
end

-- worker
local function spawn_worker(id, buf, range_start, range_end, opt, shared, promise)
	local cursor = range_start
	local chunk = opt.chunk_size
	local maxlen = opt.max_length

	local function step()
		if promise.cancelled or shared.stopped then
			return
		end
		if not vim.api.nvim_buf_is_valid(buf) then
			shared.stopped = true
			promise:resolve(false, "buffer invalid")
			return
		end

		if cursor >= range_end then
			shared.workers_done = shared.workers_done + 1
			if shared.workers_done >= shared.total_workers and not shared.stopped then
				shared.stopped = true
				promise:resolve(false, nil)
			end
			return
		end

		local end_line = math.min(cursor + chunk, range_end)
		local lines = vim.api.nvim_buf_get_lines(buf, cursor, end_line, false)

		local ml = maxlen
		for i = 1, #lines do
			local line = lines[i]
			if #line > ml then
				shared.stopped = true
				local linenr = cursor + i
				promise:resolve(true, string.format("line %d too long (%d > %d)", linenr, #line, ml))
				return
			end
		end

		cursor = end_line

		if not shared.stopped and not promise.cancelled then
			vim.defer_fn(step, opt.schedule_delay or 0)
		end
	end

	vim.defer_fn(step, opt.schedule_delay or 0)
end

-- 主 API
function M.scan(buf, opts)
	opts = opts or {}
	local opt = {
		max_length = opts.max_length or DEFAULTS.max_length,
		workers = math.max(1, opts.workers or DEFAULTS.workers),
		chunk_size = opts.chunk_size,
		min_chunk = opts.min_chunk or DEFAULTS.min_chunk,
		max_chunk = opts.max_chunk or DEFAULTS.max_chunk,
		schedule_delay = opts.schedule_delay or DEFAULTS.schedule_delay,
	}

	local promise = make_promise()

	if not vim.api.nvim_buf_is_valid(buf) then
		vim.defer_fn(function()
			promise:resolve(false, "invalid buffer")
		end, 0)
		return promise
	end

	local total_lines = vim.api.nvim_buf_line_count(buf)
	if total_lines == 0 then
		vim.defer_fn(function()
			promise:resolve(false, nil)
		end, 0)
		return promise
	end

	if not opt.chunk_size then
		opt.chunk_size = compute_chunk_size(total_lines, opt.workers, opt)
	end

	local workers = opt.workers
	local per = math.floor(total_lines / workers)
	if per < 1 then
		per = 1
		workers = total_lines
	end

	local shared = {
		stopped = false,
		workers_done = 0,
		total_workers = workers,
	}

	for i = 1, workers do
		local start_line = (i - 1) * per
		local end_line = (i == workers) and total_lines or (i * per)
		spawn_worker(i, buf, start_line, end_line, opt, shared, promise)
	end

	return {
		then_ = function(_, fn)
			return promise:then_(fn)
		end,
		await = function(_)
			return promise:await()
		end,
		cancel = function(_)
			return promise:cancel()
		end,
	}
end

return M
