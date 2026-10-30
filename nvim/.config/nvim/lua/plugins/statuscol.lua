-- https://github.com/luukvbaal/statuscol.nvim
--
-- 用 statuscol.nvim 接管 'statuscolumn'，给 git / 诊断 / DAP / 书签各分配一个
-- 固定列。原生 sign 列是「按 priority 从左到右紧凑排列，优先级低的图标在
-- 高优先级图标缺席时会左移」，无法为每类图标保留固定槽位；本插件按
-- name/namespace 把 sign 分到独立 segment，逻辑上等价于每类图标独占列。
--
-- 注意：0.13 起 sign 用 extmark（type='sign'）承载，插件的 sign 匹配也是读
-- extmark；gitsigns / 诊断 走 namespace 匹配，DAP / marks 是原生 sign 走 name 匹配。
return {
	"luukvbaal/statuscol.nvim",
	config = function()
		local builtin = require("statuscol.builtin")
		require("statuscol").setup({
			setopt = true, -- 由插件设置 'statuscolumn'
			-- 不为这些 filetype 注入 statuscolumn（否则 neotree 等侧栏会继承
			-- setopt 写入的全局默认值，多出整块行号/符号列把内容右推）。
			ft_ignore = {
				"sqmeow-drawer",
				"neo-tree",
				"todo2drawer",
				"NvimTree",
				"help",
				"qf", -- 只是不让它拿全局布局；qf 自己的 statuscolumn 见 setup() 之后的 special_stc
				"codecompanion", -- chat 只要行号：自己的 statuscolumn 见下面的 special_stc
				"alpha",
				-- ui.picker 的列表/预览/输入行：列表每行前面不能有行号/符号列
				"ui_picker_list",
				"ui_picker_preview",
				"ui_picker_prompt",
			},
			-- 每行同类 sign 只显示 1 个；colwidth = 1，配合插件「去掉图标内空白」
			-- 的行为（sign_text:gsub('%s','')），像 " " 这种带尾随空格的图标
			-- 不会被撑成两格，列宽才稳定。
			segments = {
				-- quicker.nvim 在 quickfix 里给每条类型（E/W/I/N/H）画的是 extmark sign，
				-- namespace = quicker_highlights。statuscol 只渲染这里显式列出的 sign，
				-- 没匹配到任何 segment 的 sign 直接被丢掉 —— 所以不单独列这段，qf 里就没有图标。
				{ sign = { namespace = { "quicker_highlights" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- 诊断（命名空间 diagnostic）与 DAP 断点（原生 sign，名字 Dap*）合并成一列：
				-- 同行有诊断时断点会被压掉（colwidth = 1, maxwidth = 1），换来每行少求一段。
				{
					sign = { namespace = { "diagnostic" }, name = { "Dap" }, colwidth = 1, maxwidth = 1 },
					click = "v:lua.ScSa",
				},
				-- neotest 测试状态：sign_place 在 0.13 里也是 extmark sign，但 sign_name 仍保留
				-- （如 neotest_passed），所以这里按 name 匹配。必须单独一列：neotest 的
				-- priority 是 1000，和诊断/断点共列会把它们压掉。
				{ sign = { name = { "neotest_" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- marks.nvim（原生 sign，名字 Marks_*）与 todo2 代码任务状态（extmark sign，
				-- namespace = code_render）共用一列：原生 sign 只按 name 匹配、extmark sign
				-- 只按 namespace 匹配，同一 segment 里两者可以并存；maxwidth = 1 所以同行
				-- 冲突时只显示一个（按 sign priority）。
				{
					sign = { name = { "Marks_" }, namespace = { "code_render" }, colwidth = 1, maxwidth = 1 },
					click = "v:lua.ScSa",
				},
				-- 行号（沿用内置实现，遵循 number/relativenumber）
				{
					text = { builtin.lnumfunc, " " },
					condition = { true, builtin.not_empty },
					click = "v:lua.ScLa",
				},
				-- git（gitsigns 的 extmark 命名空间为 gitsigns_signs_*）
				{ sign = { namespace = { "gitsigns" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- 折叠列放在最后，紧贴代码（还原旧 statuscolumn 的 "%s%=%l%=%C " 布局）
				{ text = { " %C " }, click = "v:lua.ScFa" },
			},
			-- clickhandlers 用内置默认即可：
			--   gitsigns   左键预览 hunk
			--   diagnostic 左键打开浮窗
			--   Dap*       左键切换断点
		})

		-- 少数 filetype 需要一套完全独立的极简 statuscolumn（不继承上面那套固定槽位布局）：
		-- statuscol.nvim 的 segments 是全局配置，没法按 filetype 裁剪，所以这些
		-- filetype 仍留在 ft_ignore 里（否则会继承那 5 个固定宽度的 sign 列），
		-- 改由下面的 autocmd 给对应窗口装本地版本：
		--   qf            类型图标（quicker 的 extmark sign）+ 绝对行号
		--   codecompanion 只要绝对行号，不要 sign / git / 折叠列
		--   %s         原生 sign 列，受本窗口 'signcolumn' 控制，所以设成 "auto"
		--   %{v:lnum}  不读 number/relativenumber，始终显示真实行号
		-- 必须注册在 setup() 之后：statuscol 的 ft_ignore 走 FileType `setlocal stc=`，
		-- 只有后注册的 autocmd 才覆盖得到；BufWinEnter 再补一次，防止被 statuscol
		-- 自己的 BufWinEnter 处理器清空。设置要落到「显示该 buffer 的所有窗口」上，
		-- 因为事件触发时当前窗口未必就是目标窗口。
		local special_stc = {
			qf = "%@v:lua.ScSa@%s%T%=%@v:lua.ScLa@%{v:lnum} %T",
			codecompanion = "%{v:lnum} %T",
		}
		-- statuscol 写进的是 window-local 选项的「全局值」，setup() 之后读到的就是它的表达式；
		-- 'statuscolumn'/'signcolumn' 都是 local to window，所以 vim.o.* 在别的窗口里读到的
		-- 不是全局值，要显式取 scope = "global"。
		local main_stc = vim.api.nvim_get_option_value("statuscolumn", { scope = "global" })
		local main_scl = vim.api.nvim_get_option_value("signcolumn", { scope = "global" })
		local function is_special_stc(value)
			for _, v in pairs(special_stc) do
				if value == v then
					return true
				end
			end
			return false
		end
		local function set_special_stc()
			local buf = vim.api.nvim_get_current_buf()
			local stc = special_stc[vim.bo[buf].filetype]
			for _, win in ipairs(vim.fn.win_findbuf(buf)) do
				if stc then
					vim.wo[win].signcolumn = "auto"
					vim.wo[win].statuscolumn = stc
				elseif is_special_stc(vim.wo[win].statuscolumn) then
					-- 同一个窗口从特殊 buffer（qf / chat）换成了普通 buffer：恢复全局值
					-- （也就是 statuscol 的表达式），否则会一直用着那套没有折叠列/
					-- 固定槽位的布局。
					vim.wo[win].statuscolumn = main_stc
					vim.wo[win].signcolumn = main_scl
				end
			end
		end
		vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
			group = vim.api.nvim_create_augroup("SpecialStatuscol", {}),
			pattern = "*",
			callback = set_special_stc,
		})
	end,
}
