-- https://github.com/chrisgrieser/nvim-genghis
--
-- 轻量文件操作（不做文件树）：重命名 / 移动 / 复制 / 新建 / 回收站 / chmod +x /
-- 复制路径 / 在系统文件管理器里定位。改名和移动会通过 LSP
-- `workspace/willRenameFiles` 顺带更新 import（Python / TS / Go 等支持的语言）。
--
-- 键位统一放在 `<leader>F`（文件操作）下，和 `<leader>f`（查找）区分开：
--   F 是 Shift+f，紧挨着查找组，但不会误触。
-- 需要 nvim 0.10+；回收站用 macOS 自带的 `trash`。

return {
	"chrisgrieser/nvim-genghis",
	config = function()
		require("genghis").setup({
			fileOperations = {
				-- 输入不带扩展名时沿用原文件扩展名（`foo` → `foo.md`）
				autoAddExt = true,
			},
			-- 操作成功后发通知
			successNotifications = true,
		})

		local g = require("genghis")
		local function map(lhs, fn, desc, mode)
			vim.keymap.set(mode or "n", lhs, fn, { desc = desc })
		end

		-- 重命名 / 移动 / 复制 / 新建
		map("<leader>Fr", g.renameFile, "File: rename")
		map("<leader>Fm", g.moveToFolderInCwd, "File: move to folder in cwd")
		map("<leader>FM", g.moveAndRenameFile, "File: move and rename")
		map("<leader>Fd", g.duplicateFile, "File: duplicate")
		map("<leader>Fn", g.createNewFile, "File: new (in current file's directory)")
		map("<leader>FN", g.createNewFileInFolder, "File: new (in folder under cwd)")
		map("<leader>Fv", g.moveSelectionToNewFile, "File: move selection to new file", "x")

		-- 删除 / 权限 / 定位
		map("<leader>Ft", g.trashFile, "File: trash")
		map("<leader>Fx", g.chmodx, "File: chmod +x")
		map("<leader>Fe", g.showInSystemExplorer, "File: reveal in system file manager")

		-- 复制路径 / 文件名（系统剪贴板）
		map("<leader>Fy", g.copyFilepath, "File: copy absolute path")
		map("<leader>FY", g.copyRelativePath, "File: copy relative path")
		map("<leader>Fc", g.copyFilename, "File: copy filename")
	end,
}
