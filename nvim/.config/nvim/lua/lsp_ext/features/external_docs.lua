-- lua/lsp_ext/features/external_docs.lua
-- `gro`：打开当前符号的外部文档
--
-- 策略（按顺序回退，全部异步、各自有超时，不阻塞 UI）：
--   1) 服务端原生 externalDocs（rust-analyzer 的 experimental/externalDocs）
--   2) textDocument/hover 里抽取链接（markdown 链接 / 裸 URL / file://）
--   3) 用光标下的词构造语言的搜索 URL；再不行才打开语言主页
--
-- 可通过 lsp_ext.features.external_docs.setup{} 扩展策略与 URL（见文件末 DEFAULTS）。
local M = {}

local lsp_request = require("lib.lsp_request")

local DEFAULTS = {
	-- 每个 LSP 请求的超时（毫秒）；超时后回退下一步，不再卡住界面
	timeout = 1500,
	-- 对 Neovim 自身的 API（`vim.xxx` / `nvim_xxx`）优先用 `:help` 打开内置文档，而不是开网页
	vim_help = true,
	-- server 同时给了 web 与 local 时的取舍：false = 优先 web（外部文档），true = 优先本地源码
	prefer_local = false,
	-- 每种 filetype 的取文档方式：
	--   external = 服务端原生方法名（可选）
	--   hover    = 是否允许从 hover 里抽链接（默认允许）
	strategies = {
		rust = { external = "experimental/externalDocs" },
		python = {},
		typescript = {},
		javascript = {},
		go = {},
		java = {},
		cpp = {},
		lua = {},
		html = {},
		css = {},
		json = {},
		yaml = {},
	},
	-- 搜索 URL 模板（%s 会被替换成光标下的词）
	search_urls = {
		rust = "https://docs.rs/releases/search?query=%s",
		python = "https://docs.python.org/3/search.html?q=%s",
		typescript = "https://developer.mozilla.org/en-US/search?q=%s",
		javascript = "https://developer.mozilla.org/en-US/search?q=%s",
		html = "https://developer.mozilla.org/en-US/search?q=%s",
		css = "https://developer.mozilla.org/en-US/search?q=%s",
		go = "https://pkg.go.dev/search?q=%s",
		cpp = "https://en.cppreference.com/w/index.php?title=Special%3ASearch&search=%s",
		lua = "https://www.lua.org/manual/5.4/",
	},
	-- 语言主页（没有搜索模板或光标下无词时使用）
	home_urls = {
		rust = "https://doc.rust-lang.org/",
		python = "https://docs.python.org/3/",
		typescript = "https://www.typescriptlang.org/docs/",
		javascript = "https://developer.mozilla.org/en-US/docs/Web/JavaScript",
		go = "https://go.dev/doc/",
		java = "https://docs.oracle.com/en/java/javase/21/docs/api/",
		cpp = "https://en.cppreference.com/w/cpp",
		lua = "https://www.lua.org/manual/5.4/",
		html = "https://developer.mozilla.org/en-US/docs/Web/HTML",
		css = "https://developer.mozilla.org/en-US/docs/Web/CSS",
		json = "https://www.json.org/json-en.html",
		yaml = "https://yaml.org/spec/",
	},
}

local config = vim.deepcopy(DEFAULTS)

local function notify(msg, level)
	vim.notify("[docs] " .. msg, level or vim.log.levels.INFO)
end

local function short_name(path)
	return vim.fn.fnamemodify(path, ":t")
end

--- 选择支持某个方法的 client（按 client id 稳定排序，避免 pairs 顺序不确定）
local function pick_client(bufnr, method)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	table.sort(clients, function(a, b)
		return a.id < b.id
	end)
	for _, c in ipairs(clients) do
		if not method or c:supports_method(method, bufnr) then
			return c
		end
	end
end

--- 构造请求位置（用显示该 buffer 的窗口，避免拿错窗口）
local function position_params(client, bufnr)
	local win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_buf(win) ~= bufnr then
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(w) == bufnr then
				win = w
				break
			end
		end
	end
	if vim.api.nvim_win_get_buf(win) ~= bufnr then
		return {
			textDocument = vim.lsp.util.make_text_document_params(bufnr),
			position = { line = 0, character = 0 },
		}
	end
	return vim.lsp.util.make_position_params(win, client.offset_encoding)
end

--- 解析 hover contents（string / MarkupContent / MarkedString / 列表）
local function hover_text(contents)
	if type(contents) == "string" then
		return contents
	end
	if type(contents) ~= "table" then
		return ""
	end
	if type(contents.value) == "string" then
		return contents.value
	end
	local parts = {}
	for _, c in ipairs(contents) do
		if type(c) == "string" then
			parts[#parts + 1] = c
		elseif type(c) == "table" and type(c.value) == "string" then
			parts[#parts + 1] = c.value
		end
	end
	return table.concat(parts, "\n")
end

--- 剪掉 URL 尾部的标点；`)` 只在括号不配对时才剪
local function trim_url_tail(s)
	while true do
		local last = s:sub(-1)
		if last == ")" then
			local opens = select(2, s:gsub("%(", ""))
			local closes = select(2, s:gsub("%)", ""))
			if closes <= opens then
				return s
			end
			s = s:sub(1, -2)
		elseif last ~= "" and last:find("[%.,;:}%]>'\"]") then
			s = s:sub(1, -2)
		else
			return s
		end
	end
end

--- 从一段 markdown/纯文本里抽链接
--- 先扫 markdown 链接并从文本中剔除，再扫裸 URL，避免同一个 URL 被记两次；
--- 裸 URL 允许 `:` `+` `@` `$` `'` `(` `)` `,` 等字符，最后再剪掉尾部的标点。
local function extract_links(text)
	local links, seen = {}, {}

	local function add(target, label)
		if type(target) ~= "string" then
			return
		end
		target = trim_url_tail(target:gsub("^<", ""):gsub(">$", ""))
		if target == "" or seen[target] then
			return
		end
		seen[target] = true
		links[#links + 1] = {
			text = (type(label) == "string" and label ~= "") and label or target,
			target = target,
		}
	end

	local rest = text:gsub("%[([^%]]*)%]%(([^%s%)]+)%)", function(label, target)
		add(target, label)
		return " "
	end)

	for url in rest:gmatch("[%a][%w+.-]*://[^%s<>\"'`|%]]+") do
		add(url)
	end

	return links
end

--- 从 externalDocs 的返回里挑一个 URL
local function pick_doc_url(docs)
	if type(docs) == "string" then
		return docs
	end
	if type(docs) ~= "table" then
		return nil
	end

	local function local_doc()
		local path = docs["local"]
		if type(path) ~= "string" then
			return nil
		end
		local fname = path:find("^file://") and vim.uri_to_fname(path) or path
		if vim.uv.fs_stat(fname) then
			return path
		end
		return nil
	end

	local function web_doc()
		return type(docs.web) == "string" and docs.web or nil
	end

	local primary = config.prefer_local and local_doc or web_doc
	local secondary = config.prefer_local and web_doc or local_doc
	local url = primary() or secondary()
	if url then
		return url
	end

	-- 未知形状：扫第一个像 URL 的字符串（本地文件必须真实存在）
	for _, value in pairs(docs) do
		if type(value) == "string" then
			if value:find("^https?://") then
				return value
			end
			if value:find("^file://") and vim.uv.fs_stat(vim.uri_to_fname(value)) then
				return value
			end
		end
	end
	return nil
end

--- 光标下的完整点分表达式（`vim.lsp.get_clients`、`vim.api.nvim_buf_get_lines`…）
--- 光标不在任何标识符上时返回 nil
---@param bufnr integer
---@return string|nil
local function expr_at_cursor(bufnr)
	local pos = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1] or ""
	local col = pos[2] + 1 -- 1-based 字节位
	local from = 1
	while true do
		local a, b = line:find("[%w_%.:]+", from)
		if not a then
			return nil
		end
		if col <= b then
			if col < a then
				return nil -- 光标在空白/标点上
			end
			local expr = line:sub(a, b):gsub("^[.:]+", ""):gsub("[.:]+$", "")
			if not expr:find("%a") then
				return nil -- 纯数字
			end
			return expr
		end
		from = b + 1
	end
end

--- 把光标下的表达式翻成 `:help` 标签候选（由具体到笼统，逐个尝试）
---@param expr string
---@param ft string
---@return string[]
local function help_tag_candidates(expr, ft)
	local tags, seen = {}, {}
	local function add(tag)
		if tag and tag ~= "" and not seen[tag] then
			seen[tag] = true
			tags[#tags + 1] = tag
		end
	end

	-- nvim_buf_get_lines / vim.api.nvim_buf_get_lines → `nvim_buf_get_lines()`
	local api = expr:match("(nvim_[%w_]+)$")
	if api then
		add(api .. "()")
	end

	-- vim.fn.expand → `expand()`
	local fn = expr:match("^vim%.fn%.([%w_]+)$")
	if fn then
		add(fn .. "()")
	end

	-- Vimscript 文件里的内建函数 / ex 命令 / 选项
	if ft == "vim" and expr:match("^[%w_]+$") then
		add(expr .. "()")
		add(expr)
	end

	-- vim.lsp.get_clients → vim.lsp.get_clients() → vim.lsp
	-- （不退化到裸 `vim`，否则拼错的 API 会静默打开 `:h vim` 这种过泛的页面）
	local cur = expr
	while cur ~= "" do
		if cur ~= "vim" or expr == "vim" then
			add(cur .. "()")
			add(cur)
		end
		cur = cur:match("^(.*)%.[%w_]+$") or ""
	end

	return tags
end

--- Neovim 自身 API：直接用内置 `:help` 打开
--- 只有看起来像 vim API（`vim.*` / `nvim_*`）或 filetype=vim 时才接管，
--- 避免把普通变量名误当成帮助标签
---@param bufnr integer
---@return boolean handled 已处理（已打开帮助，或已提示找不到）
function M.open_vim_help(bufnr)
	local ft = vim.bo[bufnr].filetype
	local expr = expr_at_cursor(bufnr)
	if not expr then
		return false
	end

	local is_vim_api = expr == "vim" or expr:match("^vim%.") ~= nil or expr:match("^nvim_") ~= nil
	if not is_vim_api and ft ~= "vim" then
		return false
	end

	for _, tag in ipairs(help_tag_candidates(expr, ft)) do
		if pcall(vim.cmd, "help " .. tag) then
			return true
		end
	end

	if is_vim_api then
		notify("没有找到内置帮助标签: " .. expr, vim.log.levels.WARN)
		return true -- 不回落去开网页
	end
	return false
end

--- 打开 URL / 文件
function M.open_url(url)
	if type(url) ~= "string" or url == "" then
		return
	end

	local scheme = url:match("^([%a][%w+.-]*)://")

	if scheme == "file" then
		local path = vim.uri_to_fname(url)
		if not vim.uv.fs_stat(path) then
			notify("文件不存在: " .. path, vim.log.levels.WARN)
			return
		end
		-- 服务端通常只给到文件、没有行列；m' 让 '' 能跳回原位置
		vim.cmd("normal! m'")
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		notify(("已打开 %s（服务端未提供位置信息，'' 返回）"):format(short_name(path)))
		return
	end

	if scheme ~= "http" and scheme ~= "https" then
		notify(("拒绝打开非 http(s)/file 的链接: %s"):format(url), vim.log.levels.WARN)
		return
	end

	-- vim.ui.open 失败时返回 nil, msg（不抛异常），pcall 只防 handler 自己炸
	local ok, res, msg = pcall(vim.ui.open, url)
	if not ok then
		notify(("打开失败: %s（%s）"):format(url, tostring(res)), vim.log.levels.ERROR)
	elseif res == nil or res == false then
		notify(
			("打开失败: %s（%s）"):format(url, tostring(msg or "没有可用的 opener")),
			vim.log.levels.ERROR
		)
	end
end

--- 打开链接列表（多于 1 条时让用户选）
---@param links { text: string, target: string }[]
---@param fallback fun()|nil 用户取消时的兜底（nil = 什么也不做）
function M.choose_and_open_link(links, fallback)
	if not links or #links == 0 then
		if fallback then
			fallback()
		end
		return
	end
	if #links == 1 then
		M.open_url(links[1].target)
		return
	end

	local items = {}
	for i, link in ipairs(links) do
		items[i] = { index = i, text = link.text or link.target, target = link.target }
	end

	vim.ui.select(items, {
		prompt = "选择要打开的链接:",
		format_item = function(item)
			local display = item.text or ""
			if vim.fn.strdisplaywidth(display) > 60 then
				display = vim.fn.strcharpart(display, 0, 57) .. "..."
			end
			return display
		end,
	}, function(selected)
		if selected and selected.target then
			M.open_url(selected.target)
		elseif fallback then
			fallback()
		end
	end)
end

--- 打开语言默认文档：优先用光标下的词搜，其次语言主页
---@param opts { ft?: string, word?: string }|nil
function M.open_default_docs(opts)
	opts = opts or {}
	local ft = opts.ft or vim.bo.filetype
	local word = opts.word
	if word == nil then
		word = vim.fn.expand("<cword>")
	end

	local template = config.search_urls[ft]
	if template and template:find("%%s") and type(word) == "string" and word ~= "" then
		local ok, url = pcall(string.format, template, vim.uri_encode(word, "rfc3986"))
		if ok then
			M.open_url(url)
			return
		end
	end

	local home = config.home_urls[ft]
	if home then
		M.open_url(home)
		return
	end

	notify(("没有 `%s` 的文档配置（可用 external_docs.setup{} 扩展）"):format(ft), vim.log.levels.WARN)
end

--- 打开当前符号的文档（`gro`）
---@param opts { word?: string }|nil
function M.open_docs(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo.filetype
	local word = opts.word
	if word == nil then
		word = vim.fn.expand("<cword>")
	end
	local strategy = config.strategies[ft] or {}

	-- 0) Neovim 自身 API → `:help`（比任何网页都准确）
	if config.vim_help and M.open_vim_help(bufnr) then
		return
	end

	local function fallback()
		M.open_default_docs({ ft = ft, word = word })
	end

	local function via_hover()
		if strategy.hover == false then
			return fallback()
		end
		local client = pick_client(bufnr, "textDocument/hover")
		if not client then
			return fallback()
		end
		lsp_request.request(client, "textDocument/hover", position_params(client, bufnr), {
			bufnr = bufnr,
			timeout = config.timeout,
		}, function(result)
			local contents = type(result) == "table" and result.contents or nil
			local links = contents and extract_links(hover_text(contents)) or {}
			if #links == 0 then
				return fallback()
			end
			M.choose_and_open_link(links, fallback)
		end)
	end

	-- 1) 服务端原生 externalDocs
	if strategy.external then
		local client = pick_client(bufnr, strategy.external)
		if client then
			lsp_request.request(client, strategy.external, position_params(client, bufnr), {
				bufnr = bufnr,
				timeout = config.timeout,
			}, function(result)
				local url = pick_doc_url(result)
				if url then
					M.open_url(url)
					return
				end
				via_hover()
			end)
			return
		end
	end

	-- 2) hover 抽链接 → 3) 搜索/主页
	via_hover()
end

--- 覆盖默认配置（与 DEFAULTS 深合并）
---@param opts table|nil
function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
end

--- 读取当前生效配置（只读用途）
function M.get_config()
	return config
end

-- 导出内部函数供测试
M._extract_links = extract_links
M._hover_text = hover_text
M._pick_doc_url = pick_doc_url
M._expr_at_cursor = expr_at_cursor
M._help_tag_candidates = help_tag_candidates

return M
