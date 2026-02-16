-- https://github.com/chrisgrieser/nvim-genghis

return {
	"chrisgrieser/nvim-genghis",
	event = "VeryLazy",
	config = function()
		require("genghis").setup({
			fileOperations = {
				-- 没有扩展名时自动保持原有扩展名
				-- （第一个非开头的点之后的所有内容被视为扩展名）
				autoAddExt = true,

				trashCmd = function()
					if jit.os == "OSX" then
						return "trash"
					end -- macOS 14 内置命令
					if jit.os == "Windows" then
						return "trash"
					end
					if jit.os == "Linux" then
						return { "gio", "trash" }
					end
					return "trash-cli"
				end,

				ignoreInFolderSelection = { -- 使用 Lua 模式匹配（例如，需要转义 `-` 为 `%-`）
					"/node_modules/", -- Node.js
					"/typings/", -- Python
					"/doc/", -- Vim 帮助文件文件夹
					"%.app/", -- macOS 伪文件夹
					"/%.", -- 隐藏文件夹
				},
			},

			navigation = {
				onlySameExtAsCurrentFile = false,
				ignoreDotfiles = true,
				ignoreExt = { "png", "svg", "webp", "jpg", "jpeg", "gif", "pdf", "zip" },
				ignoreFilesWithName = { ".DS_Store" },
			},

			successNotifications = true,

			icons = { -- 设为空字符串以禁用图标
				chmodx = "󰒃",
				copyFile = "󱉥",
				copyPath = "󰅍",
				duplicate = "",
				file = "󰈔",
				move = "󰪹",
				new = "󰝒",
				nextFile = "󰖽",
				prevFile = "󰖿",
				rename = "󰑕",
				trash = "󰩹",
			},
		})

		vim.keymap.set("n", "<leader>ea", ":Genghis createNewFile<CR>", { desc = "在当前目录创建新文件" })
		vim.keymap.set(
			"n",
			"<leader>en",
			":Genghis createNewFileInFolder<CR>",
			{ desc = "在选择的文件夹中创建新文件" }
		)
		vim.keymap.set("n", "<leader>ed", ":Genghis duplicateFile<CR>", { desc = "复制当前文件" })
		vim.keymap.set(
			"n",
			"<leader>em",
			":Genghis moveSelectionToNewFile<CR>",
			{ desc = "将选中内容移动到新文件" }
		)
		vim.keymap.set("n", "<leader>er", ":Genghis renameFile<CR>", { desc = "重命名当前文件" })
		vim.keymap.set(
			"n",
			"<leader>ev",
			":Genghis moveToFolderInCwd<CR>",
			{ desc = "将当前文件移动到工作目录下的文件夹" }
		)
		vim.keymap.set("n", "<leader>ew", ":Genghis moveAndRenameFile<CR>", { desc = "移动并重命名当前文件" })
		vim.keymap.set("n", "<leader>ex", ":Genghis chmodx<CR>", { desc = "设置当前文件为可执行" })
		vim.keymap.set("n", "<leader>et", ":Genghis trashFile<CR>", { desc = "将当前文件移动到回收站" })
		vim.keymap.set(
			"n",
			"<leader>eo",
			":Genghis showInSystemExplorer<CR>",
			{ desc = "在系统资源管理器中显示文件" }
		)
	end,
}
