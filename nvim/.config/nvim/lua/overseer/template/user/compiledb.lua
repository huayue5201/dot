-- compiledb：为 clangd 生成 compile_commands.json
-- https://github.com/nickdiego/compiledb
-- 用 make 系构建系统（Makefile / CMake 生成的 Makefile）时，clangd 默认能自动读取
-- 项目根的 compile_commands.json（见 lsp/clangd.lua 的 root_markers）。
-- 任务出现条件：向上能找到 Makefile，且 compiledb 在 $PATH。

local TAG = require("overseer.constants").TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_makefile(opts)
	return vim.fs.find({ "Makefile", "makefile", "GNUmakefile" }, {
		upward = true,
		type = "file",
		path = opts.dir,
	})[1]
end

---@type overseer.TemplateFileProvider
return {
	cache_key = find_makefile,
	generator = function(opts, cb)
		if vim.fn.executable("compiledb") == 0 then
			return 'Command "compiledb" not found'
		end
		local makefile = find_makefile(opts)
		if not makefile then
			return "No Makefile found"
		end
		local dir = vim.fs.dirname(makefile)

		cb({
			{
				name = "compiledb: 生成 compile_commands.json",
				tags = { TAG.BUILD },
				params = {
					command = {
						type = "string",
						desc = "构建命令（compiledb 会包一层执行，可带参数）",
						default = "make",
					},
					overwrite = {
						type = "boolean",
						desc = "覆盖已有 compile_commands.json（否则增量更新）",
						default = true,
					},
				},
				builder = function(params)
					-- command 里可能带空格（如 "make -j8"），交给 shell 拼
					local cmd = "compiledb " .. (params.overwrite and "-f " or "") .. params.command
					return { cmd = cmd, cwd = dir }
				end,
			},
			{
				name = "compiledb: 只生成（make -n，不实际构建）",
				tags = { TAG.BUILD },
				params = {
					command = {
						type = "string",
						desc = "构建命令（会用 -n 干跑，不产生编译产物）",
						default = "make",
					},
				},
				builder = function(params)
					return { cmd = "compiledb -f -n " .. params.command, cwd = dir }
				end,
			},
		})
	end,
}
