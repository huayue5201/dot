-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	event = "UIEnter",
	config = function()
		require("scope").setup({
			hooks = {
				pre_tab_leave = function()
					vim.api.nvim_exec_autocmds("User", { pattern = "ScopeTabLeavePre" })
					-- [other statements]
				end,

				post_tab_enter = function()
					vim.api.nvim_exec_autocmds("User", { pattern = "ScopeTabEnterPost" })
					-- [other statements]
				end,
			},
		})
	end,
}
