-- https://github.com/ThePrimeagen/99

return {
	"ThePrimeagen/99",
	config = function()
		local _99 = require("99")

		-- 用于记录日志到文件，如果你想追踪请求过程以便报告错误
		-- 我不建议依赖这个，而是使用99提供的日志机制
		-- 这更多是为了调试目的
		local cwd = vim.uv.cwd()
		local basename = vim.fs.basename(cwd)
		_99.setup({
			-- provider = _99.Providers.ClaudeCodeProvider,  -- 默认值: OpenCodeProvider
			logger = {
				level = _99.DEBUG,
				path = "/tmp/" .. basename .. ".99.debug",
				print_on_error = true,
			},
			-- 注意：如果将此路径设置为当前工作目录之外的目录
			-- 像claude code或opencode这样的工具可能会遇到权限问题
			-- 生成将会失败，请参考工具文档解决
			-- https://opencode.ai/docs/permissions/#external-directories
			-- https://code.claude.com/docs/en/permissions#read-and-edit
			tmp_dir = "./tmp",

			--- 补全功能：在提示符缓冲区中使用 #rules 和 @files
			completion = {
				-- 我打算暂时禁用这些，直到我更好地理解问题所在
				-- 在cursor rules中也有应用程序规则
				-- 这意味着我需要以不同的方式应用这些规则
				-- cursor_rules = "<自定义cursor规则路径>"

				--- 存放你自己SKILL.md文件的文件夹列表
				--- 期望格式：
				--- /path/to/dir/<技能名称>/SKILL.md
				---
				--- 示例：
				--- 输入路径：
				--- "scratch/custom_rules/"
				---
				--- 输出规则：
				--- {path = "scratch/custom_rules/vim/SKILL.md", name = "vim"},
				--- ... 该目录中的其他规则 ...
				---
				custom_rules = {
					"scratch/custom_rules/",
				},

				--- 配置@文件补全（所有字段均为可选，有合理的默认值）
				files = {
					-- enabled = true,
					-- max_file_size = 102400,     -- 字节，跳过大于此值的文件
					-- max_files = 5000,            -- 发现文件总数的上限
					-- exclude = { ".env", ".env.*", "node_modules", ".git", ... },
				},
				--- 文件发现：
				--- - 在git仓库中：使用 `git ls-files`，它会自动遵守 .gitignore
				--- - 非git仓库：回退到文件系统扫描，需要手动排除
				--- - 两种方法都会在gitignore的基础上应用配置的`exclude`列表

				--- 使用哪种自动补全引擎。如果未指定，默认为native（内置）
				source = "native", -- "native"（默认值），"cmp"，或"blink"
			},

			--- 警告：如果你改变当前工作目录，这可能会失效
			--- 我可能会在后续更新中修复这个问题
			---
			--- md_files是要查找并根据原始请求位置自动添加的文件列表
			--- 这意味着如果你在 /foo/bar/baz.lua
			--- 系统会自动查找：
			--- /foo/bar/AGENT.md
			--- /foo/AGENT.md
			--- 假设 /foo 是项目根目录（基于当前工作目录）
			md_files = {
				"AGENT.md",
			},
		})

		-- 特别注意：我仅在可视模式中使用视觉选择
		-- 技术上来说，你最后的视觉选择将被使用
		-- 所以我将其设置为可视模式，以避免错误使用旧的视觉选择
		--
		-- 后续我可能会添加模式检查并验证所需的视觉模式
		-- 所以现在先做好准备
		vim.keymap.set("v", "<leader>9v", function()
			_99.visual()
		end, { desc = "对当前视觉选中的内容执行AI操作" })

		--- 如果你有一个请求不想做任何更改，只需取消它
		vim.keymap.set("n", "<leader>9x", function()
			_99.stop_all_requests()
		end, { desc = "取消所有正在进行的AI请求" })

		vim.keymap.set("n", "<leader>9s", function()
			_99.search()
		end, { desc = "搜索AI相关功能或内容" })

		vim.keymap.set("n", "<leader>9m", function()
			require("99.extensions.fzf_lua").select_model()
		end, { desc = "选择AI模型（使用fzf-lua）" })

		vim.keymap.set("n", "<leader>9p", function()
			require("99.extensions.fzf_lua").select_provider()
		end, { desc = "选择AI服务提供商（使用fzf-lua）" })
	end,
}
