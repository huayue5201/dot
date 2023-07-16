-- https://github.com/nvim-lualine/lualine.nvim

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy", -- keep for lazy loading
	config = function()
		-- 禁用 showmode， lualine 已经显示了当前模式
		vim.opt.showmode = false

		-- 在较小的窗口中禁用组件显示
		local function trunc(trunc_width, trunc_len, hide_width, no_ellipsis)
			return function(str)
				local win_width = vim.fn.winwidth(0)
				if hide_width and win_width < hide_width then
					return ""
				elseif trunc_width and trunc_len and win_width < trunc_width and #str > trunc_len then
					return str:sub(1, trunc_len) .. (no_ellipsis and "" or "...")
				end
				return str
			end
		end

		require("lualine").setup({
			options = {
				-- theme = "auto",
				component_separators = { left = "󰷫", right = "" },
				  section_separators = { left = '', right = ''},
			},
			sections = {
				-- noice集成配置
				lualine_x = {
					{
						require("noice").api.status.message.get_hl,
						cond = require("noice").api.status.message.has,
					},
					{
						require("noice").api.status.command.get,
						cond = require("noice").api.status.command.has,
						color = { fg = "#ff9e64" },
					},
					{
						require("noice").api.status.mode.get,
						cond = require("noice").api.status.mode.has,
						color = { fg = "#ff9e64" },
					},
					{
						require("noice").api.status.search.get,
						cond = require("noice").api.status.search.has,
						color = { fg = "#ff9e64" },
					},
				},
				lualine_a = {
					{ "mode", fmt = trunc(80, 4, nil, true) },
					{
						function()
							return require("lsp-status").status()
						end,
						fmt = trunc(120, 20, 60),
					},
				},
			},
		})
	end,
}
