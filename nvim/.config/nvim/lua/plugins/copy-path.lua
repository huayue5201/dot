return {
	dir = "~/neovim-plugins/copy-path",
	"huayue5201/copy-path",
	dev = true,
	event = "VeryLazy",
	name = "copy-path",
	config = function()
		local copy_path = require("copy-path")

		vim.api.nvim_create_autocmd({ "FileType" }, {
			pattern = { "json" },
			callback = function(args)
				vim.keymap.set("n", "<leader>yc", function()
					copy_path.copy_json_path({ register = "*" })
				end, { buffer = args.buf })
			end,
		})

		vim.api.nvim_create_autocmd({ "FileType" }, {
			pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
			callback = function(args)
				vim.keymap.set("n", "<leader>yc", function()
					copy_path.copy_javascript_path({ register = "*" })
				end, { buffer = args.buf })
			end,
		})
	end,
}
