-- https://github.com/saecki/crates.nvim

return {
	"saecki/crates.nvim",
	event = { "BufRead Cargo.toml" },
	tag = "stable",
	config = function()
		local crates = require("crates")
		crates.setup({
			smart_insert = true, -- 启用智能插入：在输入时自动插入合适的符号（如引号）
			insert_closing_quote = true, -- 插入关闭的引号和括号
			autoload = true, -- 自动加载：插件启动时自动加载配置
			autoupdate = true, -- 自动更新插件
			autoupdate_throttle = 250, -- 设置自动更新的时间间隔（毫秒）
			loading_indicator = true, -- 显示加载指示器
			search_indicator = true, -- 显示搜索指示器
			date_format = "%Y-%m-%d", -- 设置日期格式
			thousands_separator = ".", -- 设置千位分隔符为点
			notification_title = "crates.nvim", -- 插件通知标题
			curl_args = { "-sL", "--retry", "1" }, -- 设置 `curl` 命令的参数
			max_parallel_requests = 80, -- 最大并发请求数
			expand_crate_moves_cursor = true, -- 扩展 crate 信息时，光标自动移动
			enable_update_available_warning = true, -- 如果更新可用，显示警告
			on_attach = function(bufnr) end, -- 绑定函数，用于缓冲区初始化
			text = { -- 配置显示的文本
				searching = "   Searching", -- 正在搜索
				loading = "   Loading", -- 正在加载
				version = "   %s", -- 版本信息
				prerelease = "   %s", -- 预发布版本
				yanked = "   %s", -- 被移除的版本
				nomatch = "   No match", -- 没有找到匹配项
				upgrade = "   %s", -- 升级版本
				error = "   Error fetching crate", -- 错误：获取 crate 时出错
			},
			popup = { -- 弹窗配置
				autofocus = true, -- 自动聚焦
				hide_on_select = true, -- 选择后隐藏弹窗
				copy_register = '"', -- 复制到默认寄存器
				style = "minimal", -- 弹窗样式：最小化
				border = "shadow", -- 弹窗边框样式：阴影
				show_version_date = true, -- 显示版本日期
				show_dependency_version = true, -- 显示依赖项版本
				max_height = 30, -- 弹窗最大高度
				min_width = 20, -- 弹窗最小宽度
				padding = 1, -- 弹窗内部填充
				text = { -- 弹窗显示的文本
					title = " %s", -- 标题格式
					pill_left = "", -- 左边的标志
					pill_right = "", -- 右边的标志
					description = "%s", -- 描述
					created_label = " created        ", -- 创建时间标签
					created = "%s", -- 创建时间
					updated_label = " updated        ", -- 更新时间标签
					updated = "%s", -- 更新时间
					downloads_label = " downloads      ", -- 下载量标签
					downloads = "%s", -- 下载量
					homepage_label = " homepage       ", -- 主页标签
					homepage = "%s", -- 主页链接
					repository_label = " repository     ", -- 仓库标签
					repository = "%s", -- 仓库链接
					documentation_label = " documentation  ", -- 文档标签
					documentation = "%s", -- 文档链接
					crates_io_label = " crates.io      ", -- crates.io 标签
					crates_io = "%s", -- crates.io 链接
					lib_rs_label = " lib.rs         ", -- lib.rs 标签
					lib_rs = "%s", -- lib.rs 链接
					categories_label = " categories     ", -- 分类标签
					keywords_label = " keywords       ", -- 关键词标签
					version = "  %s", -- 版本
					prerelease = " %s", -- 预发布版本
					yanked = " %s", -- 被移除版本
					version_date = "  %s", -- 版本日期
					feature = "  %s", -- 特性
					enabled = " %s", -- 启用的特性
					transitive = " %s", -- 传递依赖
					normal_dependencies_title = " Dependencies", -- 普通依赖标题
					build_dependencies_title = " Build dependencies", -- 构建依赖标题
					dev_dependencies_title = " Dev dependencies", -- 开发依赖标题
					dependency = "  %s", -- 依赖项
					optional = " %s", -- 可选依赖项
					dependency_version = "  %s", -- 依赖版本
					loading = "  ", -- 加载中的提示
				},
				keys = { -- 弹窗操作的快捷键
					hide = { "q", "<esc>" }, -- 隐藏弹窗
					open_url = { "<cr>" }, -- 打开 URL
					select = { "<cr>" }, -- 选择
					select_alt = { "s" }, -- 选择替代
					toggle_feature = { "<cr>" }, -- 切换特性
					copy_value = { "yy" }, -- 复制值
					goto_item = { "gd", "K", "<C-LeftMouse>" }, -- 跳转到项
					jump_forward = { "<c-i>" }, -- 向前跳转
					jump_back = { "<c-o>", "<C-RightMouse>" }, -- 向后跳转
				},
			},
			-- 	completion = {
			-- 		insert_closing_quote = true,
			-- 		text = {
			-- 			prerelease = "  pre-release ",
			-- 			yanked = "  yanked ",
			-- 		},
			-- 		blink = {
			-- 			use_custom_kind = true,
			-- 			kind_text = {
			-- 				version = "Version",
			-- 				feature = "Feature",
			-- 			},
			-- 			kind_highlight = {
			-- 				version = "BlinkCmpKindVersion",
			-- 				feature = "BlinkCmpKindFeature",
			-- 			},
			-- 			kind_icon = {
			-- 				version = "🅥 ",
			-- 				feature = "🅕 ",
			-- 			},
			-- 		},
			-- 		crates = {
			-- 			enabled = true,
			-- 			min_chars = 3,
			-- 			max_results = 8,
			-- 		},
			-- 	},
			-- },
			lsp = { -- LSP 配置
				enabled = true, -- 启用 LSP
				name = "crates.nvim", -- LSP 名称
				on_attach = function(client, bufnr) end, -- LSP 连接时的操作
				actions = true, -- 启用操作
				completion = true, -- 启用自动完成
				hover = true, -- 启用悬停提示
			},
		})
		local function map_filetype(ft, mode, lhs, rhs, opts)
			vim.api.nvim_create_autocmd("FileType", {
				pattern = ft,
				callback = function()
					vim.keymap.set(
						mode,
						lhs,
						rhs,
						vim.tbl_extend("force", opts or {}, { buffer = true, silent = true })
					)
				end,
			})
		end

		map_filetype(
			"toml",
			"n",
			"<leader>ct",
			crates.toggle,
			vim.tbl_extend("force", {}, { desc = "切换 crates 显示/隐藏" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cr",
			crates.reload,
			vim.tbl_extend("force", {}, { desc = "重新加载 crates 数据" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cv",
			crates.show_versions_popup,
			vim.tbl_extend("force", {}, { desc = "显示版本弹窗" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cf",
			crates.show_features_popup,
			vim.tbl_extend("force", {}, { desc = "显示功能弹窗" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cd",
			crates.show_dependencies_popup,
			vim.tbl_extend("force", {}, { desc = "显示依赖关系弹窗" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cu",
			crates.update_crate,
			vim.tbl_extend("force", {}, { desc = "更新当前 crate" })
		)
		map_filetype(
			"v",
			"<leader>cu",
			crates.update_crates,
			vim.tbl_extend("force", {}, { desc = "更新选中的多个 crate" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>ca",
			crates.update_all_crates,
			vim.tbl_extend("force", {}, { desc = "更新所有 crates" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cU",
			crates.upgrade_crate,
			vim.tbl_extend("force", {}, { desc = "升级当前 crate" })
		)
		map_filetype(
			"v",
			"<leader>cU",
			crates.upgrade_crates,
			vim.tbl_extend("force", {}, { desc = "升级选中的多个 crate" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cA",
			crates.upgrade_all_crates,
			vim.tbl_extend("force", {}, { desc = "升级所有 crates" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cx",
			crates.expand_plain_crate_to_inline_table,
			vim.tbl_extend("force", {}, { desc = "展开一个 crate 成为内联表格" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cX",
			crates.extract_crate_into_table,
			vim.tbl_extend("force", {}, { desc = "提取 crate 成为独立的表格" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cH",
			crates.open_homepage,
			vim.tbl_extend("force", {}, { desc = "打开 crate 的主页" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cR",
			crates.open_repository,
			vim.tbl_extend("force", {}, { desc = "打开 crate 的 Git 仓库" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cD",
			crates.open_documentation,
			vim.tbl_extend("force", {}, { desc = "打开 crate 的文档" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cC",
			crates.open_crates_io,
			vim.tbl_extend("force", {}, { desc = "打开 crates.io 页面" })
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cL",
			crates.open_lib_rs,
			vim.tbl_extend("force", {}, { desc = "打开 lib.rs 页面" })
		)

		local function show_documentation()
			if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
				require("crates").show_popup()
			else
				vim.lsp.buf.hover()
			end
		end
		map_filetype("toml", "n", "K", show_documentation, { silent = true })
	end,
}
