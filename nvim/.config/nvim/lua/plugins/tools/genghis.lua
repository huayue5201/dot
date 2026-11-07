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
		map("<leader>Fr", g.renameFile, "文件：重命名")
		map("<leader>Fm", g.moveToFolderInCwd, "文件：移动到当前目录下的文件夹")
		map("<leader>FM", g.moveAndRenameFile, "文件：移动 + 重命名")
		map("<leader>Fd", g.duplicateFile, "文件：复制一份")
		map("<leader>Fn", g.createNewFile, "文件：新建（当前文件所在目录）")
		map("<leader>FN", g.createNewFileInFolder, "文件：新建（当前工作目录下的文件夹）")
		map("<leader>Fv", g.moveSelectionToNewFile, "文件：把选中内容移到新文件", "x")

		-- 删除 / 权限 / 定位
		map("<leader>Ft", g.trashFile, "文件：删除到回收站")
		map("<leader>Fx", g.chmodx, "文件：chmod +x")
		map("<leader>Fe", g.showInSystemExplorer, "文件：在系统文件管理器中显示")

		-- 复制路径 / 文件名（系统剪贴板）
		map("<leader>Fy", g.copyFilepath, "文件：复制绝对路径")
		map("<leader>FY", g.copyRelativePath, "文件：复制相对路径")
		map("<leader>Fc", g.copyFilename, "文件：复制文件名")
	end,
}
