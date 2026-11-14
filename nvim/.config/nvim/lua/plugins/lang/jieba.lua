-- https://github.com/kkew3/jieba.vim

return {
	"kkew3/jieba.vim",
	dependencies = { "tpope/vim-repeat" },
	branch = "release",
	build = ":call jieba_vim#install()",
	init = function()
		vim.g.jieba_vim_lazy = 1
		vim.g.jieba_vim_keymap = 1
	end,
	config = function()
		-- jieba.vim 的 operator-pending 播放里用 setline() 造 undo 检查点，但没判
		-- &modifiable（plugin/jieba_vim/mapping.vim:133），于是 neo-tree / help /
		-- grug-far / todo2 等只读 buffer 里按 d+词动作会连报
		-- E21: Cannot make changes, 'modifiable' is off。
		-- 修法：在这些 buffer 上用 buffer-local 的 o 映射把它的词动作压回内置动作。
		local keys = {
			"w",
			"W",
			"e",
			"E",
			"b",
			"B",
			"ge",
			"gE",
			"iw",
			"iW",
			"aw",
			"aW",
			"<C-Left>",
			"<S-Left>",
			"<C-Right>",
			"<S-Right>",
		}

		local function shadow(bufnr)
			if vim.bo[bufnr].modifiable then
				-- 反向：缓冲区重新可写了（:setlocal modifiable、复用的 help buffer、
				-- 详情窗口退出只读态…）要把影子映射撤掉，否则该 buffer 里 jieba 的
				-- 中文分词动作永久静默失效
				if vim.b[bufnr].jieba_omap_shadowed then
					vim.b[bufnr].jieba_omap_shadowed = nil
					for _, lhs in ipairs(keys) do
						pcall(vim.keymap.del, "o", lhs, { buffer = bufnr })
					end
				end
				return
			end
			if vim.b[bufnr].jieba_omap_shadowed then
				return
			end
			vim.b[bufnr].jieba_omap_shadowed = true
			for _, lhs in ipairs(keys) do
				vim.keymap.set("o", lhs, lhs, { buffer = bufnr, remap = false })
			end
		end

		vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
			group = vim.api.nvim_create_augroup("JiebaNoModifiable", { clear = true }),
			desc = "只读 buffer 上禁用 jieba 的 operator-pending 词动作",
			callback = function(args)
				if args.buf and args.buf > 0 then
					shadow(args.buf)
				end
			end,
		})
		-- neo-tree 等插件是在缓冲区渲染时才 setlocal nomodifiable，
		-- BufWinEnter 可能早于这一步，所以再盯一次选项变化。
		vim.api.nvim_create_autocmd("OptionSet", {
			group = "JiebaNoModifiable",
			pattern = "modifiable",
			callback = function()
				shadow(vim.api.nvim_get_current_buf())
			end,
		})
	end,
}
