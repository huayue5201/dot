-- https://github.com/nvim-lualine/lualine.nvim

return {
	"nvim-lualine/lualine.nvim",
	-- https://github.com/nvim-tree/nvim-web-devicons
	dependencies = "nvim-tree/nvim-web-devicons",
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

		-- 添加窗口编号
		local function window()
			return vim.api.nvim_win_get_number(0)
		end

		local custom_fname = require("lualine.components.filename"):extend()
		local highlight = require("lualine.highlight")
		local default_status_colors = { saved = "#228B22", modified = "#C70039" }

		-- 根据修改后的状态更改文件名颜色
		function custom_fname:init(options)
			custom_fname.super.init(self, options)
			self.status_colors = {
				saved = highlight.create_component_highlight_group(
					{ bg = default_status_colors.saved },
					"filename_status_saved",
					self.options
				),
				modified = highlight.create_component_highlight_group(
					{ bg = default_status_colors.modified },
					"filename_status_modified",
					self.options
				),
			}
			if self.options.color == nil then
				self.options.color = ""
			end
		end

		function custom_fname:update_status()
			local data = custom_fname.super.update_status(self)
			data = highlight.component_format_highlight(
				vim.bo.modified and self.status_colors.modified or self.status_colors.saved
			) .. data
			return data
		end

		require("lualine").setup({
			options = {
				component_separators = { left = "󰷫", right = "" },
				section_separators = { left = "", right = "" },
			},
			disabled_filetypes = {
				statusline = {},
				winbar = {},
			},
			sections = {
				lualine_a = {
					{ window },
					{ "mode", fmt = trunc(80, 4, nil, true) },
					{
						function()
							return require("lsp-status").status()
						end,
						fmt = trunc(120, 20, 60),
					},
				},
				lualine_c = { custom_fname },
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
			},
		})
	end,
}
