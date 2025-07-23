local FormatFramework = {
	name = "format",
	brick_type = "frame",
	description = "通用代码格式化框架（支持临时文件方案）",
	version = "2.0.0",
}

local uv = vim.loop

--- 创建临时文件并写入 buffer 内容
local function write_buffer_to_tempfile(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tmpname = vim.fn.tempname()
	local fd = uv.fs_open(tmpname, "w", 438) -- 438 = 0o666

	if not fd then
		return nil, "创建临时文件失败"
	end

	local ok, err = pcall(function()
		uv.fs_write(fd, table.concat(lines, "\n"))
	end)

	uv.fs_close(fd)

	if not ok then
		return nil, "写入临时文件失败: " .. err
	end

	return tmpname
end

--- 格式化主函数
function FormatFramework.execute(exec_context)
	local logger = exec_context.services.logger
	local config = exec_context.config

	local resolved = FormatFramework.resolve_config(config, exec_context)
	local formatter = resolved.cmd
	if not formatter then
		return false, "未提供格式化命令"
	end

	local args = resolved.args or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local temp_file, err = write_buffer_to_tempfile(bufnr)
	if not temp_file then
		return false, "临时文件创建失败: " .. err
	end

	table.insert(args, temp_file)

	local full_cmd = formatter .. " " .. table.concat(args, " ")
	logger(string.format("[FORMAT] 执行: %s", full_cmd), vim.log.levels.INFO)

	local output = vim.fn.system(full_cmd)
	local exit_code = vim.v.shell_error

	if exit_code ~= 0 then
		local msg = string.format("格式化失败 (退出码 %d): %s", exit_code, output)
		logger(msg, vim.log.levels.ERROR)
		return false, msg
	end

	local fd = uv.fs_open(temp_file, "r", 438)
	local stat = uv.fs_fstat(fd)
	local formatted = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	uv.fs_unlink(temp_file)

	if formatted then
		local lines = vim.split(formatted, "\n", { plain = true })
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		if resolved.notify ~= false then
			vim.notify("✅ 格式化完成", vim.log.levels.INFO)
		end
		return true
	else
		return false, "读取格式化后内容失败"
	end
end

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

return FormatFramework
