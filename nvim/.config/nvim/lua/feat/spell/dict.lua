-- 拼写词典分层：个人词 + 项目词（可提交，团队共享）
--
-- 为什么不用插件：`'spellfile'` 本身就是**逗号分隔的列表**，Vim 会把列表里所有
-- add 文件叠加加载，而 `zg` 写入的是列表里第一个「可写」的文件（实测：第一项
-- 的目录存在但文件不存在时，Vim 会自动创建）。于是「项目词优先、个人词兜底」
-- 零成本到手：
--
--   <config>/spell/en.utf-8.add        个人长期词（跨项目）
--   <repo>/.nvim-spell/en.utf-8.add    项目词（建议进 git，全组受益）
--
-- 两个容易踩的点：
--   1. add 文件对拼写检查**不直接生效**，必须有同名 .spl（mkspell 产物）。
--      但 `zg` 在同一次会话里是立刻生效的（进内存词表），所以 .spl 只需要在
--      「下次启动前」保持新鲜 —— 重建时机放在 setup / FocusGained / VimLeavePre，
--      三处都过 mtime 检查，通常只是两次 stat。
--   2. 项目词表里存的必须是 camel 拆开后的**小写子词**（见 words.lua）：
--      `spelloptions=camel` 会把 DynamicConfig 拆成 Dynamic+Config 分别查，
--      词典里塞 "DynamicConfig" 是不起作用的。

local M = {}

local SPELL_DIR = vim.fn.stdpath("config") .. "/spell"
M.GLOBAL = SPELL_DIR .. "/en.utf-8.add"
-- 项目词表目录：放仓库根下，和 .git 同级，方便提交
M.PROJECT_DIR = ".nvim-spell"
M.ADD_FILE = "en.utf-8.add"

-- 认项目根用的标记；只用最通用的几个，避免 monorepo 里认到奇怪的地方
local ROOT_MARKERS = { ".git", "package.json", "Cargo.toml", "pyproject.toml", "go.mod" }

---@type table<string, string|false>
local root_cache = {}

--- 当前 buffer 所属项目根（结果按目录缓存，含「没有」这个结论）
---@param buf? integer
---@return string|nil
function M.root(buf)
	local name = vim.api.nvim_buf_get_name(buf or 0)
	local dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
	if not dir or dir == "" then
		return nil
	end
	local cached = root_cache[dir]
	if cached ~= nil then
		return cached or nil
	end
	local ok, root = pcall(vim.fs.root, dir, ROOT_MARKERS)
	root = ok and root or nil
	root_cache[dir] = root or false
	return root
end

--- 项目词表路径（不一定存在，`zg` 时才创建）
---@param buf? integer
---@return string|nil
function M.project_file(buf)
	local root = M.root(buf)
	if not root then
		return nil
	end
	return root .. "/" .. M.PROJECT_DIR .. "/" .. M.ADD_FILE
end

--- 'spellfile' 用的文件列表：项目（可写在前）→ 个人
---@param buf? integer
---@return string[] files
---@return string joined
function M.files(buf)
	local files = {}
	local proj = M.project_file(buf)
	if proj then
		files[#files + 1] = proj
	end
	files[#files + 1] = M.GLOBAL
	return files, table.concat(files, ",")
end

--- 读一个 add 文件的词（小写化后的集合）
---@param file string
---@return table<string, true>
function M.words(file)
	local set = {}
	if vim.fn.filereadable(file) == 0 then
		return set
	end
	for _, line in ipairs(vim.fn.readfile(file)) do
		local w = vim.trim(line)
		if w ~= "" then
			set[w:lower()] = true
		end
	end
	return set
end

--- 项目词 + 个人词的合集（判断「这词我已经收过了吗」）
---@param buf? integer
---@return table<string, true>
function M.known(buf)
	local set = M.words(M.GLOBAL)
	local proj = M.project_file(buf)
	if proj then
		for w in pairs(M.words(proj)) do
			set[w] = true
		end
	end
	return set
end

--- 往 add 文件里加词（去重；文件按字母序维护，diff 好看、合并冲突少）
---@param word string
---@param scope "project"|"global"
---@param buf? integer
---@return boolean ok
---@return string file
function M.add(word, scope, buf)
	word = vim.trim(word or "")
	if word == "" then
		return false, ""
	end
	local file = M.GLOBAL
	if scope == "project" then
		file = M.project_file(buf or 0) or M.GLOBAL
	end
	vim.fn.mkdir(vim.fs.dirname(file), "p")

	local lines = vim.fn.filereadable(file) == 1 and vim.fn.readfile(file) or {}
	local seen = {}
	for _, line in ipairs(lines) do
		seen[vim.trim(line):lower()] = true
	end
	if not seen[word:lower()] then
		lines[#lines + 1] = word
		table.sort(lines, function(a, b)
			return a:lower() < b:lower()
		end)
		local ok, err = pcall(vim.fn.writefile, lines, file)
		if not ok then
			vim.notify("写词典失败: " .. tostring(err), vim.log.levels.ERROR)
			return false, file
		end
	end
	-- 立刻在当前会话生效（add 文件本身不会立刻被读，spellgood 是内存词表）
	pcall(vim.cmd, "silent! spellgood " .. vim.fn.fnameescape(word))
	return true, file
end

--- 删词（:SpellWords 里用）
---@param word string
---@param file string
---@return boolean
function M.remove(word, file)
	if vim.fn.filereadable(file) == 0 then
		return false
	end
	local kept = {}
	for _, line in ipairs(vim.fn.readfile(file)) do
		if vim.trim(line):lower() ~= word:lower() then
			kept[#kept + 1] = line
		end
	end
	local ok = pcall(vim.fn.writefile, kept, file)
	if ok then
		pcall(vim.cmd, "silent! spellwrong " .. vim.fn.fnameescape(word))
		M.sync(file, true)
	end
	return ok
end

--- add 文件 → .spl（过 mtime 检查；force 时强制重建）
--- mkspell 是同步命令，但 add 文件通常只有几百行（<10ms），不值得为它上异步。
---@param file string
---@param force? boolean
---@return boolean rebuilt
function M.sync(file, force)
	if vim.fn.filereadable(file) == 0 or vim.fn.getfsize(file) <= 0 then
		return false
	end
	local spl = file .. ".spl"
	if not force then
		local add_mtime, spl_mtime = vim.fn.getftime(file), vim.fn.getftime(spl)
		if spl_mtime ~= -1 and add_mtime <= spl_mtime then
			return false
		end
	end
	local ok, err = pcall(vim.cmd, ("silent! mkspell! %s %s"):format(vim.fn.fnameescape(spl), vim.fn.fnameescape(file)))
	if not ok then
		vim.notify("mkspell 失败: " .. tostring(err), vim.log.levels.WARN)
		return false
	end
	return true
end

--- 所有已知 add 文件（个人 + 缓存里出现过的项目词表）都同步一遍
function M.sync_all()
	M.sync(M.GLOBAL)
	for _, root in pairs(root_cache) do
		if root then
			M.sync(root .. "/" .. M.PROJECT_DIR .. "/" .. M.ADD_FILE)
		end
	end
end

--- 把词典路径挂到 buffer 上（spelllang 由 init 统一管）
---@param buf integer
function M.attach(buf)
	local _, joined = M.files(buf)
	vim.bo[buf].spellfile = joined
end

return M
