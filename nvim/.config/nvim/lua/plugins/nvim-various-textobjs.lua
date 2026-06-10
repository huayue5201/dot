-- https://github.com/chrisgrieser/nvim-various-textobjs
-- 提供超过30个实用的文本对象，大幅提升文本编辑效率

return {
	"chrisgrieser/nvim-various-textobjs",
	event = "VeryLazy", -- 延迟加载，提升启动速度
	config = function()
		-- 配置插件
		require("various-textobjs").setup({
			keymaps = {
				useDefaults = true, -- 使用默认快捷键
				disabledDefaults = {},
			},
			forwardLooking = {
				small = 5, -- 小范围向前查找行数
				big = 15, -- 大范围向前查找行数
			},
			behavior = {
				jumplist = true, -- 保存跳转列表位置
			},
			textobjs = {
				indentation = {
					blanksAreDelimiter = false, -- 仅缩进减少作为分隔符
				},
				subword = {
					noCamelToPascalCase = true, -- 删除驼峰词开头时保持格式
				},
				diagnostic = {
					wrap = true,
				},
				url = {
					-- 使用普通字符串而非长字符串，避免 ]] 语法错误
					patterns = { "%l%l%l+://[^%s%)%]%}\"'`>]+" },
				},
			},
			notify = {
				icon = "󰠱",
				whenObjectNotFound = true,
			},
			debug = false,
		})

		-- ============================================================
		-- 智能 URL 打开器（替代内置 gx）
		-- 功能：向前查找下一个 URL 并打开，光标无需在 URL 上
		-- ============================================================
		vim.keymap.set("n", "gx", function()
			require("various-textobjs").url()
			if vim.fn.mode() == "v" then
				local url = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"), { type = "v" })[1]
				vim.ui.open(url)
				vim.cmd.normal({ "v", bang = true })
			end
		end, { desc = "智能 URL 打开器" })

		-- ============================================================
		-- 智能文件路径打开器（替代内置 gf）
		-- 功能：向前查找下一个文件路径并打开，光标无需在路径上
		-- ============================================================
		vim.keymap.set("n", "gf", function()
			require("various-textobjs").filepath("outer")
			if vim.fn.mode() == "v" then
				local path = vim.fn.getregion(vim.fn.getpos("."), vim.fn.getpos("v"), { type = "v" })[1]
				if vim.uv.fs_stat(vim.fs.normalize(path)) then
					vim.ui.open(path)
				else
					vim.notify("路径不存在: " .. path, vim.log.levels.WARN)
				end
			end
		end, { desc = "智能文件路径打开器" })

		-- ============================================================
		-- 删除环绕缩进
		-- 功能：删除当前缩进块上下两行，常用于移除 if/for 等包裹
		-- 示例：
		--   if foo then
		--       print("bar")  <- 光标在此
		--       print("baz")
		--   end
		-- 执行 dsi 后变为：
		--   print("bar")
		--   print("baz")
		-- ============================================================
		vim.keymap.set("n", "dsi", function()
			require("various-textobjs").indentation("outer", "outer")
			if vim.fn.mode():find("V") then
				vim.cmd.normal({ "<", bang = true })
				local endLn = vim.api.nvim_buf_get_mark(0, ">")[1]
				local startLn = vim.api.nvim_buf_get_mark(0, "<")[1]
				vim.cmd(tostring(endLn) .. " delete")
				vim.cmd(tostring(startLn) .. " delete")
			end
		end, { desc = "删除环绕缩进" })

		-- ============================================================
		-- 粘贴后自动缩进
		-- 功能：粘贴后自动将粘贴的内容向右缩进一档
		-- 适用于 Python 等缩进敏感的语言
		-- 注意：使用 <leader>p 避免覆盖默认粘贴功能
		-- ============================================================
		vim.keymap.set("n", "<a-p>", function()
			local cursorPos = vim.api.nvim_win_get_cursor(0)
			vim.cmd.normal({ "p", bang = true })
			require("various-textobjs").lastChange()
			if vim.fn.mode():find("v") then
				vim.cmd.normal({ ">", bang = true })
			end
			vim.api.nvim_win_set_cursor(0, cursorPos)
		end, { desc = "粘贴后自动缩进" })
	end,
}
