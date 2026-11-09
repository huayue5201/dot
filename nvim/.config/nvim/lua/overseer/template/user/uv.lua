-- uv（Python 依赖 / 运行 / 测试）任务模板
-- https://docs.astral.sh/uv/
-- 只在向上能找到 pyproject.toml / uv.lock 的项目里出现（provider 模式：
-- 不是项目就返回提示，:OverseerRun 列表里也不会显示）。
-- uv 未安装时同样只返回提示，不产生任务。

local TAG = require("overseer.constants").TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_root(opts)
	local found = vim.fs.find({ "pyproject.toml", "uv.lock" }, {
		upward = true,
		type = "file",
		path = opts.dir,
	})[1]
	return found and vim.fs.dirname(found) or nil
end

---当前 buffer 相对项目根的路径（不在项目内返回 nil）
local function current_file(dir)
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" or not vim.startswith(file, dir .. "/") then
		return nil
	end
	return vim.fs.relpath(dir, file) or file
end

---@type overseer.TemplateFileProvider
return {
	cache_key = find_root,
	generator = function(opts, cb)
		if vim.fn.executable("uv") == 0 then
			return 'Command "uv" not found'
		end
		local dir = find_root(opts)
		if not dir then
			return "No pyproject.toml or uv.lock found"
		end

		---@type overseer.TemplateDefinition[]
		local tasks = {
			{
				name = "uv sync (同步/安装依赖)",
				tags = { TAG.BUILD },
				builder = function()
					return { cmd = { "uv", "sync" }, cwd = dir }
				end,
			},
			{
				name = "uv lock (更新锁文件)",
				tags = { TAG.BUILD },
				builder = function()
					return { cmd = { "uv", "lock" }, cwd = dir }
				end,
			},
			{
				name = "uv run pytest (全部测试)",
				tags = { TAG.TEST },
				builder = function()
					return { cmd = { "uv", "run", "pytest" }, cwd = dir }
				end,
			},
		}

		local file = current_file(dir)
		if file and file:match("%.py$") then
			table.insert(tasks, {
				name = "uv run python (当前文件)",
				tags = { TAG.RUN },
				builder = function()
					return { cmd = { "uv", "run", "python", file }, cwd = dir }
				end,
			})
			table.insert(tasks, {
				name = "uv run pytest (当前文件)",
				tags = { TAG.TEST },
				builder = function()
					return { cmd = { "uv", "run", "pytest", file }, cwd = dir }
				end,
			})
		end

		cb(tasks)
	end,
}
