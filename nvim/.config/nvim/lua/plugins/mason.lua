-- https://github.com/mason-org/mason.nvim

return {
	"mason-org/mason.nvim",
	event = "VeryLazy", -- 延迟加载，保证启动速度
	cmd = "Mason",
	config = function()
		require("mason").setup()

		-- 使用状态标记，避免重复执行
		if vim.g.mason_auto_installed then
			return
		end

		-- 延迟执行，确保 registry 已加载
		vim.defer_fn(function()
			-- Names must be Mason package names
			local ensure_installed = {
				"lua-language-server",
				"markdown-oxide",
				"codelldb",
				"copilot-language-server",
				"cortex-debug",
				"delve",
				"gofumpt",
				"gopls",
				"js-debug-adapter",
				"rust-analyzer",
				"shfmt",
				"ty",
			}

			local registry = require("mason-registry")

			local to_install = {}
			for _, package_name in ipairs(ensure_installed) do
				if not registry.is_installed(package_name) then
					table.insert(to_install, package_name)
				end
			end

			-- 一次性安装所有缺失的包
			if #to_install > 0 then
				vim.cmd("MasonInstall " .. table.concat(to_install, " "))
			end

			-- 标记已执行
			vim.g.mason_auto_installed = true
		end, 100)
	end,
}
