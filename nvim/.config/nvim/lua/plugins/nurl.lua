-- https://github.com/rodrigoscc/nurl.nvim
-- 用 Lua 描述请求（项目内 .nurl/*.lua），替代 kulala.nvim：kulala 自 v6.34.0 起
-- 核心后端 kulala-core 闭源、需要申请 license token，nurl 是 MIT + 纯 Lua + 只用 curl。
--
-- 和 .http 格式不兼容，请求写成 Lua 表：
--   return { { "https://api.example.com/users/1", title = "取用户" } }
-- 因为请求文件就是可执行 Lua，首次在陌生目录（clone 来的仓库）发请求前会问 trust。

-- 开一个未保存的 lua buffer 当草稿；`:Nurl .` 直接读 buffer，不需要存盘
local function scratchpad()
	vim.cmd("enew")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].filetype = "lua"
	vim.bo[buf].bufhidden = "hide"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"return {",
		"\t{",
		'\t\t"https://jsonplaceholder.typicode.com/posts/1",',
		"\t\ttitle = \"示例请求\",",
		"\t},",
		"}",
	})
	vim.api.nvim_win_set_cursor(0, { 3, 0 })
end

return {
	"rodrigoscc/nurl.nvim",
	-- 钉在 1.x：v2 若改 picker/请求表接口不被动跟着坏
	sem_version = "1.*",

	-- nurl 的 picker 只认 snacks.nvim / telescope.nvim / mini.pick，本机一个都没装。
	-- nurl 内部所有选择都收敛到 nurl.pickers.pick（commands.lua:66,125 与
	-- app/targets.lua:58），这里直接整体替换掉，用自带的 ui.picker：
	--   真输入行 + matchfuzzy 实时过滤 + 右侧请求预览（http_message.render）。
	-- 这样也不必给 nurl 配 picker 选项，更不用伪造 mini.pick 模块。
	config = function(_, opts)
		local picker = require("ui.picker")

		-- 写了 config 就不会再走 pack.lua 的自动 setup(opts)，这里手动叫一次
		require("nurl").setup(opts)

		require("nurl.pickers").pick = function(title, items, on_pick)
			picker.pick({
				title = title,
				items = items,
				text = function(item)
					return item.text
				end,
				preview = function(item)
					if not item.preview then
						return nil
					end
					local ok, lines = pcall(require("nurl.ui.http_message").render, item.preview)
					return ok and lines or nil
				end,
				-- 预览按 http 语法高亮（方法是 Keyword、header 是 Type 之类）
				filetype = "http",
				on_choose = function(item)
					if on_pick then
						on_pick(item.item)
					else
						require("nurl.projects").jump_to(item.item)
					end
				end,
			})
		end
	end,

	keys = {
		{
			"<leader>Rs",
			function()
				vim.cmd("Nurl .")
			end,
			desc = "发送光标处请求",
		},
		{
			"<leader>Ra",
			function()
				vim.cmd("Nurl")
			end,
			desc = "项目请求列表 → 发送",
		},
		{
			"<leader>Rb",
			scratchpad,
			desc = "新建请求草稿",
		},
		{
			"<leader>Rr",
			function()
				vim.cmd("Nurl resend -1")
			end,
			desc = "重发上一条请求",
		},
		{
			"<leader>Rh",
			function()
				vim.cmd("Nurl history")
			end,
			desc = "请求历史",
		},
		{
			"<leader>Re",
			function()
				vim.cmd("Nurl env")
			end,
			desc = "切换环境",
		},
		{
			"<leader>Ry",
			function()
				vim.cmd("Nurl yank")
			end,
			desc = "复制为 curl 命令",
		},
	},

	opts = {
		-- 请求文件目录（项目根下）
		dir = ".nurl",

		-- 请求历史（SQLite）。本机 ffi.load("sqlite3") 可用；不想用就设 enabled = false
		history = {
			enabled = true,
		},

		-- 响应窗口：右侧竖分屏（想浮动改成 { relative = "editor", ... }）
		win_config = { split = "right" },

		-- 请求文件是可执行 Lua，保留首次运行的确认
		trust = {
			enabled = true,
		},
	},
}
