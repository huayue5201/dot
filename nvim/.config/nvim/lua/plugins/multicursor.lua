-- https://github.com/jake-stewart/multicursor.nvim

return {
	"jake-stewart/multicursor.nvim",
	branch = "1.0",
	config = function()
		-- 引入 multicursor 插件模块
		local mc = require("multicursor-nvim")
		-- 初始化插件，使用默认配置
		mc.setup()

		-- 本地化 vim.keymap.set 函数，简化后续代码
		local set = vim.keymap.set

		-- 在当前光标的上方或下方添加/跳过光标（主光标移动）
		-- <up> / <down>：在当前行上方/下方添加新光标
		set({ "n", "x" }, "<up>", function()
			mc.lineAddCursor(-1) -- 向上添加光标
		end, { desc = "multicursor: 向上添加光标" })

		set({ "n", "x" }, "<down>", function()
			mc.lineAddCursor(1) -- 向下添加光标
		end, { desc = "multicursor: 向下添加光标" })

		-- <leader><up> / <leader><down>：跳过当前行，在上方/下方添加光标
		set({ "n", "x" }, "<leader><up>", function()
			mc.lineSkipCursor(-1) -- 向上跳过添加光标
		end, { desc = "multicursor: 向上跳过当前行并添加光标" })

		set({ "n", "x" }, "<leader><down>", function()
			mc.lineSkipCursor(1) -- 向下跳过添加光标
		end, { desc = "multicursor: 向下跳过当前行并添加光标" })

		-- 根据当前选中的单词或文本匹配添加/跳过光标
		-- <c-n>：向下匹配并添加光标（类似 VSCode 的 Ctrl+D）
		set({ "n", "x" }, "<c-n>", function()
			mc.matchAddCursor(1) -- 匹配添加光标（下一个匹配项）
		end, { desc = "multicursor: 匹配下一个单词并添加光标" })

		-- <c-p>：向下匹配但跳过当前，不添加光标（即只跳转）
		set({ "n", "x" }, "<c-p>", function()
			mc.matchSkipCursor(1) -- 匹配并跳过光标（下一个匹配项）
		end, { desc = "multicursor: 匹配下一个单词但跳过（仅跳转）" })

		-- <c-N>：向上匹配并添加光标（注意：<c-N> 是 Shift+Ctrl+N）
		set({ "n", "x" }, "<c-N>", function()
			mc.matchAddCursor(-1) -- 匹配添加光标（上一个匹配项）
		end, { desc = "multicursor: 匹配上一个单词并添加光标" })

		-- <c-P>：向上匹配但跳过当前，不添加光标
		set({ "n", "x" }, "<c-P>", function()
			mc.matchSkipCursor(-1) -- 匹配跳过光标（上一个匹配项）
		end, { desc = "multicursor: 匹配上一个单词但跳过（仅跳转）" })

		-- 使用 Ctrl + 鼠标左键添加/移除光标（图形界面操作）
		set("n", "<c-leftmouse>", mc.handleMouse, { desc = "multicursor: Ctrl+鼠标点击添加/移除光标" })
		set("n", "<c-leftdrag>", mc.handleMouseDrag, { desc = "multicursor: Ctrl+鼠标拖拽选择区域" })
		set("n", "<c-leftrelease>", mc.handleMouseRelease, { desc = "multicursor: 释放鼠标完成多光标选择" })

		-- 禁用/启用所有光标（<C-q> 切换）
		set({ "n", "x" }, "<c-q>", mc.toggleCursor, { desc = "multicursor: 切换多光标启用/禁用状态" })

		-- 定义多光标模式下的专属快捷键层
		-- 这些快捷键仅在存在多个光标时生效，避免和普通模式快捷键冲突
		mc.addKeymapLayer(function(layerSet)
			-- 在多光标之间切换主光标位置
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

			-- 删除当前主光标（不影响其他光标）
			layerSet({ "n", "x" }, "<c-BS>", mc.deleteCursor, { desc = "multicursor: 删除当前主光标" })

			-- 按 <Esc> 的行为：
			--   如果光标被禁用则启用它们
			--   否则清除所有多余光标，只保留主光标
			layerSet("n", "<esc>", function()
				if not mc.cursorsEnabled() then
					mc.enableCursors() -- 启用光标
				else
					mc.clearCursors() -- 清除所有光标
				end
			end, { desc = "multicursor: 清除所有光标或启用光标" })
		end)

		-- 自定义多光标的显示样式（高亮组）
		local hl = vim.api.nvim_set_hl
		hl(0, "MultiCursorCursor", { reverse = true }) -- 光标样式：反转前景背景色
		hl(0, "MultiCursorVisual", { link = "Visual" }) -- 可视模式样式：跟随默认 Visual 样式
		hl(0, "MultiCursorSign", { link = "SignColumn" }) -- 符号列样式：跟随默认符号列
		hl(0, "MultiCursorMatchPreview", { link = "Search" }) -- 匹配预览样式：跟随搜索高亮
		hl(0, "MultiCursorDisabledCursor", { reverse = true }) -- 禁用状态下的光标样式
		hl(0, "MultiCursorDisabledVisual", { link = "Visual" }) -- 禁用状态下的可视模式样式
		hl(0, "MultiCursorDisabledSign", { link = "SignColumn" }) -- 禁用状态下的符号列样式
	end,
}
