-- lua/dap_ext/ft_keys.lua
---@brief 按文件类型收窄的 DAP 键位（buffer-local）
-- 目的：语言专属的调试入口不再全局注册，避免在无关文件里制造键位噪音。
-- 注册的映射只存在于匹配 filetype 的 buffer 上，切到别的 buffer 自动不可见。
--
-- 用法：
--   require("dap_ext.ft_keys").map("<leader>dE", fn, {
--     filetypes = { "rust", "c", "cpp" },
--     desc = "...",
--     cond = function(bufnr) return true end, -- 可选，额外的运行时判定
--   })
--
-- 注意：cond 只在 FileType（以及 refresh）时求值，之后条件变化不会自动生效；
-- 需要重新评估时调用 refresh()（项目类型缓存失效时会自动调用）。
local M = {}

local group = vim.api.nvim_create_augroup("dap_ext_ft_keys", { clear = true })

---@class DapExtFtKeySpec
---@field lhs string
---@field rhs string|function
---@field modes string|string[]
---@field filetypes string[]
---@field desc string?
---@field cond (fun(bufnr: integer): boolean)?
---@field map_opts table?
---@field applied table<integer, true>

---@type DapExtFtKeySpec[]
local specs = {}

-- buffer 被彻底删除后清掉 applied 标记，避免 bufnr 复用时误删别人的映射
vim.api.nvim_create_autocmd("BufWipeout", {
	group = group,
	callback = function(ev)
		for _, spec in ipairs(specs) do
			spec.applied[ev.buf] = nil
		end
	end,
})

local function modes_of(spec)
	if type(spec.modes) == "table" then
		return spec.modes
	end
	return { spec.modes }
end

---@param spec DapExtFtKeySpec
---@param bufnr integer
local function apply(spec, bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end
	if not vim.tbl_contains(spec.filetypes, vim.bo[bufnr].filetype) then
		return
	end
	if spec.cond and not spec.cond(bufnr) then
		return
	end
	local opts = vim.tbl_extend("force", { buffer = bufnr, desc = spec.desc }, spec.map_opts or {})
	vim.keymap.set(spec.modes, spec.lhs, spec.rhs, opts)
	spec.applied[bufnr] = true
end

---@param spec DapExtFtKeySpec
---@param bufnr integer
local function unapply(spec, bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or not spec.applied[bufnr] then
		return
	end
	local matched = vim.tbl_contains(spec.filetypes, vim.bo[bufnr].filetype)
	local allowed = matched and (spec.cond == nil or spec.cond(bufnr))
	if allowed then
		return
	end
	for _, mode in ipairs(modes_of(spec)) do
		pcall(vim.api.nvim_buf_del_keymap, bufnr, mode, spec.lhs)
	end
	spec.applied[bufnr] = nil
end

-- 文件类型变了（rust -> markdown、buffer 被 :setfiletype 改成别的）时回收：
-- FileType 只会「匹配时 apply」，不匹配时没有任何回调，映射会一直留在 buffer 上
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	callback = function(ev)
		for _, spec in ipairs(specs) do
			unapply(spec, ev.buf)
		end
	end,
})

---注册一条只在指定 filetype 的 buffer 中存在的键位
---@param lhs string
---@param rhs string|function
---@param opts { filetypes: string[], desc?: string, modes?: string|string[], cond?: fun(bufnr: integer): boolean, map_opts?: table? }
function M.map(lhs, rhs, opts)
	assert(opts.filetypes and #opts.filetypes > 0, "ft_keys.map: filetypes 不能为空")

	---@type DapExtFtKeySpec
	local spec = {
		lhs = lhs,
		rhs = rhs,
		modes = opts.modes or "n",
		filetypes = opts.filetypes,
		desc = opts.desc,
		cond = opts.cond,
		map_opts = opts.map_opts,
		applied = {},
	}
	table.insert(specs, spec)

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = spec.filetypes,
		callback = function(ev)
			apply(spec, ev.buf)
		end,
	})

	-- adapter setup 可能晚于 FileType：对已经打开的 buffer 补一次
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		apply(spec, buf)
	end

	return spec
end

---重新评估所有已注册键位（条件由真变假时移除，由假变真时补上）
function M.refresh()
	for _, spec in ipairs(specs) do
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			apply(spec, buf)
			unapply(spec, buf)
		end
	end
end

return M
