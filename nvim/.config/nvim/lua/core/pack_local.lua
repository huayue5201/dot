-- 让 `dir = "~/neovim-plugins/xxx"` 这类本地插件保持同步。
--
-- vim.pack 把本地路径当作「安装源」，会 git clone 一份到 pack/core/opt/<name>，
-- 并以 detached HEAD 钉在锁文件的 rev 上；nvim 实际加载的是那份副本。
-- 所以在 ~/neovim-plugins 里提交后，需要走 `vim.pack.update` 才能让副本跟上
--（它会 fetch、检出最新 rev 并改写锁文件）。这里在启动后异步补上这一步。

local M = {}

---收集 src 是本地目录的已安装插件
---@return string[] names
local function local_plugin_names()
	local ok, packs = pcall(vim.pack.get, nil, { info = false })
	if not ok or type(packs) ~= "table" then
		return {}
	end
	local names = {}
	for _, p in ipairs(packs) do
		local src = p.spec and p.spec.src
		if type(src) == "string" and src:sub(1, 1) == "/" and vim.uv.fs_stat(src) then
			names[#names + 1] = p.name or vim.fs.basename(p.path)
		end
	end
	return names
end

---读取锁文件里各插件的 rev
---@return table<string, string>
local function lock_revs()
	local ok, lines = pcall(vim.fn.readfile, vim.o.packlockfile)
	if not ok then
		return {}
	end
	local decoded_ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decoded_ok or type(data) ~= "table" or type(data.plugins) ~= "table" then
		return {}
	end
	local revs = {}
	for name, entry in pairs(data.plugins) do
		if type(entry) == "table" and type(entry.rev) == "string" then
			revs[name] = entry.rev
		end
	end
	return revs
end

---把所有本地插件的 pack 副本更新到源仓库的最新提交
---@param opts? { verbose?: boolean }
function M.sync(opts)
	opts = opts or {}
	local names = local_plugin_names()
	if #names == 0 then
		return
	end

	local before = lock_revs()
	local ok, err = pcall(vim.pack.update, names, { force = true })

	vim.schedule(function()
		if not ok then
			vim.notify("本地插件同步失败: " .. tostring(err), vim.log.levels.WARN)
			return
		end
		local after = lock_revs()
		local updated = {}
		for _, name in ipairs(names) do
			if before[name] ~= after[name] then
				updated[#updated + 1] = name
			end
		end
		if #updated > 0 then
			vim.notify(
				("已同步本地插件: %s（重启 nvim 生效）"):format(table.concat(updated, ", ")),
				vim.log.levels.INFO
			)
		elseif opts.verbose then
			vim.notify("本地插件都是最新的", vim.log.levels.INFO)
		end
	end)
end

---@param opts? { delay?: integer }
function M.setup(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("PackLocalSync", function()
		M.sync({ verbose = true })
	end, { desc = "同步本地 dir 插件（vim.pack.update）" })

	-- 不阻塞启动：VimEnter 后再等一小会儿，让首屏先画出来
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			vim.defer_fn(function()
				M.sync()
			end, opts.delay or 1000)
		end,
	})
end

return M
