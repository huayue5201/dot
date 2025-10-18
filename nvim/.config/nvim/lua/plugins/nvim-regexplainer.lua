-- https://github.com/bennypowers/nvim-regexplainer

return {
	"bennypowers/nvim-regexplainer",
	event = "BufReadPost",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"MunifTanjim/nui.nvim",
	},
	config = function()
		-- 安全加载
		local ok, regexplainer = pcall(require, "regexplainer")
		if not ok then
			vim.notify("Failed to load nvim-regexplainer", vim.log.levels.ERROR)
			return
		end

		regexplainer.setup({
			-- 是否自动展示解释窗口
			auto = true,

			-- 启用的文件类型
			filetypes = {
				"html",
				"js",
				"cjs",
				"mjs",
				"ts",
				"jsx",
				"tsx",
				"cjsx",
				"mjsx",
				"python",
			},

			-- 显示模式：split 或 popup
			display = "popup",

			-- 快捷键映射
			mappings = {
				toggle = "gR", -- 主切换键
				-- show = "gS",
				-- hide = "gH",
				-- show_split = "gP",
				-- show_popup = "gU",
			},

			-- 文本模式（Narrative Mode）设置
			narrative = {
				indentation_string = "> ", -- ✅ 修正拼写: 原来是 `indendation_string`
			},

			-- 图形模式（Graphical Mode）
			graphical = {
				width = 800,
				height = 600,
				python_cmd = nil, -- 自动检测系统 python
			},

			-- Python 依赖设置
			deps = {
				auto_install = true, -- 自动安装 Python 依赖包
				python_cmd = nil, -- 自动检测 Python
				venv_path = nil, -- 自动创建虚拟环境
				check_interval = 3600, -- 每小时检查依赖一次
			},
		})

		-- 提示：如果你未来使用 Kitty 终端，可以自动切换为图形模式
		if vim.env.TERM_PROGRAM == "Kitty" then
			vim.notify("Kitty terminal detected — enabling graphical regex explanations", vim.log.levels.INFO)
			vim.g.regexplainer_display = "graphical"
		end
	end,
}
