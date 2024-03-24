-- https://github.com/chrisgrieser/nvim-various-textobjs

return {
	"chrisgrieser/nvim-various-textobjs",
	lazy = false,
	opts = { useDefaultKeymaps = true },
	config = function()
		-- 在未缩进的行上时，“ii”应选择整个缓冲区
		vim.keymap.set("o", "ii", function()
			if vim.fn.indent(".") == 0 then
				require("various-textobjs").entireBuffer()
			else
				require("various-textobjs").indentation("inner", "inner")
			end
		end)

		-- 强化gx功能
		-- 打开 URL 的函数
		local function openURL(url)
			-- 根据系统类型选择合适的命令
			local opener
			if vim.fn.has("macunix") == 1 then
				opener = "open"
			elseif vim.fn.has("linux") == 1 then
				opener = "xdg-open"
			elseif vim.fn.has("win64") == 1 or vim.fn.has("win32") == 1 then
				opener = "start"
			end
			-- 使用系统命令打开 URL
			local openCommand = string.format("%s '%s' >/dev/null 2>&1", opener, url)
			vim.fn.system(openCommand)
		end

		-- 从当前行获取 URL
		local function getURLFromLine(line, pattern)
			local url = line:match(pattern)
			return url
		end

		-- 获取缓冲区中的所有 URL
		local function getAllURLs(pattern)
			local bufText = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
			local urls = {}
			for line in bufText:gmatch("[^\n]+") do
				local url = getURLFromLine(line, pattern)
				if url then
					table.insert(urls, url)
				end
			end
			return urls
		end

		-- 设置按键映射，当用户按下 gx 键时触发操作
		vim.keymap.set("n", "gx", function()
			-- 调用 various-textobjs 插件的 url 函数，以便在选择 URL 时能够正确地获取到它
			require("various-textobjs").url()
			-- 检查当前模式是否为可视模式
			local isVisualMode = vim.fn.mode():find("v") ~= nil

			if isVisualMode then
				-- 在可视模式下，将选中的文本复制到寄存器 "z"
				vim.cmd([[ normal! "zy ]])
				-- 从寄存器 "z" 中获取 URL
				local url = vim.fn.getreg("z")
				-- 打开 URL
				openURL(url)
			else
				-- 如果不在可视模式下，则从缓冲区中查找所有的 URL
				local urlPattern = require("various-textobjs.charwise-textobjs").urlPattern
				local urls = getAllURLs(urlPattern)

				if #urls == 0 then
					return
				end

				-- 选择一个 URL，并使用 openURL 函数打开它
				vim.ui.select(urls, { prompt = "Select URL:" }, function(choice)
					if choice then
						openURL(choice)
					end
				end)
			end
		end, { desc = "URL Opener" })

		-- 删除缩进周围的行
		vim.keymap.set("n", "dsi", function()
			-- 选择缩进的外层文本对象
			require("various-textobjs").indentation("outer", "outer")
			-- 插件仅在找到文本对象时切换到可视模式
			local indentationFound = vim.fn.mode():find("V")
			if not indentationFound then
				return
			end
			-- 减少缩进
			vim.cmd.normal({ "<", bang = true })
			-- 删除周围的行
			local endBorderLn = vim.api.nvim_buf_get_mark(0, ">")[1]
			local startBorderLn = vim.api.nvim_buf_get_mark(0, "<")[1]
			vim.cmd(tostring(endBorderLn) .. " delete") -- 先删除结尾，以免行索引被移位
			vim.cmd(tostring(startBorderLn) .. " delete")
		end, { desc = "删除周围的缩进" })

		-- 复制缩进周围的行
		vim.keymap.set("n", "ysii", function()
			local startPos = vim.api.nvim_win_get_cursor(0)
			-- 确定开始和结束边界
			require("various-textobjs").indentation("outer", "outer")
			local indentationFound = vim.fn.mode():find("V")
			if not indentationFound then
				return
			end
			vim.cmd.normal({ "V", bang = true }) -- 离开可视模式以设置 `'<` `'>` 标记
			-- 将它们复制到 + 寄存器中
			local startLn = vim.api.nvim_buf_get_mark(0, "<")[1] - 1
			local endLn = vim.api.nvim_buf_get_mark(0, ">")[1] - 1
			local startLine = vim.api.nvim_buf_get_lines(0, startLn, startLn + 1, false)[1]
			local endLine = vim.api.nvim_buf_get_lines(0, endLn, endLn + 1, false)[1]
			vim.fn.setreg("+", startLine .. "\n" .. endLine .. "\n")
			-- 高亮复制的文本
			local ns = vim.api.nvim_create_namespace("ysi")
			vim.highlight.range(0, ns, "IncSearch", { startLn, 0 }, { startLn, -1 })
			vim.highlight.range(0, ns, "IncSearch", { endLn, 0 }, { endLn, -1 })
			vim.defer_fn(function()
				vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
			end, 1000)
			-- 恢复光标位置
			vim.api.nvim_win_set_cursor(0, startPos)
		end, { desc = "复制周围的缩进" })

		-- 自动缩进粘贴的文本
		vim.keymap.set("n", "P", function()
			require("various-textobjs").lastChange()
			local changeFound = vim.fn.mode():find("v")
			if changeFound then
				vim.cmd.normal({ ">", bang = true })
			end
		end, { desc = "Indent Last Paste" })
	end,
}
