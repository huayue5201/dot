-- https://github.com/jake-stewart/multicursor.nvim

return {
	"jake-stewart/multicursor.nvim",
	event = "VeryLazy",
	config = function()
		local mc = require("multicursor-nvim")
		mc.setup()

		local set = vim.keymap.set

		-- 使用 gm 前缀
		set({ "n", "x" }, "<leader>n", function()
			mc.matchAddCursor(1)
		end, { desc = "添加下一个匹配" })
		set({ "n", "x" }, "<leader>N", function()
			mc.matchAddCursor(-1)
		end, { desc = "添加上一个匹配" })
		set({ "n", "x" }, "<leader>p", function()
			mc.matchSkipCursor(1)
		end, { desc = "跳过下一个" })
		set({ "n", "x" }, "<leader>P", function()
			mc.matchSkipCursor(-1)
		end, { desc = "跳过上一个" })
		set({ "n", "x" }, "gma", mc.matchAllAddCursors, { desc = "添加所有匹配" })

		-- 方向键
		set({ "n", "x" }, "<up>", function()
			mc.lineAddCursor(-1)
		end, { desc = "上方添加光标" })
		set({ "n", "x" }, "<down>", function()
			mc.lineAddCursor(1)
		end, { desc = "下方添加光标" })
		set({ "n", "x" }, "<leader><up>", function()
			mc.lineSkipCursor(-1)
		end, { desc = "上方跳过" })
		set({ "n", "x" }, "<leader><down>", function()
			mc.lineSkipCursor(1)
		end, { desc = "下方跳过" })

		-- 鼠标
		set("n", "<c-leftmouse>", mc.handleMouse)
		set("n", "<c-leftdrag>", mc.handleMouseDrag)
		set("n", "<c-leftrelease>", mc.handleMouseRelease)

		-- 开关
		set({ "n", "x" }, "<c-q>", mc.toggleCursor, { desc = "禁用/启用光标" })

		-- 多光标层
		mc.addKeymapLayer(function(layerSet)
			layerSet({ "n", "x" }, "<left>", mc.prevCursor, { desc = "上一个光标" })
			layerSet({ "n", "x" }, "<right>", mc.nextCursor, { desc = "下一个光标" })
			layerSet({ "n", "x" }, "<leader>x", mc.deleteCursor, { desc = "删除当前光标" })
			layerSet("n", "<esc>", function()
				if not mc.cursorsEnabled() then
					mc.enableCursors()
				else
					mc.clearCursors()
				end
			end)
		end)

		-- 高亮
		vim.api.nvim_set_hl(0, "MultiCursorCursor", { reverse = true })
		vim.api.nvim_set_hl(0, "MultiCursorVisual", { link = "Visual" })
	end,
}
