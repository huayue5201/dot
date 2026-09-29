-- lua/dap-config/persist.lua
---@brief DAP「项目级记忆」：记住每个项目上次运行的调试配置，并在下次优先复用
-- 落地方式：
--   1. 监听 dap.listeners.before.launch 记录本次配置（按 buffer 所属项目）
--   2. 用 nvim-store3 项目存储持久化
--   3. 包装所有 provider：把「上次配置」抽到最前面的 00.last provider，其余 provider 去重
--      → picker 里上次配置永远排第一
--   4. 提供 :DapContinueLast / <leader>dL 直接运行上次配置（无 picker）
local M = {}

local KEY = "dap.last_config"

---最近一次触发 provider 的 buffer（用于 launch 时定位项目）
---@type integer|nil
local pending_bufnr = nil

---setup 前抓取的原始 provider（用于不受包装影响地完整收集配置）
---@type table<string, fun(bufnr: integer): table[]>
local originals = {}
local installed = false

---@param bufnr integer|nil
---@return table|nil
local function store(bufnr)
	local ok, nvim_store = pcall(require, "nvim-store3")
	if not ok then
		return nil
	end
	local name = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""
	if name ~= "" and not name:match("^%a[%w+.-]*://") then
		return nvim_store.project({ from = name })
	end
	return nvim_store.project()
end

---记录本次 launch 的来源 buffer
---@param bufnr integer|nil
function M.note_bufnr(bufnr)
	pending_bufnr = bufnr
end

---保存「上次使用的配置」
---@param config table|nil
---@param bufnr integer|nil
function M.set_last(config, bufnr)
	if not config or type(config.name) ~= "string" then
		return
	end
	local s = store(bufnr)
	if s then
		s:set(KEY, { name = config.name, type = config.type })
	end
end

---读取「上次使用的配置」
---@param bufnr integer|nil
---@return table|nil
function M.get_last(bufnr)
	local s = store(bufnr)
	if not s then
		return nil
	end
	local v = s:get(KEY)
	if type(v) == "table" and type(v.name) == "string" then
		return v
	end
	return nil
end

---清除当前项目的记录
---@param bufnr integer|nil
function M.clear(bufnr)
	local s = store(bufnr)
	if s then
		s:delete(KEY)
	end
end

---判断某配置是否为「上次使用的配置」
---@param c table
---@param last table|nil
---@return boolean
local function matches_last(c, last)
	return last ~= nil and c.name == last.name and (last.type == nil or c.type == last.type)
end

---从原始 provider 完整收集当前 buffer 的所有配置
---@param bufnr integer
---@return table[]
local function collect_original(bufnr)
	local all = {}
	local names = vim.tbl_keys(originals)
	table.sort(names)
	for _, name in ipairs(names) do
		local ok, configs = pcall(originals[name], bufnr)
		if ok and type(configs) == "table" then
			vim.list_extend(all, configs)
		end
	end
	return all
end

---收集当前 buffer 的所有可用配置（复刻 nvim-dap 的拼装逻辑）
---@param bufnr integer|nil
---@return table[]
function M.all_configs(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	M.note_bufnr(bufnr)
	if next(originals) == nil then
		-- 兜底：未 setup 时直接用当前 providers
		local dap = require("dap")
		local all = {}
		local names = vim.tbl_keys(dap.providers.configs)
		table.sort(names)
		for _, name in ipairs(names) do
			local ok, configs = pcall(dap.providers.configs[name], bufnr)
			if ok and type(configs) == "table" then
				vim.list_extend(all, configs)
			end
		end
		return all
	end
	return collect_original(bufnr)
end

---按记录查找仍存在的配置
---@param last table
---@param bufnr integer|nil
---@return table|nil
function M.find_last(last, bufnr)
	for _, c in ipairs(M.all_configs(bufnr)) do
		if matches_last(c, last) then
			return c
		end
	end
	return nil
end

---智能 continue：有记录且仍存在 → 直接运行；否则走原生选择器
---@param bufnr integer|nil
function M.continue_last(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local last = M.get_last(bufnr)
	if last then
		local cfg = M.find_last(last, bufnr)
		if cfg then
			require("dap").run(cfg)
			return
		end
		vim.notify("上次的调试配置已不存在，改为打开选择器", vim.log.levels.INFO)
	end
	require("dap").continue()
end

---初始化：记录 launch + 包装 provider + 注册命令
function M.setup()
	if installed then
		return
	end
	installed = true
	local dap = require("dap")

	-- 1) 记录本次 launch 使用的配置
	dap.listeners.before.launch["dap_config_persist"] = function(session)
		M.set_last(session.config, pending_bufnr or vim.api.nvim_get_current_buf())
	end

	-- 2) 抓取原始 provider
	for name, fn in pairs(dap.providers.configs) do
		originals[name] = fn
	end

	-- 3) 包装 provider：记录 buffer + 剔除「上次配置」（避免重复）
	for name, fn in pairs(originals) do
		dap.providers.configs[name] = function(bufnr)
			M.note_bufnr(bufnr)
			local configs = fn(bufnr)
			if type(configs) ~= "table" then
				return configs
			end
			local last = M.get_last(bufnr)
			if not last then
				return configs
			end
			local out = {}
			for _, c in ipairs(configs) do
				if not matches_last(c, last) then
					out[#out + 1] = c
				end
			end
			return out
		end
	end

	-- 4) 用排在最前的 provider 把「上次配置」放到首位
	dap.providers.configs["00.last"] = function(bufnr)
		local last = M.get_last(bufnr)
		if not last then
			return {}
		end
		local cfg = M.find_last(last, bufnr)
		return cfg and { cfg } or {}
	end

	-- 5) 命令
	vim.api.nvim_create_user_command("DapContinueLast", function()
		M.continue_last(0)
	end, { desc = "运行本项目上次使用的调试配置" })

	vim.api.nvim_create_user_command("DapForgetLast", function()
		M.clear(0)
		vim.notify("已清除本项目的调试配置记录", vim.log.levels.INFO)
	end, { desc = "清除本项目的调试配置记录" })
end

return M
