local M = {}

-- 简单的 Promise 实现
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
	local min_chunk = opts.min_chunk or 500
	local max_chunk = opts.max_chunk or 20000
	return math.min(math.max(base, min_chunk), max_chunk)
end

-- Worker 处理函数
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

		for i = 1, #lines do
			if #lines[i] > maxlen then
				shared.stopped = true
				local linenr = cursor + i
				promise:resolve(true, string.format("line %d too long (%d > %d)", linenr, #lines[i], maxlen))
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

-- 长行扫描函数
function M.scan(buf, opts)
	opts = opts or {}
	local opt = {
		max_length = opts.max_length or 10000,
		workers = math.max(1, opts.workers or 4),
		chunk_size = opts.chunk_size,
		min_chunk = opts.min_chunk or 500,
		max_chunk = opts.max_chunk or 20000,
		schedule_delay = opts.schedule_delay or 0,
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

	-- 自动计算 chunk_size
	if not opt.chunk_size then
		opt.chunk_size = compute_chunk_size(total_lines, opt.workers, opt)
	end

	-- 计算 worker 分配
	local workers = math.min(opt.workers, total_lines)
	local per = math.ceil(total_lines / workers)

	local shared = {
		stopped = false,
		workers_done = 0,
		total_workers = workers,
	}

	-- 启动 workers
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

-- 统一的检测接口
function M.check(buf, ctx, callback)
	-- 确保配置存在
	local config = {
		max_length = ctx.max_length or 10000,
		workers = ctx.workers or 4,
		chunk_size = ctx.chunk_size,
		min_chunk = ctx.min_chunk or 500,
		max_chunk = ctx.max_chunk or 20000,
		schedule_delay = ctx.schedule_delay or 0,
	}

	if not vim.api.nvim_buf_is_valid(buf) then
		return callback(false, "invalid buffer")
	end

	local promise = M.scan(buf, config)
	promise:then_(function(hit, reason)
		callback(hit, reason)
	end)
end

return M
