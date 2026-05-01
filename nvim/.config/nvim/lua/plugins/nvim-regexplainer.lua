-- https://github.com/bennypowers/nvim-regexplainer

return {
	"bennypowers/nvim-regexplainer",
	dependencies = "edluffy/hologram.nvim",
	event = "VeryLazy",
	config = function()
		-- 默认配置
		require("regexplainer").setup({
			-- 'narrative'（叙述模式）, 'graphical'（图形模式）
			mode = "graphical",

			-- 当光标进入正则表达式时自动显示解释器
			auto = true,

			-- 激活 regexplainer 的文件类型
			filetypes = {
				"html",
				"javascript",
				"javascriptreact",
				"typescript",
				"typescriptreact",
				"ruby",
				"python",
				"go",
				"rust",
				"php",
				"java",
				"cs",
			},

			-- 是否记录调试日志
			debug = false,

			-- 'split'（分屏模式）, 'popup'（弹出窗口模式）
			display = "popup",

			mappings = {
				toggle = "gR", -- 切换显示/隐藏
				-- 示例，非默认键位：
				-- show = 'gS',       -- 显示
				-- hide = 'gH',       -- 隐藏
				-- show_split = 'gP', -- 分屏模式显示
				-- show_popup = 'gU', -- 弹出窗口模式显示
			},

			narrative = {
				indendation_string = "> ", -- 缩进字符串（默认值为 '  '）
			},

			graphical = {
				width = 800, -- 图像宽度（像素）
				height = 600, -- 图像高度（像素）
				python_cmd = nil, -- Python 命令（自动检测）
			},

			deps = {
				auto_install = true, -- 自动安装 Python 依赖
				python_cmd = nil, -- Python 命令（自动检测）
				venv_path = nil, -- 虚拟环境路径（自动生成）
				check_interval = 3600, -- 依赖检查间隔（秒）
			},
		})
	end,
}
