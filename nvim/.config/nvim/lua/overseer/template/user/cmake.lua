-- CMake 构建模板（嵌入式/C/C++ 项目常用）
-- 出现条件：向上能找到 CMakeLists.txt。
-- 「配置」任务带 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON，产出的 compile_commands.json
-- 是 clangd 需要的依赖库索引（配合 lsp/clangd.lua 的 root_markers）。
-- 需要 compiledb 那条 make 路线时用 compiledb.lua。

local TAG = require("overseer.constants").TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_root(opts)
	return vim.fs.find("CMakeLists.txt", {
		upward = true,
		type = "file",
		path = opts.dir,
	})[1]
end

---@type overseer.TemplateFileProvider
return {
	cache_key = find_root,
	generator = function(opts, cb)
		if vim.fn.executable("cmake") == 0 then
			return 'Command "cmake" not found'
		end
		local cmakelists = find_root(opts)
		if not cmakelists then
			return "No CMakeLists.txt found"
		end
		local dir = vim.fs.dirname(cmakelists)

		local build_dir_param = {
			type = "string",
			desc = "构建目录（相对项目根）",
			default = "build",
		}

		cb({
			{
				name = "cmake: 配置（导出 compile_commands.json）",
				tags = { TAG.BUILD },
				params = {
					build_dir = build_dir_param,
					extra = {
						type = "string",
						desc = "额外的 -D 参数（空格分隔，可留空）",
						default = "",
						optional = true,
					},
				},
				builder = function(params)
					local cmd = {
						"cmake",
						"-S",
						".",
						"-B",
						params.build_dir,
						"-DCMAKE_EXPORT_COMPILE_COMMANDS=ON",
					}
					vim.list_extend(cmd, vim.split(params.extra, "%s+", { trimempty = true }))
					return { cmd = cmd, cwd = dir }
				end,
			},
			{
				name = "cmake: 构建",
				tags = { TAG.BUILD },
				params = {
					target = {
						type = "string",
						desc = "目标名（留空 = 默认 all）",
						default = "",
						optional = true,
					},
					build_dir = build_dir_param,
				},
				builder = function(params)
					local cmd = { "cmake", "--build", params.build_dir }
					if params.target ~= "" then
						vim.list_extend(cmd, { "--target", params.target })
					end
					return { cmd = cmd, cwd = dir }
				end,
			},
			{
				name = "cmake: 清理（clean 目标）",
				tags = { TAG.CLEAN },
				params = { build_dir = build_dir_param },
				builder = function(params)
					return {
						cmd = { "cmake", "--build", params.build_dir, "--target", "clean" },
						cwd = dir,
					}
				end,
			},
		})
	end,
}
