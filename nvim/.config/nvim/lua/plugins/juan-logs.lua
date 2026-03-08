-- https://github.com/minigian/juan-logs.nvim

return {
	"minigian/juan-logs.nvim",
	build = function(plugin)
		local path = plugin.dir .. "/build.lua"
		if vim.fn.filereadable(path) == 1 then
			dofile(path)
		end
	end,
	-- You can use `build = "cargo build --release"` if you have `cargo` in your system
	config = function()
		require("juanlog").setup({
			threshold_size = 1024 * 1024 * 100, -- 100MB
			mode = "dynamic",
			lazy = true, -- background indexing. prevents neovim from freezing on 50GB files
			patterns = { "*.log", "*.txt", "*.csv", "*.json" }, -- Use the plugin for these filetypes
			enable_custom_statuscol = true, -- fakes absolute line numbers
			syntax = false, -- set to true to enable native vim syntax (can be slow on huge files)
		})
	end,
}
