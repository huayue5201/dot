-- https://github.com/bennypowers/nvim-regexplainer
--
-- 只用 narrative 模式：纯 Lua，不依赖 python / 图像协议。
-- graphical 模式需要 python venv（railroad-diagrams + Pillow）和 Kitty graphics
-- 协议，本机未装，触发时只会警告并静默回退 narrative，因此不启用，
-- 也就不需要 hologram.nvim 这个已停更的依赖。

return {
	"bennypowers/nvim-regexplainer",
	config = function()
		require("regexplainer").setup({
			-- 'narrative'（叙述模式）, 'graphical'（图形模式，需 python 依赖）
			mode = "narrative",

			-- 当光标进入正则表达式时自动显示解释器
			auto = true,

			-- 激活 regexplainer 的文件类型
			-- 插件只提供 c_sharp / ecma / go / java / javascript / php / python /
			-- ruby / rust / typescript 的 treesitter query；lua、html 没有 query，
			-- 配了也不会命中（lua 的 pattern 不是 regex 语法树）。
			filetypes = {
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
			},

			narrative = {
				indentation_string = "> ",
			},
		})
	end,
}
