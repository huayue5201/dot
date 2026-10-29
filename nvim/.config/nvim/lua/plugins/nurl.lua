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

	-- init 在所有插件 config 之前跑，保证 preload 注入早于 nurl 首次用 picker
	init = function()
		-- nurl 的 picker 只认 snacks.nvim / telescope.nvim / mini.pick，本机一个都没装。
		-- 用 package.preload 顶替 mini.pick 的探测（返回空表让它"存在"）和它的适配器，
		-- 底层走 vim.ui.select —— dropbar 已把 vim.ui.select 换成自己的可筛选菜单。
		-- 代价：没有 preview 面板；上游若改 picker 接口，这里要跟着改。
		package.preload["mini.pick"] = function()
			return {}
		end

		package.preload["nurl.pickers.mini"] = function()
			return {
				---@param title string
				---@param items nurl.PickerItem[]
				---@param on_pick? fun(item: nurl.RequestItem) 省略时跳转到请求定义处
				pick = function(title, items, on_pick)
					vim.ui.select(items, {
						prompt = title,
						kind = "nurl_request",
						format_item = function(item)
							return item.text
						end,
					}, function(choice)
						if not choice then
							return
						end
						if on_pick then
							-- 先让菜单关掉再发请求，和上游 mini 适配器保持一致
							vim.schedule(function()
								on_pick(choice.item)
							end)
						else
							require("nurl.projects").jump_to(choice.item)
						end
					end)
				end,
			}
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

		-- 走 init 里注入的 vim.ui.select 适配层
		picker = "mini",

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
