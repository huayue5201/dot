-- https://github.com/jake-stewart/multicursor.nvim

return {
	"jake-stewart/multicursor.nvim",
	config = function()
		local mc = require("multicursor-nvim")
		mc.setup()

		local set = vim.keymap.set

		-- ============================================================
		-- 基础快捷键（上下行添加/跳过）
		-- ============================================================
		set({ "n", "x" }, "<up>", function()
			mc.lineAddCursor(-1)
		end, { desc = "multicursor: 在上方添加光标" })
		set({ "n", "x" }, "<down>", function()
			mc.lineAddCursor(1)
		end, { desc = "multicursor: 在下方添加光标" })
		set({ "n", "x" }, "<a-up>", function()
			mc.lineSkipCursor(-1)
		end, { desc = "multicursor: 跳过当前行并在上方添加光标" })
		set({ "n", "x" }, "<a-down>", function()
			mc.lineSkipCursor(1)
		end, { desc = "multicursor: 跳过当前行并在下方添加光标" })

		-- ============================================================
		-- 基础快捷键（匹配单词）
		-- ============================================================
		set({ "n", "x" }, "<localleader>n", function()
			mc.matchAddCursor(1)
		end, { desc = "multicursor: 向下匹配相同单词并添加光标" })
		set({ "n", "x" }, "<localleader>s", function()
			mc.matchSkipCursor(1)
		end, { desc = "multicursor: 向下匹配相同单词但跳过（仅跳转）" })
		set({ "n", "x" }, "<localleader>N", function()
			mc.matchAddCursor(-1)
		end, { desc = "multicursor: 向上匹配相同单词并添加光标" })
		set({ "n", "x" }, "<localleader>S", function()
			mc.matchSkipCursor(-1)
		end, { desc = "multicursor: 向上匹配相同单词但跳过（仅跳转）" })

		-- ============================================================
		-- 鼠标支持
		-- ============================================================
		set("n", "<c-leftmouse>", mc.handleMouse, { desc = "multicursor: Ctrl+鼠标点击添加/移除光标" })
		set("n", "<c-leftdrag>", mc.handleMouseDrag, { desc = "multicursor: Ctrl+鼠标拖拽选择区域" })
		set("n", "<c-leftrelease>", mc.handleMouseRelease, { desc = "multicursor: 释放鼠标完成多光标选择" })

		-- ============================================================
		-- 切换光标启用/禁用
		-- ============================================================
		set({ "n", "x" }, "<c-q>", mc.toggleCursor, { desc = "multicursor: 切换多光标启用/禁用状态" })

		-- ============================================================
		-- 高级操作：光标批量操作
		-- ============================================================
		-- 在每个选中的行添加光标（如 gaip = 给整个段落每行加光标）
		set(
			{ "n", "x" },
			"ga",
			mc.addCursorOperator,
			{ desc = "multicursor: 为每个选中的行添加光标（配合文本对象）" }
		)

		-- 克隆所有光标并禁用原始光标
		set(
			{ "n", "x" },
			"<localleader><c-q>",
			mc.duplicateCursors,
			{ desc = "multicursor: 克隆所有光标并禁用原始光标" }
		)

		-- 对齐光标列
		set("n", "<localleader>a", mc.alignCursors, { desc = "multicursor: 对齐所有光标到同一列" })

		-- 恢复意外清除的光标
		set("n", "<localleader>gv", mc.restoreCursors, { desc = "multicursor: 恢复意外清除的光标" })

		-- 给文档中所有匹配的单词添加光标
		set(
			{ "n", "x" },
			"<localleader>A",
			mc.matchAllAddCursors,
			{ desc = "multicursor: 给文档中所有匹配的单词添加光标" }
		)

		-- ============================================================
		-- 高级操作：可视模式增强
		-- ============================================================
		-- 用正则表达式拆分当前可视选择
		set("x", "S", mc.splitCursors, { desc = "multicursor: 用正则表达式拆分可视选择并添加光标" })

		-- 在可视选择内匹配正则并添加光标
		set("x", "M", mc.matchCursors, { desc = "multicursor: 在可视选择内匹配正则并添加光标" })

		-- 在每行开头/末尾插入（类似块选插入）
		set("x", "I", mc.insertVisual, { desc = "multicursor: 在每行开头插入（类似块选）" })
		set("x", "A", mc.appendVisual, { desc = "multicursor: 在每行末尾追加（类似块选）" })

		-- 轮换交换光标间的文本
		set("x", "gmct", function()
			mc.transposeCursors(1)
		end, { desc = "multicursor: 轮换交换光标间文本（正向）" })
		set("x", "gmcT", function()
			mc.transposeCursors(-1)
		end, { desc = "multicursor: 轮换交换光标间文本（反向）" })

		-- ============================================================
		-- 高级操作：数字序列
		-- ============================================================
		set({ "n", "x" }, "g<c-a>", mc.sequenceIncrement, { desc = "multicursor: 多光标数字序列递增" })
		set({ "n", "x" }, "g<c-x>", mc.sequenceDecrement, { desc = "multicursor: 多光标数字序列递减" })

		-- ============================================================
		-- 高级操作：搜索集成
		-- ============================================================
		-- 在搜索结果中逐次添加光标
		set("n", "<localleader>/n", function()
			mc.searchAddCursor(1)
		end, { desc = "multicursor: 向下给搜索结果添加光标" })
		set("n", "<localleader>/N", function()
			mc.searchAddCursor(-1)
		end, { desc = "multicursor: 向上给搜索结果添加光标" })

		-- 在搜索结果中移动（不添加光标）
		set("n", "<localleader>/s", function()
			mc.searchSkipCursor(1)
		end, { desc = "multicursor: 向下移动搜索结果（不添加光标）" })
		set("n", "<localleader>/S", function()
			mc.searchSkipCursor(-1)
		end, { desc = "multicursor: 向上移动搜索结果（不添加光标）" })

		-- 给所有搜索结果同时添加光标
		set("n", "<localleader>/A", mc.searchAllAddCursors, { desc = "multicursor: 给所有搜索结果添加光标" })

		-- ============================================================
		-- 高级操作：通用操作符（最强大）
		-- ============================================================
		-- 如 <localleader>miwap = 给当前单词的所有匹配加光标
		set(
			{ "n", "x" },
			"<localleader>m",
			mc.operator,
			{ desc = "multicursor: 通用匹配操作符（配合文本对象使用）" }
		)

		-- -- ============================================================
		-- -- 高级操作：诊断集成（LSP错误/警告）
		-- -- ============================================================
		-- -- 添加/跳过诊断错误光标
		-- set({ "n", "x" }, "]d", function() mc.diagnosticAddCursor(1) end,
		-- 	{ desc = "multicursor: 向下给诊断错误添加光标" })
		-- set({ "n", "x" }, "[d", function() mc.diagnosticAddCursor(-1) end,
		-- 	{ desc = "multicursor: 向上给诊断错误添加光标" })
		-- set({ "n", "x" }, "]s", function() mc.diagnosticSkipCursor(1) end,
		-- 	{ desc = "multicursor: 向下跳过诊断错误（仅跳转）" })
		-- set({ "n", "x" }, "[S", function() mc.diagnosticSkipCursor(-1) end,
		-- 	{ desc = "multicursor: 向上跳过诊断错误（仅跳转）" })

		-- -- 给范围内的所有错误诊断添加光标（如 mdip = 给当前段落所有错误加光标）
		-- set({ "n", "x" }, "md", function()
		-- 	mc.diagnosticMatchCursors({ severity = vim.diagnostic.severity.ERROR })
		-- end, { desc = "multicursor: 给范围内的所有错误诊断添加光标" })

		-- ============================================================
		-- 多光标模式下的专属快捷键层
		-- ============================================================
		mc.addKeymapLayer(function(layerSet)
			-- 切换主光标
			layerSet(
				{ "n", "x" },
				"<left>",
				mc.prevCursor,
				{ desc = "multicursor: 选择上一个光标作为主光标" }
			)
			layerSet(
				{ "n", "x" },
				"<right>",
				mc.nextCursor,
				{ desc = "multicursor: 选择下一个光标作为主光标" }
			)

			-- 删除当前光标
			layerSet({ "n", "x" }, "<localleader>x", mc.deleteCursor, { desc = "multicursor: 删除当前主光标" })

			-- Esc: 如果光标被禁用则启用，否则清除所有额外光标
			layerSet("n", "<esc>", function()
				if not mc.cursorsEnabled() then
					mc.enableCursors()
				else
					mc.clearCursors()
				end
			end, { desc = "multicursor: 退出多光标模式（清除所有光标或重新启用）" })
		end)

		-- ============================================================
		-- 光标高亮样式
		-- ============================================================
		local hl = vim.api.nvim_set_hl
		hl(0, "MultiCursorCursor", { reverse = true })
		hl(0, "MultiCursorVisual", { link = "Visual" })
		hl(0, "MultiCursorSign", { link = "SignColumn" })
		hl(0, "MultiCursorMatchPreview", { link = "Search" })
		hl(0, "MultiCursorDisabledCursor", { reverse = true })
		hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
		hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
	end,
}
