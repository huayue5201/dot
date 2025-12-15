---@diagnostic disable: param-type-mismatch, undefined-field
local M = {}

-- ==============================
-- 文档请求策略表（可手动扩展）
-- ==============================
local doc_strategies = {
	rust = {
		external = "experimental/externalDocs", -- rust-analyzer 扩展
		fallback = "textDocument/hover",
	},
	python = {
		fallback = "textDocument/hover",
	},
	typescript = {
		fallback = "textDocument/hover",
		command = "workspace/executeCommand", -- tsserver 可选扩展
	},
	go = {
		fallback = "textDocument/hover",
	},
	java = {
		fallback = "textDocument/hover",
	},
	cpp = {
		fallback = "textDocument/hover",
	},
	lua = {
		fallback = "textDocument/hover",
	},
}

-- ==============================
-- 默认文档 URL 表（可手动扩展）
-- ==============================
local default_urls = {
	python = "https://docs.python.org/3/",
	javascript = "https://developer.mozilla.org/en-US/docs/Web/JavaScript",
	typescript = "https://www.typescriptlang.org/docs/",
	rust = "https://doc.rust-lang.org/",
	go = "https://go.dev/doc/",
	java = "https://docs.oracle.com/javase/8/docs/api/",
	cpp = "https://en.cppreference.com/w/",
	lua = "https://www.lua.org/manual/5.4/",
	html = "https://developer.mozilla.org/en-US/docs/Web/HTML",
	css = "https://developer.mozilla.org/en-US/docs/Web/CSS",
	json = "https://www.json.org/json-en.html",
	yaml = "https://yaml.org/spec/",
}

-- ==============================
-- 工具函数
-- ==============================
local function get_position_encoding()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	return clients[1] and clients[1].offset_encoding or "utf-16"
end

local function parse_hover_contents(contents)
	local str = ""
	if type(contents) == "string" then
		str = contents
	elseif vim.islist(contents) then
		for _, c in ipairs(contents) do
			if type(c) == "string" then
				str = str .. c .. "\n"
			elseif type(c) == "table" and c.value then
				str = str .. c.value .. "\n"
			end
		end
	elseif type(contents) == "table" and contents.value then
		str = contents.value
	end
	return str
end

-- ==============================
-- 主逻辑
-- ==============================
function M.open_docs()
	local ft = vim.bo.filetype
	local strategy = doc_strategies[ft]

	-- 1. externalDocs（Rust 专属）
	if strategy and strategy.external then
		local docs = M.get_external_docs(strategy.external)
		if docs then
			M.handle_external_docs(docs)
			return
		end
	end

	-- 2. hover 提取链接（通用）
	if strategy and strategy.fallback == "textDocument/hover" then
		local hover_info = M.get_hover_with_links()
		if hover_info and hover_info.links and #hover_info.links > 0 then
			M.choose_and_open_link(hover_info.links)
			return
		end
	end

	-- 3. 可选 command（如 tsserver）
	if strategy and strategy.command then
		local params = {
			command = "typescript.openDocLink", -- 假设 tsserver 提供这个命令
			arguments = { vim.uri_from_bufnr(0) }, -- 当前 buffer 的 URI
		}

		--- @diagnostic disable-next-line: param-type-mismatch
		local success, response = pcall(vim.lsp.buf_request_sync, 0, strategy.command, params, 3000)

		if success and response then
			for _, resp in pairs(response) do
				if resp and resp.result and type(resp.result) == "string" then
					M.open_url(resp.result)
					return
				end
			end
		end
	end

	-- 4. 默认文档
	M.open_default_docs()
end

-- ==============================
-- 获取外部文档
-- ==============================
function M.get_external_docs(method)
	local params = vim.lsp.util.make_position_params(0, get_position_encoding())
	--- @diagnostic disable-next-line: param-type-mismatch
	local success, response = pcall(vim.lsp.buf_request_sync, 0, method, params, 5000)

	if not success or not response or vim.tbl_isempty(response) then
		return nil
	end

	for _, resp in pairs(response) do
		if resp and resp.result then
			return resp.result
		end
	end
	return nil
end

-- ==============================
-- 处理外部文档结果
-- ==============================
function M.handle_external_docs(docs)
	if type(docs) == "string" then
		M.open_url(docs)
		return
	elseif type(docs) ~= "table" then
		vim.notify("文档格式无效: " .. type(docs), vim.log.levels.ERROR)
		M.open_default_docs()
		return
	end

	local url = nil
	if docs["local"] then
		local local_path = vim.uri_to_fname(docs["local"])
		if vim.loop.fs_stat(local_path) then
			url = docs["local"]
		end
	end
	if not url and docs.web then
		url = docs.web
	end
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
		M.open_default_docs()
	end
end

-- ==============================
-- 打开 URL
-- ==============================
function M.open_url(url)
	if not url then
		return
	end
	if url:find("^file://") then
		local local_path = vim.uri_to_fname(url)
		vim.cmd("edit " .. vim.fn.fnameescape(local_path))
		return
	end
	local success, err = pcall(vim.ui.open, url)
	if not success then
		vim.notify("无法打开: " .. url .. "\n错误信息: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- ==============================
-- 获取 hover 信息中的链接
-- ==============================
function M.get_hover_with_links()
	local params = vim.lsp.util.make_position_params(0, get_position_encoding())
	--- @diagnostic disable-next-line: param-type-mismatch
	local success, response = pcall(vim.lsp.buf_request_sync, 0, "textDocument/hover", params, 3000)

	if not success or not response or vim.tbl_isempty(response) then
		return nil
	end

	local _, first_value = next(response)
	if not first_value or not first_value.result then
		return nil
	end

	local hover = first_value.result
	local links = {}
	local content_str = parse_hover_contents(hover.contents)

	for text, target in content_str:gmatch("%[([^%]]*)%]%(([^%)]+)%)") do
		table.insert(links, { text = text ~= "" and text or target, target = target })
	end
	for url in content_str:gmatch("https?://[%w%.%-_/~#=&?%%]+") do
		table.insert(links, { text = url, target = url })
	end

	return #links > 0 and { links = links } or nil
end

-- ==============================
-- 选择并打开链接
-- ==============================
function M.choose_and_open_link(links)
	if not links or #links == 0 then
		vim.notify("没有可用的链接", vim.log.levels.INFO)
		M.open_default_docs()
		return
	end
	if #links == 1 then
		M.open_url(links[1].target)
		return
	end

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
			M.open_default_docs()
		end
	end)
end

-- ==============================
-- 打开默认文档
-- ==============================
function M.open_default_docs()
	local ft = vim.bo.filetype
	local url = default_urls[ft]
	if url then
		vim.notify("打开默认 " .. ft .. " 文档", vim.log.levels.INFO)
		M.open_url(url)
	else
		vim.notify("无法确定默认文档，请尝试手动搜索", vim.log.levels.WARN)
	end
end

return M
