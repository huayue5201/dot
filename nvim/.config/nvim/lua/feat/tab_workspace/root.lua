-- 「当前文件属于哪个项目」的判定，以及按文件自动切 tab 根目录。
--
-- 根解析顺序（就近者胜，绝不用 :cd，只动当前 tab 的 :tcd）：
--   1. 从文件所在目录向上找 marker（.git / .emmyrc.json / pyproject.toml ...），
--      最近命中的那个目录就是根。近者胜天然把 monorepo、dotfiles 压到子项目。
--   2. 文件路径走不通（软链把 marker 挡在视野外）时，用 realpath 再找一遍。
--   3. 都没有时退到已 attach 的 LSP client 的 root_dir（取最深的一个）。
--
-- 触发条件只有一条：当前文件不在本 tab 的根内。已在根内就完全不动，
-- 所以你平时的操作没有任何额外开销，也不会误改 cwd。
-- 手动设置的根（<leader>lws / 新建工作区 / <leader>lwr 回退）记为 pin，pin 优先，
-- 自动逻辑不再覆盖它；<leader>lwR 解除 pin 后恢复自动跟随。

local util = require("feat.tab_workspace.util")

local M = {}

-- 判定项目根的标记文件。顺序不重要，命中深度才重要：
-- 一个目录里只要有任意一个，就算根。
M.markers = {
	".git",
	".hg",
	".emmyrc.json",
	".luarc.json",
	"stylua.toml",
	"selene.toml",
	".env.lua",
	"nvim-pack-lock.json",
	"pyproject.toml",
	"setup.py",
	"setup.cfg",
	"requirements.txt",
	"Cargo.toml",
	"go.mod",
	"package.json",
	"deno.json",
	"tsconfig.json",
	"Makefile",
	"CMakeLists.txt",
	"flake.nix",
	"compose.yaml",
	"docker-compose.yml",
	"Justfile",
}

-- 这些目录里（或它下面）的 marker 不算数：防止把 node_modules 里的包当成项目根
local SKIP_SEGMENTS = {
	["node_modules"] = true,
	[".venv"] = true,
	["venv"] = true,
	["target"] = true,
	["dist"] = true,
	["build"] = true,
	[".git"] = true,
	[".cache"] = true,
}

M.enabled = true

-- tab -> 手动锁定的根（显式设置的根永远赢过自动判定）
local pinned = {}
-- tab -> 自动切换前的根（<leader>lwr 用）
local prev = {}

---@param dir string
---@return string
local function real(dir)
	local ok, res = pcall(vim.uv.fs_realpath, dir)
	return (ok and res) or dir
end

---@param path string
---@param dir string
---@return boolean
local function is_under(path, dir)
	local f, d = real(path), real(dir)
	if f == d then
		return true
	end
	if d:sub(-1) ~= "/" then
		d = d .. "/"
	end
	return f:sub(1, #d) == d
end

---@param dir string
---@return boolean
local function in_skip_dir(dir)
	for seg in dir:gmatch("[^/]+") do
		if SKIP_SEGMENTS[seg] then
			return true
		end
	end
	return false
end

--- 从 dir 向上找最近一个含 marker 的目录
---@param dir string
---@return string|nil
local function nearest(dir)
	local seen = {}
	while dir and dir ~= "" and not seen[dir] do
		seen[dir] = true
		if not in_skip_dir(dir) then
			for _, marker in ipairs(M.markers) do
				if vim.uv.fs_stat(dir .. "/" .. marker) then
					return dir
				end
			end
		end
		local parent = vim.fs.dirname(dir)
		if not parent or parent == dir then
			break
		end
		dir = parent
	end
end

--- buffer 对应的真实文件路径（特殊 buffer / 终端 / 目录 buffer 返回 nil）
---@param bufnr integer
---@return string|nil
local function buf_path(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end
	local bo = vim.bo[bufnr]
	if bo.buftype ~= "" then
		return nil
	end
	local name = vim.api.nvim_buf_get_name(bufnr)
	-- term://、fugitive://、oil:// 之类不是文件
	if name == "" or name:find("^%a[%w+.-]*://") then
		return nil
	end
	return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

--- 已 attach 的 LSP client 的根里，属于该文件祖先目录中最深的一个
---@param path string
---@param bufnr integer
---@return string|nil
local function lsp_root(path, bufnr)
	local best
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local dir = client.config and client.config.root_dir
		-- 只认真正的祖先目录：client 可能来自别的项目（多 client、空 root_dir）
		if dir and dir ~= "" and is_under(path, dir) and (not best or #dir > #best) then
			best = dir
		end
	end
	return best
end

--- 判定这个 buffer 的项目根
---@param bufnr? integer
---@return string|nil
function M.resolve(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local path = buf_path(bufnr)
	if not path then
		return nil
	end
	local dir = vim.fs.dirname(path)
	return nearest(dir) or nearest(real(dir)) or lsp_root(path, bufnr)
end

--- tab 当前的工作目录（:tcd 的值）
---@param tab? integer
---@return string
function M.cwd(tab)
	tab = tab or vim.api.nvim_get_current_tabpage()
	local ok, dir = pcall(vim.fn.getcwd, -1, vim.api.nvim_tabpage_get_number(tab))
	if ok and dir ~= "" then
		return dir
	end
	return vim.fn.getcwd()
end

--- 工作区展示名：根目录末段；家目录 / 文件系统根用 ~ 与 /（末段没有信息量）
---@param tab? integer
---@return string
function M.name(tab)
	tab = tab or vim.api.nvim_get_current_tabpage()
	local pretty = vim.fn.fnamemodify(M.cwd(tab), ":~"):gsub("/+$", "")
	if pretty == "~" or pretty == "" then
		return pretty == "" and "/" or "~"
	end
	local short = vim.fn.fnamemodify(pretty, ":t")
	if short == "" or short == "." or short == "/" then
		return pretty
	end
	return short
end

---@param tab integer
---@return string|nil
function M.pin_of(tab)
	return pinned[tab]
end

--- 记录手动根（不放行自动切换）
---@param tab integer
---@param dir string
function M.set_pin(tab, dir)
	pinned[tab] = dir
	prev[tab] = nil
	vim.api.nvim_exec_autocmds("User", { pattern = "TabWorkspaceRoot" })
end

--- 清空 pin / 回退点（测试与重置用）
function M.reset()
	pinned = {}
	prev = {}
end

--- 丢掉已关闭 tab 的 pin / 回退点（tab handle 可能被复用，别让新 tab 继承旧根）
function M.prune()
	local valid = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		valid[tab] = true
	end
	for tab in pairs(pinned) do
		if not valid[tab] then
			pinned[tab] = nil
		end
	end
	for tab in pairs(prev) do
		if not valid[tab] then
			prev[tab] = nil
		end
	end
end

--- 解除 pin，回到自动跟随
---@param tab? integer
---@return boolean
function M.unpin(tab)
	tab = tab or vim.api.nvim_get_current_tabpage()
	if not pinned[tab] then
		vim.notify("this tab has no pinned root", vim.log.levels.INFO)
		return false
	end
	pinned[tab] = nil
	vim.api.nvim_exec_autocmds("User", { pattern = "TabWorkspaceRoot" })
	vim.notify("root unpinned, back to auto-follow", vim.log.levels.INFO)
	M.maybe_follow()
	return true
end

--- 回到自动切换前的根（回退后锁定它，免得下一次 BufEnter 又立刻切回去）
---@param tab? integer
---@return boolean
function M.back(tab)
	tab = tab or vim.api.nvim_get_current_tabpage()
	local target = prev[tab]
	if not target then
		vim.notify("no previous root to go back to", vim.log.levels.INFO)
		return false
	end
	if vim.fn.isdirectory(target) == 0 then
		vim.notify(string.format("previous root no longer exists: %s", target), vim.log.levels.WARN)
		prev[tab] = nil
		return false
	end
	local ok = pcall(vim.cmd.tcd, { args = { target } })
	if not ok then
		return false
	end
	prev[tab] = nil
	M.set_pin(tab, target)
	vim.notify(string.format("workspace root ← %s (pinned)", target), vim.log.levels.INFO)
	return true
end

--- 切换 tab 根目录并记下回退点
---@param tab integer
---@param dir string
---@return boolean
function M.switch(tab, dir)
	local current = M.cwd(tab)
	if real(dir) == real(current) then
		return false
	end
	local ok = pcall(vim.cmd.tcd, { args = { dir } })
	if not ok then
		return false
	end
	prev[tab] = current
	vim.notify(string.format("workspace root → %s", dir), vim.log.levels.INFO)
	return true
end

--- BufEnter 钩子：文件不在本 tab 根内时，把根切到它的项目根
---@param bufnr? integer
function M.maybe_follow(bufnr)
	if not M.enabled or util.resession_loading() then
		return
	end
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	if util.is_ephemeral_win(win) or vim.api.nvim_win_get_buf(win) ~= bufnr then
		return
	end
	local path = buf_path(bufnr)
	if not path then
		return
	end
	local tab = vim.api.nvim_get_current_tabpage()
	local current = M.cwd(tab)
	-- 绝大多数时候走这一条：文件就在当前根里，什么都不做
	if is_under(path, current) then
		return
	end
	if pinned[tab] then
		return
	end
	local root = M.resolve(bufnr)
	if not root or not is_under(path, root) then
		return
	end
	M.switch(tab, root)
end

---@param opts? { enabled?: boolean, markers?: string[] }
function M.setup(opts)
	opts = opts or {}
	if opts.enabled ~= nil then
		M.enabled = opts.enabled
	end
	if opts.markers then
		M.markers = opts.markers
	end
end

return M
