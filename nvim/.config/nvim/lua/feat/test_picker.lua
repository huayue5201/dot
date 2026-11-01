-- lua/feat/test_picker.lua
--[[
测试方法模糊查找（大项目用）
==============================
neotest 上游没有「跨整个项目模糊定位测试」的入口（summary 只列已发现的文件，
`/` 也是在树里搜），这里用 ripgrep 把所有测试声明扫成一张扁平清单，
再交给通用 picker（matchfuzzy 模糊过滤 + 源码预览）。

    require("feat.test_picker").pick()          -- <leader>tS
    require("feat.test_picker").pick({ run = true })  -- 选中后直接跑

<CR> 跳到测试定义；<C-r> 跳过去并运行最近测试（neotest.run.run()）；
<C-d> 跳过去并调试。数据源是静态扫描，所以没跑过 discovery 的文件也能找到。
]]
local M = {}

------------------------------------------------------------------
-- 各语言的「测试声明」扫描规则
-- pattern 走 ripgrep 正则；extract 从命中文本里取 (名字, 名字起始字节位置)
------------------------------------------------------------------
local SPECS = {
	{
		ext = "rs",
		glob = "*.rs",
		-- #[test] / #[tokio::test] / #[rstest]，允许属性后面再跟几行属性（如 #[case(...)]）
		pattern = [[#\[[^\]\n]*test[^\]\n]*\](?:\s*\n\s*#\[[^\]\n]*\])*\s*\n\s*(?:pub(?:\([^)\n]*\))?\s+)?(?:async\s+)?fn\s+\w+]],
		extract = function(t)
			local s, _, name = t:find("fn%s+([%w_]+)")
			return name, s
		end,
	},
	{
		ext = "go",
		glob = "*.go",
		pattern = [[^\s*func\s+(?:\([^)\n]*\)\s*)?(?:Test|Benchmark|Fuzz|Example)\w*]],
		extract = function(t)
			-- 包级测试函数 或 方法形式 func (s *Suite) TestX
			local name = t:match("func%s+%b()%s*([%w_]+)") or t:match("func%s+([%w_]+)")
			if not name then
				return nil
			end
			return name, (t:find(name, 1, true))
		end,
	},
	{
		ext = "lua",
		glob = "*.lua",
		pattern = [[^[ \t]*(?:it|describe|test|pending)[ \t]*\(]],
		extract = function(_, line)
			local name = line:match("[\"'](.-)[\"']")
			if not name or name == "" then
				return nil
			end
			return name, (line:find(name, 1, true))
		end,
	},
}

---按文件后缀索引（同一后缀可有多条规则）
local BY_EXT = {}
for _, spec in ipairs(SPECS) do
	BY_EXT[spec.ext] = BY_EXT[spec.ext] or {}
	table.insert(BY_EXT[spec.ext], spec)
end

local function scan()
	if vim.fn.executable("rg") ~= 1 then
		vim.notify("test_picker: 需要 ripgrep (rg)", vim.log.levels.ERROR)
		return {}
	end

	local cwd = vim.fn.getcwd()
	local args = { "rg", "--json", "--no-messages", "-n", "-U" }
	for _, spec in ipairs(SPECS) do
		vim.list_extend(args, { "-e", spec.pattern, "-g", spec.glob })
	end

	local ok, res = pcall(function()
		return vim.system(args, { cwd = cwd, text = true }):wait(10000)
	end)
	if not ok or not res or (res.code or 0) > 2 then
		vim.notify("test_picker: ripgrep 失败: " .. tostring(ok and res and res.stderr or res), vim.log.levels.ERROR)
		return {}
	end

	local items, seen = {}, {}
	for line in (res.stdout or ""):gmatch("[^\n]+") do
		local ok_json, ev = pcall(vim.json.decode, line)
		if ok_json and ev.type == "match" then
			local path = ev.data.path.text
			local specs = BY_EXT[(path:match("%.([%w]+)$") or ""):lower()]
			local text = ev.data.lines and ev.data.lines.text
			if specs and text then
				-- 一条 match 事件可带多个命中（多行模式会把相邻行并成一段）
				for _, sub in ipairs(ev.data.submatches or {}) do
					-- 命中片段 + 该行剩余部分（lua 的测试名在行尾的引号里）
					local seg = text:sub(sub.start + 1, sub["end"])
					local rest = text:sub(sub.start + 1, (text:find("\n", sub.start + 1, true) or #text + 1) - 1)
					for _, spec in ipairs(specs) do
						local name, npos = spec.extract(seg, rest)
						if name then
							-- 换算成文件里的绝对行号：起始行 + 名字之前换行数
							local before = text:sub(1, sub.start + (npos or 1) - 1)
							local _, nl = before:gsub("\n", "")
							local line_no = (ev.data.line_number or 1) + nl
							local key = path .. ":" .. line_no
							if not seen[key] then
								seen[key] = true
								items[#items + 1] = {
									path = path,
									abs = vim.fs.normalize(cwd .. "/" .. path),
									line = line_no,
									name = name,
								}
							end
							break
						end
					end
				end
			end
		end
	end
	return items
end

---读取文件行（优先用已加载的 buffer，含未保存修改）
---@param item table
---@param from integer
---@param to integer
local function file_lines(item, from, to)
	if vim.fn.bufexists(item.abs) == 1 then
		local buf = vim.fn.bufnr(item.abs)
		if vim.api.nvim_buf_is_loaded(buf) then
			return vim.api.nvim_buf_get_lines(buf, from - 1, to, false)
		end
	end
	local ok, lines = pcall(vim.fn.readfile, item.abs, "", to)
	if not ok then
		return {}
	end
	return vim.list_slice(lines, from, to)
end

local function jump(item)
	vim.cmd("edit " .. vim.fn.fnameescape(item.abs))
	pcall(vim.api.nvim_win_set_cursor, 0, { item.line, 0 })
	vim.cmd("normal! zvzz")
end

---扫描全项目测试声明（供调试 / 外部复用）
function M.scan()
	return scan()
end

---@param opts? { run?: boolean, debug?: boolean }
function M.pick(opts)
	opts = opts or {}
	local items = scan()
	if #items == 0 then
		vim.notify("test_picker: 没扫到测试（检查 rg 规则 / 是否在项目根目录）", vim.log.levels.WARN)
		return
	end

	local function run_after(item, mode)
		jump(item)
		local neotest = require("neotest")
		if mode == "debug" then
			neotest.run.run({ strategy = "dap" })
		else
			neotest.run.run()
		end
	end

	require("ui.picker").pick({
		title = ("tests %d"):format(#items),
		items = items,
		text = function(it)
			return ("%s  ›  %s"):format(it.path, it.name)
		end,
		filetype = function(it)
			return ({ rs = "rust", go = "go", lua = "lua" })[(it.path:match("%.([%w]+)$") or ""):lower()] or ""
		end,
		preview = function(it)
			local from = math.max(1, it.line - 4)
			local to = it.line + 14
			local lines = file_lines(it, from, to)
			local out = {}
			for i, l in ipairs(lines) do
				local no = from + i - 1
				out[i] = ("%s%4d │ %s"):format(no == it.line and "▶" or " ", no, l)
			end
			return out
		end,
		actions = {
			{
				key = "<C-r>",
				desc = "运行",
				fn = function(it)
					run_after(it, "run")
				end,
			},
			{
				key = "<C-d>",
				desc = "调试",
				fn = function(it)
					run_after(it, "debug")
				end,
			},
		},
		on_choose = function(it)
			jump(it)
			if opts.run then
				require("neotest").run.run()
			end
		end,
	})
end

return M
