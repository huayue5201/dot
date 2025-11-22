-- ============================
--  Project Root Detector
-- ============================

local function detect_root()
	-- 1. Try git
	local git_root = vim.fn.systemlist("git -C " .. vim.fn.expand("%:p:h") .. " rev-parse --show-toplevel")[1]

	if git_root and git_root ~= "" then
		return git_root
	end

	-- 2. Try common project markers
	local markers = {
		".git",
		".hg",
		".svn",
		"package.json",
		"pyproject.toml",
		"setup.py",
		"Cargo.toml",
		"go.mod",
		"Makefile",
	}

	local path = vim.fn.expand("%:p:h")
	local prev = ""

	while path ~= prev do
		for _, m in ipairs(markers) do
			if vim.fn.glob(path .. "/" .. m) ~= "" then
				return path
			end
		end
		prev = path
		path = vim.fn.fnamemodify(path, ":h")
	end

	-- 3. fallback
	return vim.fn.getcwd()
end

local root = detect_root()

-- Unique project ID
local unique_id = vim.fn.sha256(root):sub(1, 12)
local data = vim.fn.stdpath("data")

-- ensure dirs
local function ensure(path)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
end

ensure(data .. "/shada")
ensure(data .. "/undo")
ensure(data .. "/session")

-- ============================
--  Per-Project shada
-- ============================

local shada = data .. "/shada/" .. unique_id .. ".shada"
vim.opt.shadafile = shada

-- ============================
--  Per-Project undo
-- ============================

local undo_dir = data .. "/undo/" .. unique_id
ensure(undo_dir)

vim.opt.undofile = true
vim.opt.undodir = undo_dir

-- ============================
--  Per-Project session
-- ============================

local session_file = data .. "/session/" .. unique_id .. ".vim"
vim.g.project_session_file = session_file

vim.o.sessionoptions = table.concat({
	"blank",
	"buffers",
	"curdir",
	"folds",
	"help",
	"globals",
	"tabpages",
	"winsize",
	"winpos",
	"terminal",
	"localoptions",
}, ",")

-- command :SaveSession  and :LoadSession

vim.api.nvim_create_user_command("SaveSession", function()
	vim.cmd("mksession! " .. session_file)
	print("Session saved to: " .. session_file)
end, {})

vim.api.nvim_create_user_command("LoadSession", function()
	if vim.fn.filereadable(session_file) == 1 then
		vim.cmd("source " .. session_file)
		print("Session loaded from: " .. session_file)
	else
		print("No session file found: " .. session_file)
	end
end, {})

-- ============================
--  Export root if you need it
-- ============================

return {
	root = root,
	unique_id = unique_id,
	shada = shada,
	undo = undo_dir,
	session = session_file,
}
