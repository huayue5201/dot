-- https://github.com/mason-org/mason.nvim

return {
	"mason-org/mason.nvim",
	event = "VeryLazy", -- 延迟加载，保证启动速度
	cmd = "Mason",
	config = function()
		require("mason").setup()

		local registry = require("mason-registry")

		------------------------------------------------------------------
		-- 1) 确保工具已安装
		------------------------------------------------------------------
		if not vim.g.mason_auto_installed then
			vim.defer_fn(function()
				-- Names must be Mason package names
				local ensure_installed = {
					"lua-language-server",
					"codelldb",
					"cortex-debug",
					"copilot-language-server",
					-- "delve",
					-- "gofumpt",
					-- "gopls",
					"js-debug-adapter",
					"rust-analyzer",
					"shfmt",
					"ty",
					"stylua",
					"ruff",
					"taplo",
					"dprint",
					-- "harper-ls",
					-- "copilot-language-server",
					"bash-language-server",
					"marksman",
				}

				local to_install = {}
				for _, package_name in ipairs(ensure_installed) do
					if not registry.is_installed(package_name) then
						table.insert(to_install, package_name)
					end
				end

				if #to_install > 0 then
					vim.cmd("MasonInstall " .. table.concat(to_install, " "))
				end

				vim.g.mason_auto_installed = true
			end, 100)
		end

		------------------------------------------------------------------
		-- 2) 自动更新已安装的工具
		--    vim.g.mason_auto_update = false          -- 关闭
		--    vim.g.mason_auto_update_interval = 604800 -- 秒（默认 7 天）
		------------------------------------------------------------------
		local function update_outdated(force)
			if vim.g.mason_auto_update == false and not force then
				return
			end

			local interval = tonumber(vim.g.mason_auto_update_interval) or (7 * 24 * 60 * 60)
			local stamp = vim.fn.stdpath("state") .. "/mason_auto_update"
			local now = os.time()

			if not force then
				local last = 0
				local f = io.open(stamp, "r")
				if f then
					last = tonumber(f:read("*a")) or 0
					f:close()
				end
				if now - last < interval then
					return
				end
			end

			-- 先落时间戳：即使失败也不要在本次会话反复重试
			pcall(function()
				local w = io.open(stamp, "w")
				if w then
					w:write(tostring(now))
					w:close()
				end
			end)

			-- 先刷新注册表，`get_latest_version()` 才是最新的
			registry.update(function(success)
				if not success then
					vim.notify("mason: 注册表更新失败，跳过工具更新", vim.log.levels.WARN)
					return
				end

				local outdated = {}
				for _, pkg in ipairs(registry.get_installed_packages()) do
					local ok1, cur = pcall(function()
						return pkg:get_installed_version()
					end)
					local ok2, latest = pcall(function()
						return pkg:get_latest_version()
					end)
					if ok1 and ok2 and cur ~= latest then
						outdated[#outdated + 1] = pkg
					end
				end

				if #outdated == 0 then
					if force then
						vim.notify("mason: 所有工具均为最新", vim.log.levels.INFO)
					end
					return
				end

				local names = {}
				for _, p in ipairs(outdated) do
					names[#names + 1] = p.name
				end
				vim.notify(
					("mason: 更新 %d 个工具\n%s"):format(#outdated, table.concat(names, ", ")),
					vim.log.levels.INFO
				)

				for _, p in ipairs(outdated) do
					p:install()
				end
			end)
		end

		-- 启动后延迟执行，避免影响启动
		vim.defer_fn(function()
			update_outdated(false)
		end, 5000)

		vim.api.nvim_create_user_command("MasonAutoUpdate", function()
			update_outdated(true)
		end, { desc = "检查并更新 Mason 已安装工具" })
	end,
}
