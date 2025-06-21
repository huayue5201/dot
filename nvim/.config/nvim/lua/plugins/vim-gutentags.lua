-- https://github.com/ludovicchabant/vim-gutentags

return {
	"ludovicchabant/vim-gutentags",
	lazy = true,
	dependencies = { "vim-scripts/gtags.vim" },
	init = function()
		-- 基础配置
		vim.g.gutentags_modules = { "cscope_maps" }
		vim.g.gutentags_cscope_build_inverted_index_maps = 1
		vim.g.gutentags_cache_dir = vim.fn.stdpath("cache") .. "/gutentags"
		vim.g.gutentags_file_list_command = "fd -e c -e h -e cpp -e hpp -e py -e js -e ts -e go -e rs -e java"
		vim.g.gutentags_exclude = {
			"node_modules",
			"build",
			"dist",
			"*.git",
		}
		-- gtags 配置 (简化版本)
		vim.g.gutentags_define_advanced_commands = 1
		vim.g.gutentags_plus_switch = 1

		-- 更简单的 gtags 集成方式
		vim.cmd([[
      function! GutentagsUpdateGtags() abort
        " 获取当前文件路径作为参数
        let l:current_file = expand('%:p')
        if empty(l:current_file)
          return
        endif

        " 使用带参数的 get_project_root
        let l:project_root = gutentags#get_project_root(l:current_file)
        if empty(l:project_root)
          return
        endif

        " 使用全局缓存目录
        let l:gtags_db = g:gutentags_cache_dir . '/gtags'
        if !isdirectory(l:gtags_db)
          call mkdir(l:gtags_db, 'p')
        endif

        " 简化的 gtags 命令
        let l:cmd = 'gtags --gtagslabel=native-pygments --explain --skip-unreadable --skip-symlink=follow'

        " 在项目根目录执行
        call system('cd ' . shellescape(l:project_root) . ' && ' . l:cmd)
      endfunction

      " 添加自动命令
      augroup gutentags_gtags
        autocmd!
        autocmd User GutentagsUpdated call GutentagsUpdateGtags()
      augroup END
    ]])

		-- gtags.vim 配置
		vim.g.Gtags_OpenQuickfixWindow = 1
		vim.g.Gtags_VerticalWindow = 1
		vim.g.Gtags_Auto_Map = 0
		vim.g.Gtags_No_Auto_Jump = 1
		vim.g.Gtags_Use_Directory_Stack = 0
		vim.g.Gtags_DB_Path = vim.g.gutentags_cache_dir .. "/gtags"

		-- 修复 deprecated 警告
		vim.g.gutentags_async = 0 -- 暂时禁用异步避免警告
	end,
	config = function()
		-- 创建缓存目录
		local cache_dir = vim.g.gutentags_cache_dir
		if vim.fn.isdirectory(cache_dir) == 0 then
			vim.fn.mkdir(cache_dir, "p")
			vim.fn.mkdir(cache_dir .. "/gtags", "p")
		end

		-- 首次打开时生成 gtags
		vim.schedule(function()
			vim.cmd([[
        if !empty(expand('%'))
          call GutentagsUpdateGtags()
        endif
      ]])
		end)
	end,
}
