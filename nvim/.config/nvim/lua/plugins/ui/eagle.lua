-- https://github.com/soulis-1256/eagle.nvim
-- 鼠标停在代码上就浮出「诊断 + LSP hover」的窗口（VSCode 同款），不用按 K。
--
-- 依赖 vim.o.mousemoveevent：lua/boot/settings.lua:121 已全局打开，这里不用再设。
-- 内部靠一个 uv 定时器每 detect_idle_timer 毫秒比一次鼠标位置，空闲时几乎零开销。
-- 与 k 的 hover 不冲突：eagle 用独立浮窗，hover_scroll.lua 只管 LSP 自己的 hover 窗。
return {
	"soulis-1256/eagle.nvim",
	config = function()
		--- 插件只接受 #RRGGBB 字符串，所以从当前主题的浮窗高亮里取色再转成 hex。
		--- 取不到就返回 nil，让插件用自己的默认色。
		---@param name string 高亮组名
		---@return string|nil
		local function hl_hex(name)
			local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
			local fg = ok and hl and hl.fg
			return fg and ("#%06x"):format(fg) or nil
		end

		require("eagle").setup({
			-- 1 = DL/DL：诊断在上、LSP 信息在下（窗口贴屏幕下半时插件会自动翻转）
			order = 1,
			-- 鼠标在同一处停留 500ms 才弹，扫过代码时不会闪窗
			render_delay = 500,
			-- 弹窗最大占屏宽的 1/2.5、屏高的 1/2.5
			max_width_factor = 2.5,
			max_height_factor = 2.5,
			-- 跟主题的浮窗边框/标题同色，而不是插件写死的 #8AAAE5
			border = "rounded",
			border_color = hl_hex("FloatBorder"),
			title_color = hl_hex("FloatTitle"),
			-- 键盘模式：默认关（K 已是 hover、grd 已是诊断浮窗，再占 <Tab> 会和补全候选冲突），
			-- 只留 <leader>sh 手动唤起
			keyboard_mode = true,
			mouse_mode = true,
			-- LSP 信息默认开启：没有 LSP attach 的文件会自动只显示诊断
			show_lsp_info = true,
			-- 进命令行（:）时收起浮窗，避免焦点跑到浮窗里
			close_on_cmd = true,
		})

		vim.keymap.set("n", "<leader>sh", "<cmd>EagleWin<CR>", {
			noremap = true,
			silent = true,
			desc = "LSP: 光标处浮窗（诊断 + hover）",
		})
	end,
}
