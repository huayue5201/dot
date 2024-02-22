-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		-- https://github.com/nvim-telescope/telescope-fzf-native.nvim
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
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
				buffers = {
					mappings = {
						i = {
							["<c-d>"] = actions.delete_buffer + actions.move_to_top,
						},
					},
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
		require("telescope").load_extension("fzf")
		-- 按键映射
		vim.keymap.set("n", "<space>ff", "<cmd>Telescope find_files<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>fg", "<cmd>Telescope live_grep<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>fb", "<cmd>Telescope buffers<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>fo", "<cmd>Telescope oldfiles<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>fw", "<cmd>Telescope grep_string<cr>", { silent = true, noremap = true })
	end,
}
