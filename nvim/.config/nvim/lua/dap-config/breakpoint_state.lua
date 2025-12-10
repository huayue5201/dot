-- lua/dap/breakpoint_state.lua
local M = {}
local breakpoints = require("dap.breakpoints")
local json_store = require("user.json_store")

-- 缓存存储的断点数据
local cached_bps = nil
local save_debounce_timer = nil

-- 获取当前项目标识
local function get_project_id()
	local cwd = vim.fn.getcwd()
	return vim.fn.fnamemodify(cwd, ":t") .. ":" .. cwd
end

-- 规范化文件路径
local function normalize_path(path)
	if not path or path == "" then
		return nil
	end
	return vim.fn.fnamemodify(path, ":p")
end

-- 获取缓存或从存储加载断点
local function get_cached_stored_bps()
	if cached_bps == nil then
		cached_bps = json_store.get("dap", "breakpoints") or {}
	end
	return cached_bps
end

-- 更新缓存和存储
local function update_cached_bps(new_bps)
	cached_bps = new_bps
	json_store.set("dap", "breakpoints", new_bps)
end

-- 验证断点数据有效性
local function validate_breakpoint(bp)
	if not bp.line or type(bp.line) ~= "number" or bp.line <= 0 then
		return false
	end

	-- 验证条件字段
	if bp.condition and type(bp.condition) ~= "string" then
		return false
	end

	if bp.logMessage and type(bp.logMessage) ~= "string" then
		return false
	end

	if bp.hitCondition and type(bp.hitCondition) ~= "string" then
		return false
	end

	return true
end

-- 获取当前所有打开的缓冲区及其实际断点
local function get_current_breakpoints()
	local current_bps = {}
	local breakpoints_by_buf = breakpoints.get()

	for buf, buf_bps in pairs(breakpoints_by_buf) do
		local filepath = vim.api.nvim_buf_get_name(buf)
		local full_path = normalize_path(filepath)

		if full_path and vim.fn.filereadable(full_path) == 1 then
			current_bps[full_path] = {}

			for _, bp in ipairs(buf_bps) do
				if validate_breakpoint(bp) then
					table.insert(current_bps[full_path], {
						line = bp.line,
						condition = bp.condition,
						logMessage = bp.logMessage,
						hitCondition = bp.hitCondition,
					})
				end
			end
		end
	end

	return current_bps
end

-- 防抖保存断点
function M.save_breakpoints_debounced()
	if save_debounce_timer then
		save_debounce_timer:close()
	end

	save_debounce_timer = vim.defer_fn(function()
		M.save_breakpoints()
		save_debounce_timer = nil
	end, 500) -- 500ms防抖
end

-- 智能保存断点：比对存储和实际断点，清理无效数据
function M.save_breakpoints()
	-- 获取当前项目ID
	local project_id = get_project_id()

	-- 获取当前实际的断点
	local current_bps = get_current_breakpoints()

	-- 获取存储中的断点
	local stored_bps = get_cached_stored_bps()

	-- 创建新的存储数据
	local new_stored_bps = {}

	-- 首先，保存所有当前实际的断点
	for filepath, bps in pairs(current_bps) do
		if #bps > 0 then
			-- 只保存有效的断点
			local valid_bps = {}
			for _, bp in ipairs(bps) do
				if validate_breakpoint(bp) then
					table.insert(valid_bps, bp)
				end
			end

			if #valid_bps > 0 then
				new_stored_bps[filepath] = valid_bps
			end
		end
	end

	-- 然后，检查存储中是否有文件实际已不存在
	for filepath, bps in pairs(stored_bps) do
		-- 跳过项目标识和版本信息等特殊键
		if not filepath:match("^_") then
			-- 如果文件不存在于当前实际断点中
			if not current_bps[filepath] then
				-- 检查文件是否还存在于系统中
				if vim.fn.filereadable(filepath) == 0 then
					-- 文件已不存在，不保留断点
				else
					-- 文件存在但没有当前断点，保留存储的断点（可能文件未打开）
					-- 但只保留有效的断点
					local valid_bps = {}
					for _, bp in ipairs(bps) do
						if validate_breakpoint(bp) then
							table.insert(valid_bps, bp)
						end
					end

					if #valid_bps > 0 then
						new_stored_bps[filepath] = valid_bps
					end
				end
			end
		end
	end

	-- 保存项目标识
	new_stored_bps._project = project_id

	-- 保存版本信息（便于未来数据迁移）
	new_stored_bps._version = 1

	-- 保存新的存储数据
	update_cached_bps(new_stored_bps)
end

-- 恢复断点
function M.restore_breakpoints()
	local stored_bps = get_cached_stored_bps()
	local current_project = get_project_id()
	local stored_project = stored_bps._project

	-- 如果项目不同，跳过恢复（静默处理）
	if stored_project and stored_project ~= current_project then
		return
	end

	-- 先获取当前实际的断点，用于去重
	local current_bps = get_current_breakpoints()

	-- 恢复每个文件的断点
	for filepath, bps in pairs(stored_bps) do
		-- 跳过特殊键
		if filepath:match("^_") then
			goto continue
		end

		-- 验证文件是否存在
		if vim.fn.filereadable(filepath) ~= 1 then
			goto continue
		end

		-- 查找文件是否在缓冲区中
		local bufnr = vim.fn.bufnr(filepath)
		if bufnr == -1 then
			-- 文件未打开，跳过
			goto continue
		end

		-- 获取该文件当前的断点（用于去重）
		local current_file_bps = {}
		if current_bps[filepath] then
			for _, bp in ipairs(current_bps[filepath]) do
				current_file_bps[bp.line] = true
			end
		end

		-- 恢复断点（跳过已存在的）
		for _, bp in ipairs(bps) do
			if validate_breakpoint(bp) and not current_file_bps[bp.line] then
				local opts = {}
				if bp.condition and bp.condition ~= "" then
					opts.condition = bp.condition
				end
				if bp.logMessage and bp.logMessage ~= "" then
					opts.log_message = bp.logMessage
				end
				if bp.hitCondition and bp.hitCondition ~= "" then
					opts.hit_condition = bp.hitCondition
				end

				breakpoints.set(opts, bufnr, bp.line)
			end
		end

		::continue::
	end
end

-- 处理文件重命名
local function handle_file_rename(old_path, new_path)
	if not old_path or not new_path or old_path == new_path then
		return
	end

	local stored_bps = get_cached_stored_bps()
	if stored_bps[old_path] then
		stored_bps[new_path] = stored_bps[old_path]
		stored_bps[old_path] = nil
		update_cached_bps(stored_bps)
	end
end

-- 清理无效的存储断点
function M.cleanup_stored_breakpoints()
	local stored_bps = get_cached_stored_bps()
	local valid_bps = {}

	-- 保留特殊键
	for key, value in pairs(stored_bps) do
		if key:match("^_") then
			valid_bps[key] = value
		end
	end

	for filepath, bps in pairs(stored_bps) do
		-- 跳过特殊键
		if filepath:match("^_") then
			goto continue
		end

		-- 验证文件是否存在
		if vim.fn.filereadable(filepath) ~= 1 then
			-- 文件不存在，跳过
			goto continue
		end

		-- 验证每个断点是否有效
		local valid_file_bps = {}
		for _, bp in ipairs(bps) do
			if validate_breakpoint(bp) then
				table.insert(valid_file_bps, bp)
			end
		end

		if #valid_file_bps > 0 then
			valid_bps[filepath] = valid_file_bps
		end

		::continue::
	end

	-- 保存清理后的数据
	update_cached_bps(valid_bps)
end

-- 清除单个断点
function M.clear_single_breakpoint(filepath, line)
	if not filepath or line <= 0 then
		return false
	end

	-- 获取当前存储的断点
	local stored_bps = get_cached_stored_bps()

	-- 检查该文件路径是否存在断点
	if stored_bps[filepath] then
		local valid_bps = {}

		-- 遍历当前文件的断点，移除指定行号的断点
		for _, bp in ipairs(stored_bps[filepath]) do
			if bp.line ~= line then
				table.insert(valid_bps, bp)
			end
		end

		-- 如果移除了该行号的断点，更新存储数据
		if #valid_bps < #stored_bps[filepath] then
			stored_bps[filepath] = valid_bps
			update_cached_bps(stored_bps)
			return true
		end
	end

	return false
end

-- 自动清除光标位置的断点
function M.clear_breakpoint_at_cursor()
	-- 获取当前文件路径和光标行号
	local filepath = vim.fn.expand("%:p") -- 当前文件的绝对路径
	local line = vim.fn.line(".") -- 当前光标所在的行号
	-- 调用清除单个断点的函数
	return M.clear_single_breakpoint(filepath, line)
end

-- 清除存储的断点数据
function M.clear_breakpoints()
	cached_bps = {}
	json_store.delete("dap", "breakpoints")
	return true
end

-- 设置自动保存和自动恢复
function M.setup()
	-- 初始化缓存
	get_cached_stored_bps()

	-- 退出时自动保存（并清理无效数据）
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			M.save_breakpoints()
		end,
		desc = "DAP: 退出时自动保存并清理断点",
	})

	local restore_group = vim.api.nvim_create_augroup("BreakpointAutoRestore", { clear = true })

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = restore_group,
		callback = function()
			-- 延时 2 秒后执行
			vim.defer_fn(function()
				M.cleanup_stored_breakpoints()
				M.restore_breakpoints()
			end, 2000)
		end,
	})

	-- 断点变化时自动保存（使用防抖）
	local save_group = vim.api.nvim_create_augroup("DapBreakpointAutoSave", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = save_group,
		pattern = "DapBreakpointChanged",
		callback = function()
			M.save_breakpoints_debounced()
		end,
		desc = "DAP: 断点变化时智能保存",
	})

	-- 文件删除时清理相关断点
	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(args)
			local filepath = vim.api.nvim_buf_get_name(args.buf)
			local full_path = normalize_path(filepath)

			if full_path and full_path ~= "" then
				-- 延迟执行，给其他操作时间
				vim.defer_fn(function()
					-- 检查文件是否真的被删除了
					if vim.fn.filereadable(full_path) ~= 1 then
						local stored_bps = get_cached_stored_bps()
						if stored_bps[full_path] then
							stored_bps[full_path] = nil
							update_cached_bps(stored_bps)
						end
					end
				end, 1000) -- 延迟1秒检查
			end
		end,
		desc = "DAP: 文件删除时清理断点",
	})

	-- 文件重命名时更新断点
	vim.api.nvim_create_autocmd("BufFilePost", {
		group = group,
		callback = function(args)
			local oldname = vim.v.oldname
			local newname = vim.api.nvim_buf_get_name(args.buf)
			if oldname and oldname ~= "" and newname and newname ~= "" then
				local old_path = normalize_path(oldname)
				local new_path = normalize_path(newname)
				handle_file_rename(old_path, new_path)
			end
		end,
		desc = "DAP: 处理文件重命名",
	})

	return true
end

return M
