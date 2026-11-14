-- 本地插件（spec 里写 `dir = "~/neovim-plugins/x"`）现在由 boot/pack.lua 直接插进
-- 'runtimepath'，不再交给 vim.pack：
--
--   * 改完代码重启就好 —— 没有 clone 副本、没有锁文件 rev、没有「commit + 同步」
--   * 忘了同步就加载旧代码这类坑从根上消失（lazy.nvim 的 dev 模式是同一个思路）
--   * build 仍然会跑（首次与 git rev 变化时），cwd 就是工作区目录
--
-- 这个模块只剩一件事：vim.pack 时代给本地插件留下的副本还在 pack/core/opt 下，
-- `:PackLocalSync` 会列出它们，`:PackLocalSync!` 删除（源码在工作区，删副本不会丢东西）。

local M = {}

-- 由 boot/pack.lua 在 setup 时注入，避免反向 require("boot.pack") 形成循环依赖
-- （pack.lua 在模块体里就调 setup，那时 package.loaded["boot.pack"] 还没写进去）
local dev_names = function()
	return {}
end
local pack_root = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")

---本地插件在 vim.pack 里遗留的克隆副本目录
---@return string[]
local function stale_clones()
	local dirs = {}
	for _, name in ipairs(dev_names()) do
		local dir = vim.fs.joinpath(pack_root, name)
		if vim.uv.fs_stat(dir) then
			dirs[#dirs + 1] = dir
		end
	end
	return dirs
end

---@param opts? { verbose?: boolean, force?: boolean }
function M.sync(opts)
	opts = opts or {}
	local dirs = stale_clones()
	if #dirs == 0 then
		if opts.verbose then
			vim.notify("本地插件直接读工作区，没有副本需要同步", vim.log.levels.INFO)
		end
		return
	end
	if not opts.force then
		vim.notify(
			("本地插件已改为直接加载（改完重启即可），这些旧副本可以删：\n%s\n:PackLocalSync! 删除"):format(
				table.concat(dirs, "\n")
			),
			vim.log.levels.WARN
		)
		return
	end
	local failed = {}
	for _, dir in ipairs(dirs) do
		-- 只删目录没用：锁文件里还留着这条（src 是本地绝对路径），下次启动 vim.pack
		-- 会按锁文件把目录重新造出来。vim.pack.del 同时清目录和锁文件。
		local name = vim.fs.basename(dir)
		local del_ok = pcall(vim.pack.del, { name }, { force = true })
		if vim.uv.fs_stat(dir) then
			-- vim.pack.del 没删掉才兜底（例如锁文件里没有这条）：但只删目录的话锁条目
			-- 还在，下次启动会被 lock_sync 造回来 —— 所以额外把锁条目一并清掉
			pcall(vim.fn.delete, dir, "rf")
			if not del_ok then
				local lock = {}
				for n in pairs(require("boot.pack").lock_plugins()) do
					lock[n] = true
				end
				if lock[name] then
					vim.notify(
						("锁文件里还有 %s，删目录后可能被重建（:PackPrune 可复查）"):format(name),
						vim.log.levels.WARN
					)
				end
			end
		end
		if vim.uv.fs_stat(dir) then
			failed[#failed + 1] = dir
		end
	end
	if #failed > 0 then
		vim.notify("删除副本失败:\n" .. table.concat(failed, "\n"), vim.log.levels.ERROR)
	else
		vim.notify(("已删除 %d 个旧副本（本地插件继续读工作区）"):format(#dirs), vim.log.levels.INFO)
	end
end

---@param opts? { keymap?: string|false, dev_names?: fun(): string[], pack_root?: string }
function M.setup(opts)
	opts = opts or {}
	if opts.dev_names then
		dev_names = opts.dev_names
	end
	if opts.pack_root then
		pack_root = opts.pack_root
	end
	vim.api.nvim_create_user_command("PackLocalSync", function(cmd)
		M.sync({ verbose = true, force = cmd.bang })
	end, { desc = "本地插件的旧 vim.pack 副本（! 删除）", bang = true })

	if opts.keymap ~= false then
		vim.keymap.set("n", opts.keymap or "<leader>zp", function()
			M.sync({ verbose = true })
		end, { silent = true, desc = "Pack: 本地插件副本检查（! 删除）" })
	end
end

return M
