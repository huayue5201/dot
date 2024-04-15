-- /utils/url_opener.lua

local M = {}

-- 获取当前行的URL
local function getCurrentURL()
	local cursor = vim.fn.getpos(".")
	local current_line = vim.api.nvim_buf_get_lines(0, cursor[2] - 1, cursor[2], false)[1]
	local urlPattern = "https?://%S+"
	return current_line:match(urlPattern)
end

-- 获取缓冲区中的所有URL并带编号
local function getURLsWithNumbers()
	if M.cached_urls_with_numbers then
		return M.cached_urls_with_numbers
	end

	local bufText = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local urls = {}
	local urlPattern = "https?://%S+"

	for _, line in ipairs(bufText) do
		for url in line:gmatch(urlPattern) do
			table.insert(urls, url)
		end
	end

	local numbered_urls = {}
	for i, v in ipairs(urls) do
		table.insert(numbered_urls, i .. ". " .. v)
	end

	M.cached_urls_with_numbers = numbered_urls
	return numbered_urls
end

-- 打开URL的主函数
function M.open_url()
	local current_url = getCurrentURL()

	if current_url then
		vim.ui.open(current_url)
		return
	end

	local urls = getURLsWithNumbers()

	if #urls == 0 then
		print("No URLs found")
		return
	end

	vim.ui.select(urls, {
		prompt = "Select a URL:",
	}, function(selected_index, urls) -- 修正这里，添加urls参数
		if selected_index then
			-- 使用selected_index来获取正确的URL
			local selected_url = urls[selected_index]:match("https?://%S+")
			if selected_url then
				vim.ui.open(selected_url)
			else
				print("Invalid URL selected")
			end
		end
	end)
end

return M
