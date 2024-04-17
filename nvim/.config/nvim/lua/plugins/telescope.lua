-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	-- event = "VeryLazy",
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
		-- https://github.com/nvim-telescope/telescope-fzf-native.nvim
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	keys = {
		{ "<leader>ff", desc = "文件检索" },
		{ "<leader>fg", desc = "字符检索" },
		{ "<leader>fo", desc = "历史检索" },
		{ "<leader>fw", desc = "检索光标下的字符" },
	},
	config = function()
		-- 导入 Telescope 插件中的预览器模块和异步任务模块
		local previewers = require("telescope.previewers")
		local Job = require("plenary.job")

		-- 定义一个新的预览器生成函数
		local new_maker = function(filepath, bufnr, opts)
			-- 将文件路径展开为绝对路径
			filepath = vim.fn.expand(filepath)
			-- 创建一个新的异步任务来获取文件的 MIME 类型
			Job:new({
				command = "file",
				args = { "--mime-type", "-b", filepath },
				on_exit = function(j)
					-- 解析 MIME 类型并获取其主类型
					local mime_type = vim.split(j:result()[1], "/")[1]
					-- 如果是文本类型，则使用默认的文件预览器
					if mime_type == "text" then
						previewers.buffer_previewer_maker(filepath, bufnr, opts)
					else
						-- 否则，在缓冲区中显示 "BINARY"
						vim.schedule(function()
							vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "BINARY" })
						end)
					end
				end,
			}):sync()
		end

		-- 设置自动命令，当 FileType 为 TelescopeResults 时触发
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "TelescopeResults",
			callback = function(ctx)
				-- 在当前缓冲区中添加匹配规则，用于高亮显示结果
				vim.api.nvim_buf_call(ctx.buf, function()
					vim.fn.matchadd("TelescopeParent", "\t\t.*$")
					vim.api.nvim_set_hl(0, "TelescopeParent", { link = "Comment" })
				end)
			end,
		})

		-- 定义一个函数，用于在文件名之前添加其父目录名
		local function filenameFirst(_, path)
			local tail = vim.fn.fnamemodify(path, ":t")
			local parent = vim.fn.fnamemodify(path, ":h")
			if parent == "." then
				return tail
			end
			return string.format("%s\t\t%s", tail, parent)
		end

		-- 导入 Telescope 插件中的动作模块
		local actions = require("telescope.actions")

		-- 配置 Telescope 插件的默认设置
		require("telescope").setup({
			defaults = {
				buffer_previewer_maker = new_maker, -- 不要预览二进制文件
				mappings = {
					i = {
						-- 将 <C-h> 映射到 actions.which_key（默认：<C-/>）
						-- actions.which_key 用于显示选择器的键位映射
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
							-- 将 <c-d> 映射到 actions.delete_buffer + actions.move_to_top
							["<c-d>"] = actions.delete_buffer + actions.move_to_top,
						},
					},
					path_display = filenameFirst,
				},
				oldfiles = {
					path_display = filenameFirst,
				},
			},
			extensions = {
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
					case_mode = "smart_case",
				},
			},
		})

		-- 加载 Telescope 插件的扩展
		require("telescope").load_extension("fzf")

		-- 设置键盘映射
		vim.keymap.set("n", "<space>ff", "<cmd>Telescope find_files<cr>", { desc = "文件检索" })
		vim.keymap.set("n", "<space>fg", "<cmd>Telescope live_grep<cr>", { desc = "字符检索" })
		vim.keymap.set("n", "<space>fo", "<cmd>Telescope oldfiles<cr>", { desc = "历史检索" })
		vim.keymap.set("n", "<space>fw", "<cmd>Telescope grep_string<cr>", { desc = "检索光标下的字符" })
	end,
}
