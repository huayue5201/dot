-- https://github.com/chrisgrieser/nvim-genghis

return {
	"chrisgrieser/nvim-genghis",
	event = "VeryLazy",
	config = function()
		require("genghis").setup({
			fileOperations = {
				-- automatically keep the extension when no file extension is given
				-- (everything after the first non-leading dot is treated as the extension)
				autoAddExt = true,

				trashCmd = function() ---@type fun(): string|string[]
					if jit.os == "OSX" then
						return "trash"
					end -- builtin since macOS 14
					if jit.os == "Windows" then
						return "trash"
					end
					if jit.os == "Linux" then
						return { "gio", "trash" }
					end
					return "trash-cli"
				end,

				ignoreInFolderSelection = { -- using lua pattern matching (e.g., escape `-` as `%-`)
					"/node_modules/", -- nodejs
					"/typings/", -- python
					"/doc/", -- vim help files folders
					"%.app/", -- macOS pseudo-folders
					"/%.", -- hidden folders
				},
			},

			navigation = {
				onlySameExtAsCurrentFile = false,
				ignoreDotfiles = true,
				ignoreExt = { "png", "svg", "webp", "jpg", "jpeg", "gif", "pdf", "zip" },
				ignoreFilesWithName = { ".DS_Store" },
			},

			successNotifications = true,

			icons = { -- set an icon to empty string to disable it
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

		vim.keymap.set(
			"n",
			"<leader>ea",
			":Genghis createNewFile<CR>",
			{ desc = "Create a new file in the same directory" }
		)
		vim.keymap.set(
			"n",
			"<leader>en",
			":Genghis createNewFileInFolder<CR>",
			{ desc = "Create a new file in a folder" }
		)
		vim.keymap.set("n", "<leader>ed", ":Genghis duplicateFile<CR>", { desc = "Duplicate the current file" })
		vim.keymap.set(
			"n",
			"<leader>em",
			":Genghis moveSelectionToNewFile<CR>",
			{ desc = "Move the current selection to a new file" }
		)
		vim.keymap.set("n", "<leader>er", ":Genghis renameFile<CR>", { desc = "Rename the current file" })
		vim.keymap.set(
			"n",
			"<leader>ev",
			":Genghis moveToFolderInCwd<CR>",
			{ desc = "Move the current file to a folder" }
		)
		vim.keymap.set(
			"n",
			"<leader>ew",
			":Genghis moveAndRenameFile<CR>",
			{ desc = "Move and rename the current file" }
		)
		vim.keymap.set("n", "<leader>ex", ":Genghis chmodx<CR>", { desc = "Make current file executable" })
		vim.keymap.set("n", "<leader>et", ":Genghis trashFile<CR>", { desc = "Move the current file to the trash" })
		vim.keymap.set(
			"n",
			"<leader>eo",
			":Genghis showInSystemExplorer<CR>",
			{ desc = "Show the file in the system explorer" }
		)
	end,
}
