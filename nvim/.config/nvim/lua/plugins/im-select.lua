-- https://github.com/hughfenghen/fenghen-im-select.nvim
-- 从 keaising/im-select.nvim 迁移而来（旧配置见 git 历史）。
-- 相比旧插件，多了 CmdLine / Term / Focus 事件与「按光标上下文智能切换」策略。

return {
	"hughfenghen/fenghen-im-select.nvim",
	event = "VeryLazy",
	config = function()
		local im_select = require("im_select.init")

		-- 输入法 id 可用 `macism`（英文）或 `macism com.apple.inputmethod.SCIM.ITABC` 查询
		local im_native = "com.apple.inputmethod.SCIM.ITABC" -- macOS 简体拼音
		local im_default = "com.apple.keylayout.ABC" -- 美式键盘（英文）

		---@type im_select.Config
		local opts = {
			-- macOS 用 macism 读写当前输入法
			im_select_get_im_cmd = { "macism" },
			ImSelectSetImCmd = function(key)
				return { "macism", key }
			end,

			im_select_native_im = im_native,
			im_select_default = im_default,

			im_select_switch_timeout = 100,
			im_select_enable_focus_events = 1,
			im_select_enable_cmd_line = 1,

			-- 进入 insert 时的切换策略：按顺序取第一个返回非 nil 的结果
			insert_enter_strategies = {
				-- 光标左右是中文字符 / 中文标点 → 中文
				function(ctx)
					local chars = { ctx.charcode_before or 0, ctx.charcode_after or 0 }
					for _, nr in ipairs(chars) do
						if
							(nr >= 0x4E00 and nr <= 0x9FFF) -- CJK 统一表意文字
							or (nr >= 0x3000 and nr <= 0x303F) -- CJK 标点
							or (nr >= 0xFF00 and nr <= 0xFFEF) -- 全角字符
						then
							return im_native
						end
					end
				end,

				-- 光标左右是英文字母 → 英文
				function(ctx)
					local ch = ctx.char_before or ctx.char_after or ""
					if ch:match("%a") then
						return im_default
					end
				end,

				-- 代码文件：注释里 → 中文，否则英文
				function(ctx)
					local code_ft = {
						lua = true,
						python = true,
						rust = true,
						go = true,
						c = true,
						cpp = true,
						javascript = true,
						javascriptreact = true,
						typescript = true,
						typescriptreact = true,
						html = true,
						css = true,
						sh = true,
						sql = true,
					}
					if code_ft[ctx.filetype] then
						return ctx.is_inside_comment and im_native or im_default
					end
				end,

				-- Markdown / 纯文本 → 中文
				function(ctx)
					if ctx.filetype == "markdown" or ctx.filetype == "text" then
						return im_native
					end
				end,

				-- 兜底 → 英文
				function()
					return im_default
				end,
			},
		}

		im_select.setup(opts)
	end,
}
