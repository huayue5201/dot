-- 让 `dir = "~/neovim-plugins/xxx"` 这类本地插件保持同步。
--
-- vim.pack 把本地路径当作「安装源」，会 git clone 一份到
-- pack/core/opt/<name>，之后不再跟随源目录；而 nvim 实际加载的是那份副本。
-- 所以在 ~/neovim-plugins 里提交后，必须手动 fetch + fast-forward 才生效。
-- 这里在启动后异步补上这一步，只做 fast-forward，不会制造合并提交。

local M = {}

---收集 src 是本地目录的已安装插件
---@return { name: string, path: string }[]
local function local_plugins()
	local ok, packs = pcall(vim.pack.get, nil, { info = false })
	if not ok or type(packs) ~= "table" then
		return {}
	end
	local out = {}
	for _, p in ipairs(packs) do
		local src = p.spec and p.spec.src
		if type(src) == "string" and src:sub(1, 1) == "/" and vim.uv.fs_stat(src) then
			out[#out + 1] = { name = p.name or vim.fs.basename(p.path), path = p.path }
		end
	end
	return out
end

---在 dir 下跑一个 git 子命令（异步，回调在主循环里执行）
local function git(dir, argv, on_done)
	vim.system(vim.list_extend({ "git", "-C", dir }, argv), { text = true }, function(res)
		vim.schedule(function()
			on_done(res)
		end)
	end)
end

---把所有本地插件的 pack 副本快进到源仓库的最新提交
---@param opts? { verbose?: boolean, force?: boolean }
function M.sync(opts)
	opts = opts or {}
	local plugins = local_plugins()
	if #plugins == 0 then
		return
	end

	local pending, updated, failed = #plugins, {}, {}

	local function finish()
		pending = pending - 1
		if pending > 0 then
			return
		end
		if #failed > 0 then
			vim.notify("本地插件同步失败: " .. table.concat(failed, ", "), vim.log.levels.WARN)
		end
		if #updated > 0 then
			vim.notify(
				("已同步本地插件: %s（重启 nvim 生效）"):format(table.concat(updated, ", ")),
				vim.log.levels.INFO
			)
		elseif opts.verbose then
			vim.notify("本地插件都是最新的", vim.log.levels.INFO)
		end
	end

	for _, p in ipairs(plugins) do
		-- --force：源仓库被 amend/rebase/reset 过时，远程跟踪分支也要跟着回退
		git(p.path, { "fetch", "--quiet", "--no-tags", "--force", "origin" }, function(res)
			if res.code ~= 0 then
				failed[#failed + 1] = p.name
				return finish()
			end
			-- --left-right --count：左边是副本多出的提交（ahead），右边是源仓库多出的（behind）
			git(p.path, { "rev-list", "--left-right", "--count", "HEAD...@{upstream}" }, function(r)
				local ahead, behind = nil, nil
				if r.code == 0 then
					ahead, behind = (r.stdout or ""):match("^(%d+)%s+(%d+)")
					ahead, behind = tonumber(ahead), tonumber(behind)
				end
				-- 没有上游跟踪分支（detached HEAD 等）就跳过
				if not ahead or (ahead == 0 and behind == 0) then
					return finish()
				end
				if ahead > 0 then
					-- 副本有源仓库里没有的提交（源仓库被 reset / amend 过）。
					-- 副本干净时才能 --force 对齐，否则不动，避免丢掉副本里的改动。
					if not opts.force then
						failed[#failed + 1] = p.name .. "(分叉,可用 :PackLocalSync!)"
						return finish()
					end
					git(p.path, { "status", "--porcelain" }, function(s)
						if s.code ~= 0 or (s.stdout or "") ~= "" then
							failed[#failed + 1] = p.name .. "(副本有未提交改动)"
							return finish()
						end
						git(p.path, { "reset", "--hard", "--quiet", "@{upstream}" }, function(r2)
							if r2.code == 0 then
								updated[#updated + 1] = ("%s(=源仓库)"):format(p.name)
							else
								failed[#failed + 1] = p.name
							end
							finish()
						end)
					end)
					return
				end
				git(p.path, { "merge", "--ff-only", "--quiet", "@{upstream}" }, function(m)
					if m.code == 0 then
						updated[#updated + 1] = ("%s(+%d)"):format(p.name, behind)
					else
						failed[#failed + 1] = p.name
					end
					finish()
				end)
			end)
		end)
	end
end

---@param opts? { delay?: integer }
function M.setup(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("PackLocalSync", function(args)
		M.sync({ verbose = true, force = args.bang })
	end, { desc = "同步本地 dir 插件（git fetch + fast-forward）", bang = true })

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
