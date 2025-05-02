-- 可配置项
local fd_cmd = "fd --color=never --full-path --type file --hidden --exclude=.git"

-- grep 异步搜索并打开 quickfix
vim.keymap.set("n", "<leader>/", function()
	vim.ui.input({ prompt = "rg pattern: " }, function(pattern)
		if not pattern or pattern == "" then
			return
		end

		vim.system({ "rg", "--vimgrep", "--smart-case", pattern }, { text = true }, function(res)
			vim.schedule(function()
				if res.code ~= 0 then
					local err_msg = res.stderr or "Unknown error"
					vim.notify("rg failed: " .. err_msg, vim.log.levels.ERROR)
					return
				end
				local lines = vim.split(res.stdout or "", "\n", { trimempty = true })
				if #lines == 0 then
					vim.notify("No results found for pattern: " .. pattern, vim.log.levels.WARN)
					return
				end
				vim.fn.setqflist({}, " ", {
					title = ("rg: %s"):format(pattern),
					lines = lines,
				})
				vim.cmd("copen")
			end)
		end)
	end)
end, { desc = "rawdog: grep search" })

-- fd 异步搜索并使用 ui.select 选择文件
vim.keymap.set("n", "<C-p>", function()
	vim.ui.input({ prompt = "fd pattern: " }, function(file_pattern)
		if not file_pattern or file_pattern == "" then
			return
		end

		local pattern = file_pattern
		if pattern:sub(1, 1) == "*" then
			pattern = pattern:gsub(".", ".*%%0") .. ".*"
		end

		local cmd = fd_cmd .. ' "' .. pattern .. '"'

		vim.system({ "sh", "-c", cmd }, { text = true }, function(res)
			vim.schedule(function()
				if res.code ~= 0 then
					vim.notify("fd failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
					return
				end

				local files = vim.split(res.stdout or "", "\n", { trimempty = true })
				if #files == 0 then
					vim.notify("No file found", vim.log.levels.WARN, { title = "rawdog.fd" })
					return
				end

				vim.ui.select(files, { prompt = "Open file:" }, function(choice)
					if choice then
						vim.schedule(function()
							vim.cmd.edit(vim.fn.fnameescape(choice))
						end)
					end
				end)
			end)
		end)
	end)
end, { desc = "rawdog: file search" })
