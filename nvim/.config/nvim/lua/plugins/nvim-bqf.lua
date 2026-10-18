-- https://github.com/kevinhwang91/nvim-bqf

return {
	"kevinhwang91/nvim-bqf",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	ft = "qf",
	config = function()
		-- nvim-bqf 的 `zf` 模式不只调用 fzf 二进制，还依赖 fzf 仓库里的
		-- Vim 插件（fzf#run / fzf#wrap / fzf#exec）。
		-- Homebrew 的 fzf 已经自带 plugin/fzf.vim，直接复用，避免 zpack
		-- 再下载一份 junegunn/fzf 并额外编译 fzf 二进制。
		local candidates = {
			"/opt/homebrew/opt/fzf",
			"/usr/local/opt/fzf",
		}

		-- 兼容 Linuxbrew / 自定义安装：从 PATH 里的 fzf 反推安装目录。
		local exe = vim.fn.exepath("fzf")
		if exe ~= "" then
			local real = vim.fn.resolve(exe)
			table.insert(candidates, vim.fs.dirname(vim.fs.dirname(real)))
		end

		for _, dir in ipairs(candidates) do
			local plugin_file = dir .. "/plugin/fzf.vim"
			if vim.fn.filereadable(plugin_file) == 1 then
				vim.opt.runtimepath:append(dir)
				vim.cmd("source " .. vim.fn.fnameescape(plugin_file))
				return
			end
		end

		vim.notify("nvim-bqf: 找不到 fzf 的 Vim 插件（plugin/fzf.vim）", vim.log.levels.WARN)
	end,
}
