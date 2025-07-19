-- lua/brickdag/bricks/frame/format.lua

local FormatFramework = {
	name = "format",
	brick_type = "frame",
	description = "通用代码格式化框架（含内置增量格式化参数注入器）",
	version = "1.1.0",
}

local function get_changed_ranges(file_path)
	local result = {}
	local lines = vim.fn.systemlist("git diff -U0 -- " .. vim.fn.shellescape(file_path))
	for _, line in ipairs(lines) do
		local m = string.match(line, "^@@ %-%d+,%d+ %+(%d+),?(%d*) @@")
		if m then
			local start_line = tonumber(m:match("^(%d+)"))
			local count = tonumber(m:match(",(%d+)")) or 1
			table.insert(result, { start_line = start_line, end_line = start_line + count - 1 })
		end
	end
	return result
end

-- 内置注入器集合，key为格式化器模式名
local builtin_range_arg_injectors = {
	stylua = function(base_args, ranges)
		for _, r in ipairs(ranges) do
			table.insert(base_args, "--range-start")
			table.insert(base_args, tostring(r.start_line))
			table.insert(base_args, "--range-end")
			table.insert(base_args, tostring(r.end_line))
		end
		return base_args
	end,
	clang_format = function(base_args, ranges)
		for _, r in ipairs(ranges) do
			table.insert(base_args, "-lines=" .. r.start_line .. ":" .. r.end_line)
		end
		return base_args
	end,
	prettier = function(base_args, ranges)
		-- prettier 支持 --range-start 和 --range-end，但只支持单个范围，这里取第一个
		if #ranges > 0 then
			local r = ranges[1]
			table.insert(base_args, "--range-start")
			table.insert(base_args, tostring(r.start_line))
			table.insert(base_args, "--range-end")
			table.insert(base_args, tostring(r.end_line))
		end
		return base_args
	end,
	rustfmt = function(base_args, ranges)
		-- rustfmt 目前不支持增量行范围，只能跳过注入
		return base_args
	end,
	-- 可继续添加其它工具支持
}

local function default_inject_range_args(base_args, ranges)
	return base_args
end

--- 解析配置参数
function FormatFramework.resolve_config(config, context)
	local services = context.services
	local resolver = services.resolver

	return resolver.resolve_parameters(config, {
		file_path = vim.fn.expand("%:p"),
		file_dir = vim.fn.expand("%:p:h"),
		file_name = vim.fn.expand("%:t"),
		file_type = vim.bo.filetype,
		project_root = context.project_root or vim.fn.getcwd(),
	})
end

--- 格式化执行主函数
function FormatFramework.execute(exec_context)
	local logger = exec_context.services.logger
	local config = exec_context.config

	local resolved = FormatFramework.resolve_config(config, exec_context)
	local formatter = resolved.cmd
	if not formatter then
		return false, "未提供格式化工具命令"
	end

	local args = resolved.args or {}
	local files = resolved.files or { resolved.file_path }

	if resolved.incremental and #files == 1 then
		local file_path = files[1]
		local ranges = get_changed_ranges(file_path)
		if #ranges > 0 then
			local inject_fn = resolved.inject_range_args
			if not inject_fn and resolved.range_mode then
				inject_fn = builtin_range_arg_injectors[resolved.range_mode]
			end
			if not inject_fn then
				inject_fn = default_inject_range_args
			end
			args = inject_fn(args, ranges)
		else
			logger("未检测到改动区域，跳过格式化", vim.log.levels.INFO)
			return true
		end
	end

	local full_cmd = formatter
	if #args > 0 then
		full_cmd = full_cmd .. " " .. table.concat(args, " ")
	end
	full_cmd = full_cmd .. " " .. table.concat(vim.tbl_map(vim.fn.shellescape, files), " ")

	logger(string.format("[FORMAT] 执行: %s", full_cmd), vim.log.levels.INFO)

	local output = vim.fn.system(full_cmd)
	local exit_code = vim.v.shell_error

	if exit_code == 0 then
		if resolved.reload ~= false then
			vim.cmd("e!")
			logger("文件已重新加载", vim.log.levels.INFO)
		end
		if resolved.notify ~= false then
			vim.notify("✅ 格式化完成", vim.log.levels.INFO)
		end
		return true
	else
		local err_msg = "格式化失败 (退出码: " .. exit_code .. ")"
		logger(err_msg .. "\n" .. output, vim.log.levels.ERROR)
		return false, err_msg
	end
end

return FormatFramework
