-- https://github.com/williamboman/mason.nvim

return {
	"williamboman/mason.nvim",
	event = { "BufReadPost", "BufNewFile" },
	cmd = {
		"Mason",
		"MasonUpdate",
		"MasonInstall",
		"MasonUninstall",
	},
	config = function()
		require("mason").setup()
		-- 自动安装与更新mason
		vim.api.nvim_create_user_command("MasonInstallAll", function()
			local packages = table.concat(opts.ensure_installed, " ")
			vim.cmd("MasonInstall " .. packages)
		end, {})
	end,
}
