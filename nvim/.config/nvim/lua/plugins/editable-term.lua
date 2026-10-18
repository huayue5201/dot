-- https://github.com/xb-bx/editable-term.nvim
-- 把 :terminal 里的命令行当普通 buffer 编辑（A/I/i/a/dd/y/c/d/cw/ys 等都能用），回车前随便改。
-- 需要 neovim 0.11+。
--
-- 提示符识别有两条路：
--   1) OSC 133 语义提示符（.zshrc 里给 PROMPT 加了 133;A / 133;B，最可靠）
--   2) promts 里的 Lua pattern 兜底：离开终端窗口时按当前行文本匹配
-- 键位走 zsh 的 emacs/vi-insert 默认按键（C-a 行首、C-e 行尾、C-f 右移、C-e C-u 清行），
-- 这几个在 zsh-vi-mode 的 viins 里默认是 self-insert，已在 .zshrc 里显式绑定。

return {
	"xb-bx/editable-term.nvim",
	-- 直接加载（不延迟）：插件在 setup() 里注册 TermOpen autocmd，任何终端都会命中，
	-- 包括启动时用 -c "terminal ..." 打开的那种。代码只有 213 行，启动开销可忽略。
	config = function()
		require("editable-term").setup({
			-- 发送按键后等待 shell 消化的时间（毫秒），太短会在慢机器上丢键
			wait_for_keys_delay = 30,
			default_keybinds = {
				clear_current_line = "<C-e><C-u>",
				goto_line_start = "<C-a>",
				goto_line_end = "<C-e>",
				forward_char = "<C-f>",
			},
			promts = {
				-- zsh + starship（OSC 133 不可用时的兜底）
				["❯ "] = {},
				-- gdb
				["^%(gdb%) "] = {},
				-- python
				["^>>> "] = {},
				["^%.%.%. "] = {},
				-- node / 其他 REPL
				["^> "] = {},
			},
		})

		-- 插件把每个终端的第一次 TextChanged 当成“终端自己的输出”而忽略
		-- （M.buffers[buf].leaving_term 初始为 true），所以打开终端后第一次编辑
		-- 会被吞掉。退出终端插入模式时把这个标记清掉即可。
		vim.api.nvim_create_autocmd("ModeChanged", {
			pattern = "t:nt",
			callback = function()
				local info = require("editable-term").buffers[vim.api.nvim_get_current_buf()]
				if info then
					info.leaving_term = false
				end
			end,
		})
	end,
}
