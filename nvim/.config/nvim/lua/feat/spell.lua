-- 拼写检查：只对文本类 buffer 自动开，代码里靠 <leader>zw 手动
--
-- 两个关键点：
--   1. `cjk` 是 vim 内置的 «东亚洲字符不标红» 支持（:h spell-cjk），中文注释能忍全靠它；
--      光设 en_us 时「这是我的 neovim 配置」会整段标红。
--   2. 技术词（neovim / quicksort / DynamoDB）由 vim-dirtytalk 的词表补上，
--      见 lua/plugins/dirtytalk.lua + M.build()（上游的 :DirtytalkUpdate 依赖 Vim 专有的
--      spellfile#WritableSpellDir()，Neovim 里没有这个函数，跑起来是 E117）。

local M = {}

local SPELL_DIR = vim.fn.stdpath("config") .. "/spell"
-- zg 加的词写这里，FocusGained 时 mkspell 生成 .add.spl（同名字典 Vim 会自动叠加）
local ADD_FILE = SPELL_DIR .. "/en.utf-8.add"
local PROGRAMMING = "programming"

-- 自动开 spell 的 filetype：写文档/提交信息才有意义，代码注释里的拼写不值得管
local TEXT_FT = {
	markdown = true,
	gitcommit = true,
	text = true,
	tex = true,
	asciidoc = true,
	rst = true,
	mail = true,
	norg = true,
	help = true,
}

-- dirtytalk 词表里不想要的（不写这些场景的文档）
M.blacklist = { "lorem-ipsum", "nerd-fonts" }

-- 首次建 en.utf-8.add 时的种子词。dirtytalk 只收大小写规范的形式（Neovim），
-- 而日常写的是小写 neovim，所以这些得单独加
local SEED_WORDS = {
	"neovim",
	"nvim",
	"lazyvim",
	"ripgrep",
	"telescope",
	"tokei",
	"tmux",
	"jujutsu",
	"jjlog",
	"nvimtree",
	"codecompanion",
	"yanky",
	"markdown",
	"codebase",
	"codeblock",
	"dotfiles",
	"runtimepath",
	"autocmd",
	"autocmds",
	"filetype",
	"filetypes",
	"keymap",
	"keymaps",
	"lspconfig",
	"treesitter",
	"which-key",
	"buffers",
	"subword",
	"visuals",
	"monorepo",
	"worktree",
	"worktrees",
}

--- spelllang：programming 词典没生成前不要加，否则每个 buffer 报 E756
local function spelllang()
	local base = "en_us,cjk"
	if vim.fn.filereadable(SPELL_DIR .. "/" .. PROGRAMMING .. ".utf-8.spl") == 1 then
		return base .. "," .. PROGRAMMING
	end
	return base
end

--- zg 加了新词 → 重新生成 .add.spl（空词表不跑，mkspell 会拒绝）
function M.refresh_add()
	if vim.fn.filereadable(ADD_FILE) == 0 or vim.fn.getfsize(ADD_FILE) <= 0 then
		return
	end
	local spl = ADD_FILE .. ".spl"
	local add_mtime, spl_mtime = vim.fn.getftime(ADD_FILE), vim.fn.getftime(spl)
	if spl_mtime ~= -1 and add_mtime <= spl_mtime then
		return
	end
	vim.cmd("silent! mkspell! " .. vim.fn.fnameescape(spl) .. " " .. vim.fn.fnameescape(ADD_FILE))
end

--- 由 wordlists/*.words 生成 spell/programming.utf-8.spl（config 目录在 rtp 里，能被 spelllang 找到）
--- @param dir string vim-dirtytalk 的插件目录（build 时由 pack 传入）
function M.build(dir)
	local words = {}
	for _, file in ipairs(vim.fn.glob(dir .. "/wordlists/*.words", false, true)) do
		local name = vim.fn.fnamemodify(file, ":t:r")
		if not vim.tbl_contains(M.blacklist, name) then
			vim.list_extend(words, vim.fn.readfile(file))
		end
	end
	if #words == 0 then
		return vim.notify("dirtytalk 词表为空，跳过 build", vim.log.levels.WARN)
	end
	vim.fn.mkdir(SPELL_DIR, "p")
	local out = SPELL_DIR .. "/" .. PROGRAMMING
	local tmp = vim.fn.tempname()
	vim.fn.writefile(words, tmp)
	local ok, err = pcall(vim.cmd, ("silent mkspell! %s %s"):format(vim.fn.fnameescape(out), vim.fn.fnameescape(tmp)))
	vim.fn.delete(tmp)
	if not ok then
		vim.notify("mkspell 失败: " .. tostring(err), vim.log.levels.ERROR)
	end
end

local group = vim.api.nvim_create_augroup("Spell", { clear = true })

function M.setup()
	vim.opt.spellsuggest = "best,9"
	vim.opt.spelllang = spelllang()
	vim.opt.spellfile = ADD_FILE
	vim.fn.mkdir(SPELL_DIR, "p")
	if vim.fn.filereadable(ADD_FILE) == 0 then
		vim.fn.writefile(SEED_WORDS, ADD_FILE)
		M.refresh_add()
	end

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = vim.tbl_keys(TEXT_FT),
		callback = function()
			vim.wo.spell = true
			vim.w.spell_auto = true -- 记住：这个窗口的 spell 是我们自动开的
			vim.bo.spellfile = ADD_FILE
			vim.bo.spelllang = spelllang()
			-- camel：只在文档里拆驼峰（DynamicConfig → Dynamic + Config），代码里拆了反而更吵
			vim.bo.spelloptions = "camel"
		end,
	})

	-- 同一个窗口切回代码时把自动开的 spell 关掉（spell 是窗口选项，不关就会漏到代码 buffer 里）
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "*",
		callback = function()
			if vim.w.spell_auto and not TEXT_FT[vim.bo.filetype] then
				vim.wo.spell = false
				vim.w.spell_auto = nil
			end
		end,
	})

	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		pattern = "*",
		callback = function()
			M.refresh_add()
		end,
	})

	vim.keymap.set("n", "<leader>zw", function()
		vim.bo.spellfile = ADD_FILE
		vim.bo.spelllang = spelllang()
		vim.wo.spell = not vim.wo.spell
		vim.w.spell_auto = nil -- 手动开的就别自动关
	end, { desc = "拼写检查开关" })
end

return M
