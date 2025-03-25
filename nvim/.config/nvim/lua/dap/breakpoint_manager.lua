local breakpoints = require("dap.breakpoints")

-- 获取项目根目录
local function get_project_root()
	return vim.fn.finddir(".git", vim.fn.expand("%:p:h") .. ";") or vim.fn.expand("%:p:h")
end

-- 获取缓存文件路径
local function get_cache_file()
	return vim.fn.stdpath("cache") .. "/breakpoints.json"
end

-- 读取文件内容，返回解码后的 JSON 数据
local function read_json_file(filepath)
	local fp = io.open(filepath, "r")
	if not fp then
		return {}
	end -- 如果文件不存在，返回空表

	local content = fp:read("*a")
	fp:close()

	if content == "" then
		return {}
	end -- 如果文件为空，返回空表
	return vim.fn.json_decode(content) or {}
end

-- 将数据写入文件
local function write_json_file(filepath, data)
	local fp = io.open(filepath, "w")
	if not fp then
		print("无法写入断点文件")
		return false
	end

	fp:write(vim.fn.json_encode(data))
	fp:close()
	return true
end

-- 存储断点
local function store_breakpoints()
	local bps = {}
	local breakpoints_by_buf = breakpoints.get()

	-- 获取每个缓冲区的断点
	for buf, buf_bps in pairs(breakpoints_by_buf) do
		bps[tostring(buf)] = buf_bps
	end

	local filepath = get_cache_file() -- 获取断点文件路径
	local existing_bps = read_json_file(filepath)
	existing_bps[get_project_root()] = bps

	-- 将更新后的内容写回文件
	if not write_json_file(filepath, existing_bps) then
		print("无法保存断点")
	end
end

-- 加载断点
local function load_breakpoints()
	local filepath = get_cache_file() -- 获取断点文件路径
	local bps = read_json_file(filepath)

	-- 获取当前项目的断点数据
	local project_bps = bps[get_project_root()]

	-- 如果该项目没有断点数据
	if not project_bps then
		print("该项目没有保存的断点")
		return
	end

	-- 重新设置断点
	for buf, buf_bps in pairs(project_bps) do
		for _, bp in pairs(buf_bps) do
			local opts = {
				condition = bp.condition,
				log_message = bp.logMessage,
				hit_condition = bp.hitCondition,
			}
			breakpoints.set(opts, tonumber(buf), bp.line)
		end
	end
	print("断点已成功加载")
end

-- 在 Neovim 启动时加载断点
vim.api.nvim_create_autocmd("VimEnter", {
	callback = load_breakpoints, -- 加载断点
})

-- 在 Neovim 退出时保存断点
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = store_breakpoints, -- 保存断点
})
