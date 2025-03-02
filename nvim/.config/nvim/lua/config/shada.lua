-- 工作区配置 (shada 文件)
vim.opt.exrc = true -- 启用 exrc 配置
vim.opt.secure = true -- 启用安全模式

-- 生成唯一的 shada 文件路径
local workspace_path = vim.fn.getcwd()
local data_dir = vim.fn.stdpath("data")
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") .. "_" .. vim.fn.sha256(workspace_path):sub(1, 8)
local shadafile = data_dir .. "/shada/" .. unique_id .. ".shada"
vim.opt.shadafile = shadafile

-- 清理过期的 shada 文件 (超过 7 天)
local function cleanup_shada()
	local days_old = 7
	local current_time = os.time()
	local shada_files = vim.fn.glob(data_dir .. "/shada/*.shada", true, true)
	if #shada_files == 0 then
		return -- 没有 shada 文件，直接返回
	end
	for _, filename in ipairs(shada_files) do
		local file_time = vim.fn.getftime(filename)
		-- 处理文件时间错误
		if file_time == -1 then
			vim.notify("Unable to get file time for: " .. filename, vim.log.levels.WARN)
			return
		end

		local age_in_days = os.difftime(current_time, file_time) / (24 * 60 * 60)

		if age_in_days > days_old then
			local success, err = pcall(vim.fn.delete, filename) -- 安全删除文件
			if not success then
				vim.notify("Error deleting file: " .. filename .. " - " .. err, vim.log.levels.ERROR)
			else
				print("Deleted file: " .. filename)
			end
		end
	end
end
-- 设置定时器每隔一天清理一次 shada 文件
vim.defer_fn(function()
	cleanup_shada()
end, 86400) -- 86400 秒 = 1 天
