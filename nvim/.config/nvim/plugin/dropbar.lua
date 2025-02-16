-- https://github.com/Bekaboo/dropbar.nvim?tab=readme-ov-file

vim.g.now(function()
	vim.g.add({
		source = "Bekaboo/dropbar.nvim",
		depends = { "nvim-telescope/telescope-fzf-native.nvim" },
		hooks = {
			post_install = function()
				-- 运行构建命令（例如 make 或 cargo）
				vim.fn.system("cd ~/.local/share/nvim/site/pack/deps/opt/telescope-fzf-native.nvim && make")
			end,
		},
	})

	local dropbar_api = require("dropbar.api")
	vim.keymap.set("n", "<Leader>;", dropbar_api.pick, { desc = "Pick symbols in winbar" })
	vim.keymap.set("n", "[;", dropbar_api.goto_context_start, { desc = "Go to start of current context" })
	vim.keymap.set("n", "];", dropbar_api.select_next_context, { desc = "Select next context" })
end)
