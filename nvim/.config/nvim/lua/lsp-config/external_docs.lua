---@diagnostic disable: undefined-field
local M = {}

-- 获取位置编码
local function get_position_encoding()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	return clients[1] and clients[1].offset_encoding or "utf-16"
end

-- 智能文档跳转（单一入口点）
function M.open_docs()
	-- 1. 首先尝试获取 LSP 外部文档
	local docs = M.get_external_docs()
	if docs then
		M.handle_external_docs(docs)
		return
	end

	-- 2. 尝试获取 hover 信息中的链接
	local hover_info = M.get_hover_with_links()
	if hover_info and hover_info.links and #hover_info.links > 0 then
		-- 让用户选择链接
		M.choose_and_open_link(hover_info.links)
		return
	end

	-- 3. 最后的回退：使用默认文档
	M.open_default_docs()
end

-- 检查是否有 LSP 客户端支持 externalDocs
function M.has_external_docs_support()
	-- 使用新的 API vim.lsp.get_clients
	local clients = vim.lsp.get_clients({ bufnr = 0 })

	for _, client in ipairs(clients) do
		-- 检查客户端是否支持 externalDocsProvider
		if client.server_capabilities and client.server_capabilities.externalDocsProvider then
			return true, client
		end
	end

	-- Rust 特别优化：假设 rust-analyzer 可能支持
	for _, client in ipairs(clients) do
		if client.name == "rust-analyzer" then
			return true, client
		end
	end

	return false, nil
end

-- 获取外部文档
function M.get_external_docs()
	local has_support, client = M.has_external_docs_support()

	if not has_support then
		return nil
	end

	-- 使用正确的位置编码
	local params = vim.lsp.util.make_position_params(0, get_position_encoding())

	local success, response = pcall(vim.lsp.buf_request_sync, 0, "experimental/externalDocs", params, 5000)

	if not success or not response or vim.tbl_isempty(response) then
		return nil
	end

	-- 获取第一个有效的响应
	for _, resp in pairs(response) do
		if resp and resp.result then
			return resp.result
		end
	end

	return nil
end

-- 处理外部文档结果
function M.handle_external_docs(docs)
	-- 先检查 docs 类型
	if type(docs) == "string" then
		-- 如果 docs 是字符串，直接作为 URL 打开
		M.open_url(docs)
		return
	elseif type(docs) ~= "table" then
		vim.notify("文档格式无效: " .. type(docs), vim.log.levels.ERROR)
		M.open_default_docs()
		return
	end

	local url = nil

	-- 优先使用本地文档
	if docs["local"] then
		local local_path = vim.uri_to_fname(docs["local"])
		local file_exists = vim.loop.fs_stat(local_path)
		if file_exists then
			url = docs["local"]
		end
	end

	-- 其次使用在线文档
	if not url and docs.web then
		url = docs.web
	end

	-- 最后尝试其他可能的 URL 字段
	if not url then
		for _, value in pairs(docs) do
			if type(value) == "string" and (value:find("^https?://") or value:find("^file://")) then
				url = value
				break
			end
		end
	end

	if url then
		M.open_url(url)
	else
		vim.notify("未找到有效的文档 URL", vim.log.levels.WARN)
		M.open_default_docs() -- 回退到默认文档
	end
end

-- 打开 URL
function M.open_url(url)
	if not url then
		return
	end

	-- 处理 file:// URL
	if url:find("^file://") then
		local local_path = vim.uri_to_fname(url)
		vim.cmd("edit " .. vim.fn.fnameescape(local_path))
		return
	end

	-- 使用 vim.ui.open 打开在线 URL
	local success, err = pcall(vim.ui.open, url)
	if not success then
		vim.notify("无法打开: " .. url .. "\n错误信息: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- 获取 hover 信息中的链接
function M.get_hover_with_links()
	-- 使用正确的位置编码
	local params = vim.lsp.util.make_position_params(0, get_position_encoding())

	local success, response = pcall(vim.lsp.buf_request_sync, 0, "textDocument/hover", params, 3000)

	if not success or not response or vim.tbl_isempty(response) then
		return nil
	end

	-- 正确获取第一个响应（键值对）
	local first_key, first_value = next(response)
	if not first_key or not first_value then
		return nil
	end

	local hover = first_value.result
	if not hover then
		return nil
	end

	local links = {}

	if hover.contents then
		local content_str = ""

		if type(hover.contents) == "table" then
			content_str = hover.contents.value or ""
		elseif type(hover.contents) == "string" then
			content_str = hover.contents
		end

		-- 提取 Markdown 链接
		for text, target in content_str:gmatch("%[([^%]]*)%]%(([^%)]+)%)") do
			if target then
				table.insert(links, {
					text = text ~= "" and text or target,
					target = target,
				})
			end
		end

		-- 提取纯 URL
		for url in content_str:gmatch("https?://[%w%.%-_/~#=&?%%]+") do
			table.insert(links, {
				text = url,
				target = url,
			})
		end
	end

	return #links > 0 and { links = links } or nil
end

-- 让用户选择并打开链接
function M.choose_and_open_link(links)
	if not links or #links == 0 then
		vim.notify("没有可用的链接", vim.log.levels.INFO)
		M.open_default_docs()
		return
	end

	-- 如果只有一个链接，直接打开
	if #links == 1 then
		M.open_url(links[1].target)
		return
	end

	-- 多个链接，让用户选择
	local items = {}
	for i, link in ipairs(links) do
		table.insert(items, {
			index = i,
			text = link.text or link.target or ("链接 " .. i),
			target = link.target,
		})
	end

	vim.ui.select(items, {
		prompt = "选择要打开的链接:",
		format_item = function(item)
			local display = item.text
			if #display > 50 then
				display = display:sub(1, 47) .. "..."
			end
			return display
		end,
	}, function(selected)
		if selected and selected.target then
			M.open_url(selected.target)
		else
			M.open_default_docs() -- 用户取消选择，回退到默认
		end
	end)
end

-- 打开默认文档
function M.open_default_docs()
	local filetype = vim.bo.filetype
	local default_urls = {
		python = "https://docs.python.org/3/",
		javascript = "https://developer.mozilla.org/en-US/docs/Web/JavaScript",
		typescript = "https://www.typescriptlang.org/docs/",
		rust = "https://doc.rust-lang.org/",
		go = "https://go.dev/doc/",
		java = "https://docs.oracle.com/javase/8/docs/api/",
		cpp = "https://en.cppreference.com/w/",
		lua = "https://www.lua.org/manual/5.4/",
	}

	local url = default_urls[filetype]
	if url then
		vim.notify("打开默认 " .. filetype .. " 文档", vim.log.levels.INFO)
		M.open_url(url)
	else
		vim.notify("无法确定默认文档，请尝试手动搜索", vim.log.levels.WARN)
	end
end

return M
