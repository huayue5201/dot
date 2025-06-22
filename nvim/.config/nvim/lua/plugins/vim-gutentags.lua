-- https://github.com/ludovicchabant/vim-gutentags

return {
	"ludovicchabant/vim-gutentags",
	lazy = true,
	init = function()
		-- ===================== 核心配置 =====================
		-- 启用模块：cscope_maps 是必须的，其他模块可选
		vim.g.gutentags_modules = { "cscope_maps" }

		-- 启用 cscope 倒排索引（加速大型项目搜索）
		vim.g.gutentags_cscope_build_inverted_index_maps = 1

		-- 标签文件缓存目录（避免污染项目）
		vim.g.gutentags_cache_dir = vim.fn.expand("~/.cache/.gutentags")

		-- 启用调试模式（生成完成后建议关闭）
		vim.g.gutentags_trace = 0

		-- 项目根目录识别标记（优先级从高到低）
		vim.g.gutentags_project_root = { ".root", "Makefile", "*.ioc" }

		-- 启用自动生成行为
		vim.g.gutentags_generate_on_missing = 1 -- 缺失标签时自动生成
		vim.g.gutentags_generate_on_empty_buffer = 1 -- 空缓冲区时生成
		vim.g.gutentags_define_advanced_commands = 1 -- 启用高级命令

		-- 自动将标签文件加入 Vim 的 tags 选项
		vim.g.gutentags_ctags_auto_set_tags = 1

		-- ===================== 文件处理配置 =====================
		-- 统一标签文件名（使用隐藏文件避免污染项目）
		vim.g.gutentags_ctags_tagfile = ".gtags"

		-- 文件列表生成命令（优化索引速度）
		vim.g.gutentags_file_list_command = {
			markers = {
				[".git"] = "git ls-files", -- Git 项目使用 git 命令
				["Cargo.toml"] = "fd -e rs", -- Rust 项目使用 fd
				["requirements.txt"] = "fd -e py", -- Python 项目使用 fd
				["Makefile"] = "fd -e c -e h -e cpp", -- C/C++ 项目使用 fd
			},
		}

		-- 后台生成标签（避免阻塞 Vim）
		vim.g.gutentags_background_update = 1

		-- ===================== 排除规则配置 =====================
		-- 全局通配符排除规则（同步到 ctags）
		vim.g.gutentags_ctags_exclude_wildignore = 1
		vim.opt.wildignore:append({
			-- 通用排除
			"*.o",
			"*.obj",
			"*.so",
			"*.dll",
			"*.exe", -- 二进制文件
			"*.pyc",
			"__pycache__", -- Python 缓存
			"target/**", -- Rust 构建目录
			"build/**",
			"dist/**", -- 构建输出目录
			"**/venv/**",
			"**/node_modules/**", -- 虚拟环境和依赖
			".git",
			".svn",
			".hg", -- 版本控制目录
			"*.log",
			"*.tmp",
			".DS_Store", -- 临时文件
		})

		-- ctags 专用排除规则
		vim.g.gutentags_ctags_exclude = {
			"third_party/**", -- C/C++ 第三方库
			"out/**", -- C/C++ 构建输出
			"**/tests/data/**", -- Python 测试数据
			".mypy_cache/**", -- Python 类型缓存
			"benches/**", -- Rust 基准测试目录
		}

		-- ===================== 语言专属配置 =====================
		-- 项目类型检测规则
		vim.g.gutentags_project_info = {
			-- C/C++ 项目（检测 Makefile 或 C 源文件）
			{ type = "c", glob = "*.{c,h,cc,cpp,hpp}", file = "Makefile" },
			-- Python 项目（检测 requirements.txt）
			{ type = "python", file = "requirements.txt" },
			-- Rust 项目（检测 Cargo.toml）
			{ type = "rust", file = "Cargo.toml" },
		}

		-- 语言专属 ctags 参数
		vim.g.gutentags_ctags_executable = "ctags" -- 默认使用系统 ctags

		-- C/C++ 参数：增强函数和类型信息
		vim.g.gutentags_ctags_extra_args_c = {
			"--c-kinds=+px", -- 包含函数原型和外部变量
			"--fields=+iaS", -- 增加继承/实现信息
			"--extras=+q", -- 添加类修饰符信息
		}

		-- Python 参数：优化标签生成
		vim.g.gutentags_ctags_extra_args_python = {
			"--python-kinds=-iv", -- 排除导入变量
			"--languages=Python",
		}

		-- Rust 参数：增强模块支持
		vim.g.gutentags_ctags_extra_args_rust = {
			"--rust-kinds=+p", -- 包含模块
			"--languages=Rust",
			"--map-Rust=+.rs", -- 确保识别 .rs 文件
		}

		-- ===================== 自动命令优化 =====================
		vim.cmd([[
      augroup GutentagsOverrides
        autocmd!
        " 项目加载后关闭跟踪（避免日志过大）
        autocmd User GutentagsUpdated let g:gutentags_trace = 0

        " 大型项目限制文件数量（防止内存溢出）
        autocmd User GutentagsUpdating if line('$') > 5000 |
              \ let g:gutentags_file_list_command = 'fd | head -n 5000' |
              \ endif
      augroup END
    ]])
	end,

	-- 确保缓存目录存在
	config = function()
		local cache_dir = vim.fn.expand("~/.cache/.gutentags")
		if vim.fn.isdirectory(cache_dir) == 0 then
			vim.fn.mkdir(cache_dir, "p", "0755")
		end
	end,
}
