-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		_G.__cached_neo_tree_selector = nil
		_G.__get_selector = function()
			return _G.__cached_neo_tree_selector
		end

		local icons = require("config.utils").icons.diagnostic
		require("bufferline").setup({
			options = {
				separator_style = "thin",
				custom_filter = function(buf) -- 过滤qf缓冲区
					local excluded_filetypes = { "qf", "help", "terminal", "fugitive" }
					local excluded_buftypes = { "terminal", "acwrite", "nofile" }
					local filetype = vim.bo[buf].filetype
					local buftype = vim.bo[buf].buftype
					return not vim.tbl_contains(excluded_filetypes, filetype)
						and not vim.tbl_contains(excluded_buftypes, buftype)
				end,
				-- numbers = "ordinal", -- 显示buffer的编号
				numbers = function(opts)
					return string.format("%s·%s", opts.raise(opts.id), opts.lower(opts.ordinal))
				end,
				max_name_length = 10, -- buffer名称的最大长度
				max_prefix_length = 8, -- 去重时的前缀长度
				tab_size = 10, -- tab的大小
				diagnostics = "nvim_lsp", -- 开启诊断提示，来源为nvim_lsp
				diagnostics_indicator = function(count, level) -- 诊断提示的图标和数量显示
					local icon = level:match("error") and icons.ERROR or icons.WARN
					return "" .. icon .. count
				end,
				toggle_hidden_on_enter = true, -- 重新进入隐藏的组时，自动展开
				items = {
					{
						name = "🧠 Code",
						icon = "",
						matcher = function(buf)
							return buf.filename:match("%.rs")
								and not buf.filename:match("test")
								and not buf.filename:match("examples")
						end,
					},
					{
						name = "🧪 Tests",
						icon = "",
						matcher = function(buf)
							return buf.filename:match("test") or buf.filename:match("spec")
						end,
					},
					{
						name = "📄 Docs",
						icon = "",
						matcher = function(buf)
							return buf.filename:match("%.md") or buf.filename:match("%.txt")
						end,
					},
					{
						name = "🧰 Cargo",
						icon = "",
						matcher = function(buf)
							return buf.filename:match("Cargo.toml") or buf.filename:match("Cargo.lock")
						end,
					},
					{
						name = "🔧 Config",
						icon = "",
						matcher = function(buf)
							return buf.path:match("%.vscode")
								or buf.path:match("nvim")
								or buf.filename:match("%.lua")
								or buf.filename:match("%.json")
						end,
					},
					{
						name = "🧪 Examples",
						icon = "",
						matcher = function(buf)
							return buf.path:match("/examples/")
						end,
					},
					{
						name = "🔍 Logs",
						icon = "",
						matcher = function(buf)
							return buf.filename:match("%.log")
								or buf.filename:match("rtt")
								or buf.filename:match("probe")
						end,
					},
				},
				offsets = { -- 侧边栏偏移设置
					{
						filetype = "neo-tree",
						text = "󰙅 File explorer",
						raw = " %{%v:lua.__get_selector()%} ",
						highlight = { sep = { link = "WinSeparator" } },
						separator = "┃",
					},
					{
						filetype = "aerial",
						text = " Symbols",
						highlight = { sep = { link = "WinSeparator" } },
						separator = "┃",
					},
				},
				hover = { -- 鼠标悬停设置
					enabled = true, -- 开启鼠标悬停
					delay = 50, -- 悬停延迟时间
					reveal = { "close" }, -- 悬停时显示的内容
				},
			},
		})

		-- 跳转至可见位置
		for i = 1, 9 do
			vim.keymap.set(
				"n",
				"<leader>tb" .. i,
				"<Cmd>BufferLineGoToBuffer " .. i .. "<CR>",
				{ silent = true, desc = "Go to buffer " .. i }
			)
		end
		vim.keymap.set("n", "<leader>tbp", "<cmd>BufferLineTogglePin<cr>", { desc = "图钉📌" })
		vim.keymap.set("n", "gb", "<cmd>BufferLinePick<CR>", { desc = "跳转到任意可见标签" })
		vim.keymap.set("n", "<leader>tbr", "<cmd>BufferLinePickClose<CR>", { desc = "删除任意可见标签" })
		vim.keymap.set("n", "<leader>tbR", "<cmd>BufferLineCloseOthers<cr>", { desc = "删除其他所有buffers" })
	end,
}
