-- 让 `dir = "~/neovim-plugins/xxx"` 这类本地插件保持同步。
--
-- vim.pack 把本地路径当作「安装源」，会 git clone 一份到 pack/core/opt/<name>，
-- 并以 detached HEAD 钉在锁文件的 rev 上；nvim 实际加载的是那份副本。
-- 所以在 ~/neovim-plugins 里提交后，需要走 `vim.pack.update` 才能让副本跟上
--（它会 fetch、检出最新 rev 并改写锁文件）。这里改为手动触发：<leader>zp
--（工具分组），或执行 :PackLocalSync。

local M = {}

---收集 src 是本地目录的已安装插件
---@return string[] names
local function local_plugin_names()
	local names = {}
	for _, p in ipairs(vim.pack.get(nil, { info = false })) do
		local src = p.spec.src
		if type(src) == "string" and src:sub(1, 1) == "/" and vim.uv.fs_stat(src) then
			names[#names + 1] = p.spec.name
		end
	end
	return names
end

---当前锁文件里每个插件钉住的 rev
---（info=false 时 vim.pack.get 返回的 rev 就是锁文件的值，不必自己解析 json）
---@return table<string, string>
local function lock_revs()
	local revs = {}
	for _, p in ipairs(vim.pack.get(nil, { info = false })) do
		revs[p.spec.name] = p.rev
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

---@param opts? { keymap?: string|false }
function M.setup(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("PackLocalSync", function()
		M.sync({ verbose = true })
	end, { desc = "同步本地 dir 插件（vim.pack.update）" })

	-- 不自动同步：只在需要时手动触发（工具分组 <leader>z + p(pack)）
	if opts.keymap ~= false then
		vim.keymap.set("n", opts.keymap or "<leader>zp", function()
			M.sync({ verbose = true })
		end, { silent = true, desc = "Pack: 同步本地 dir 插件（重启生效）" })
	end
end

return M
