-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	event = "VeryLazy",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		-- https://github.com/nvim-telescope/telescope-fzf-native.nvim
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		-- https://github.com/nvim-telescope/telescope-dap.nvim
		{ "nvim-telescope/telescope-dap.nvim" },
	},
	keys = {
		{ "<leader>ff", desc = "文件检索" },
		{ "<leader>fg", desc = "字符检索" },
		{ "<leader>fb", desc = "buffer检索" },
		{ "<leader>fo", desc = "历史检索" },
		{ "<leader>fw", desc = "检索光标下的字符" },
	},
	config = function()
		local previewers = require("telescope.previewers")
		local Job = require("plenary.job")
		local new_maker = function(filepath, bufnr, opts)
			filepath = vim.fn.expand(filepath)
			Job:new({
				command = "file",
				args = { "--mime-type", "-b", filepath },
				on_exit = function(j)
					local mime_type = vim.split(j:result()[1], "/")[1]
					if mime_type == "text" then
						previewers.buffer_previewer_maker(filepath, bufnr, opts)
					else
						-- maybe we want to write something to the buffer here
						vim.schedule(function()
							vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "BINARY" })
						end)
					end
				end,
			}):sync()
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "TelescopeResults",
			callback = function(ctx)
				vim.api.nvim_buf_call(ctx.buf, function()
					vim.fn.matchadd("TelescopeParent", "\t\t.*$")
					vim.api.nvim_set_hl(0, "TelescopeParent", { link = "Comment" })
				end)
			end,
		})

		local function filenameFirst(_, path)
			local tail = vim.fs.basename(path)
			local parent = vim.fs.dirname(path)
			if parent == "." then
				return tail
			end
			return string.format("%s\t\t%s", tail, parent)
		end

		local actions = require("telescope.actions")
		require("telescope").setup({
			defaults = {
				buffer_previewer_maker = new_maker, -- 不要预览二进制文件
				-- Default configuration for telescope goes here:
				-- config_key = value,
				mappings = {
					i = {
						-- map actions.which_key to <C-h> (default: <C-/>)
						-- actions.which_key shows the mappings for your picker,
						-- e.g. git_{create, delete, ...}_branch for the git_branches picker
						["<C-h>"] = "which_key",
					},
				},
			},
			pickers = {
				find_files = {
					path_display = filenameFirst,
				},
				buffers = {
					mappings = {
						i = {
							["<c-d>"] = actions.delete_buffer + actions.move_to_top,
						},
					},
					path_display = filenameFirst,
				},
				oldfiles = {
					path_display = filenameFirst,
				},
				-- Default configuration for builtin pickers goes here:
				-- picker_name = {
				--   picker_config_key = value,
				--   ...
				-- }
				-- Now the picker_config_key will be applied every time you call this
				-- builtin picker
			},
			extensions = {
				fzf = {
					fuzzy = true, -- false will only do exact matching
					override_generic_sorter = true, -- override the generic sorter
					override_file_sorter = true, -- override the file sorter
					case_mode = "smart_case", -- or "ignore_case" or "respect_case"
					-- the default case_mode is "smart_case"
				},
			},
		})
		require("telescope").load_extension("dap")
		require("telescope").load_extension("fzf")
		-- 按键映射
		vim.keymap.set(
			"n",
			"<space>ff",
			"<cmd>Telescope find_files<cr>",
			{ desc = "文件检索", silent = true, noremap = true }
		)
		vim.keymap.set(
			"n",
			"<space>fg",
			"<cmd>Telescope live_grep<cr>",
			{ desc = "字符检索", silent = true, noremap = true }
		)
		vim.keymap.set(
			"n",
			"<space>fb",
			"<cmd>Telescope buffers<cr>",
			{ desc = "buffer检索", silent = true, noremap = true }
		)
		vim.keymap.set(
			"n",
			"<space>fo",
			"<cmd>Telescope oldfiles<cr>",
			{ desc = "历史检索", silent = true, noremap = true }
		)
		vim.keymap.set(
			"n",
			"<space>fw",
			"<cmd>Telescope grep_string<cr>",
			{ desc = "检索光标下的字符", silent = true, noremap = true }
		)
	end,
}
