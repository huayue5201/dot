-- 拼写检查：词典分层 / 文本 buffer 原生高亮 / 代码注释诊断 / 建议 picker
--
-- 分层（见各子模块顶部的「为什么」）：
--   dict.lua    词典：个人词 + 项目词（.nvim-spell/，可提交），add→spl 同步
--   diag.lua    找错：treesitter 的 @spell/@nospell 区间 → vim.spell.check → diagnostics
--   suggest.lua 建议：z= 换成 picker（上下文/预览/全部替换/撤回），建议永远懒算
--   words.lua   项目技术词候选（从代码里统计高频子词，收进词典）
--
-- 两个关键点：
--   1. `cjk` 是 vim 内置的 «东亚洲字符不标红» 支持（:h spell-cjk），中文注释能忍全靠它；
--      光设 en_us 时「这是我的 neovim 配置」会整段标红。
--   2. 技术词（neovim / quicksort / DynamoDB）由 vim-dirtytalk 的词表补上，
--      见 lua/plugins/lang/dirtytalk.lua + M.build()（上游的 :DirtytalkUpdate 依赖 Vim 专有的
--      spellfile#WritableSpellDir()，Neovim 里没有这个函数，跑起来是 E117）。
--
-- 性能取舍（实测）：`vim.spell.check()` 约 0.3ms/行，可以随时跑；
-- `spellsuggest()` 约 30ms/次，只能按需算 —— 所以「找错」和「给建议」是两套路径。
-- 当年 spellwand.nvim 卡 2s 就是因为它把两者绑在了每个错词上。

local M = {}

local dict = require("feat.spell.dict")
local diag = require("feat.spell.diag")
local suggest = require("feat.spell.suggest")
local words = require("feat.spell.words")
local picker = require("ui.picker")

local SPELL_DIR = vim.fn.stdpath("config") .. "/spell"
local PROGRAMMING = "programming"
-- 超过这个行数不自动开原生高亮（整屏重绘时要按行检查）。
-- 不用字节数：中文一字 3 字节，按字节卡会把中文文档误伤成 5 万字就关。
local AUTO_MAX_LINES = 20000

-- 自动开 spell 的 filetype：写文档/提交信息才有意义
local TEXT_FT = {
	markdown = true,
	gitcommit = true,
	text = true,
	tex = true,
	asciidoc = true,
	rst = true,
	mail = true,
	norg = true,
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

---@param ft string
---@return boolean
function M.is_text(ft)
	return TEXT_FT[ft] == true
end

--- spelllang：programming 词典没生成前不要加，否则每个 buffer 报 E756
---@return string
function M.spelllang()
	local base = "en_us,cjk"
	if vim.fn.filereadable(SPELL_DIR .. "/" .. PROGRAMMING .. ".utf-8.spl") == 1 then
		return base .. "," .. PROGRAMMING
	end
	return base
end

--- 由 wordlists/*.words 生成 spell/programming.utf-8.spl（config 目录在 rtp 里，能被 spelllang 找到）
--- @param dir string vim-dirtytalk 的插件目录（build 时由 pack 传入）
function M.build(dir)
	local list = {}
	for _, file in ipairs(vim.fn.glob(dir .. "/wordlists/*.words", false, true)) do
		local name = vim.fn.fnamemodify(file, ":t:r")
		if not vim.tbl_contains(M.blacklist, name) then
			vim.list_extend(list, vim.fn.readfile(file))
		end
	end
	if #list == 0 then
		return vim.notify("dirtytalk 词表为空，跳过 build", vim.log.levels.WARN)
	end
	vim.fn.mkdir(SPELL_DIR, "p")
	local out = SPELL_DIR .. "/" .. PROGRAMMING
	local tmp = vim.fn.tempname()
	vim.fn.writefile(list, tmp)
	local ok, err = pcall(vim.cmd, ("silent mkspell! %s %s"):format(vim.fn.fnameescape(out), vim.fn.fnameescape(tmp)))
	vim.fn.delete(tmp)
	if not ok then
		vim.notify("mkspell 失败: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- 手动开关（<leader>zw）。手动开的不会被切到代码 buffer 时自动关掉
function M.toggle()
	local buf = vim.api.nvim_get_current_buf()
	dict.attach(buf)
	vim.bo[buf].spelllang = M.spelllang()
	vim.wo.spell = not vim.wo.spell
	vim.w.spell_auto = vim.wo.spell
	if vim.wo.spell then
		diag.update(buf)
	else
		diag.schedule(buf, 0)
	end
	vim.notify("拼写检查: " .. (vim.wo.spell and "开" or "关"), vim.log.levels.INFO)
end

--- 收词前先确认它确实「不合法」——`<leader>za`/`zG` 取的是光标下的词，
--- 在 `this` 上按下去就把 this 收进词表了（还写进了可提交的项目词表）
--- @param word string
--- @param scope "project"|"global"
--- @param buf integer
--- @return boolean added
local function add_word(word, scope, buf)
	if not word or word == "" then
		return false
	end
	local ok, res = pcall(vim.spell.check, word)
	if ok and (#res == 0 or (res[1][2] ~= "bad" and res[1][2] ~= "rare")) then
		vim.notify(("%s 已经是合法单词"):format(word), vim.log.levels.INFO)
		return false
	end
	local added, file = dict.add(word, scope, buf)
	if added then
		vim.notify(("%s → %s"):format(word, file), vim.log.levels.INFO)
		diag.update(buf)
	end
	return added
end

----------------------------------------------------------------------
-- :SpellAll —— 全 buffer 错词列表（原生只能 ]s 一个个跳）
----------------------------------------------------------------------

---@param buf integer
---@param hit feat.spell.hit
local function jump_to(buf, hit)
	if vim.api.nvim_get_current_buf() ~= buf then
		vim.api.nvim_set_current_buf(buf)
	end
	vim.api.nvim_win_set_cursor(0, { hit.lnum, hit.col })
end

function M.all()
	local buf = vim.api.nvim_get_current_buf()
	local hits = diag.scan(buf)
	if #hits == 0 then
		vim.notify("这个 buffer 没有拼写问题", vim.log.levels.INFO)
		return
	end

	-- 按词聚合：同一个错词改一次能修全部，所以列表按「词」而不是按「出现处」
	local order, by_word = {}, {}
	for _, h in ipairs(hits) do
		local key = h.word:lower()
		local item = by_word[key]
		if not item then
			item = { word = h.word, count = 0, first = h }
			by_word[key] = item
			order[#order + 1] = item
		end
		item.count = item.count + 1
	end

	picker.pick({
		title = ("拼写问题 %d 处 / %d 词"):format(#hits, #order),
		items = order,
		text = function(it)
			return ("%3d× %s"):format(it.count, it.word)
		end,
		actions = {
			{
				key = "<C-r>",
				desc = "全部替换(用首个建议)",
				fn = function(it, ctx)
					ctx.close()
					local ok, sugs = pcall(vim.fn.spellsuggest, it.word, 12)
					if not ok or #sugs == 0 then
						vim.notify(("没有 %s 的建议"):format(it.word), vim.log.levels.INFO)
						return
					end
					local n = suggest.replace_all(buf, it.word, sugs[1])
					vim.notify(("替换 %d 处: %s → %s"):format(n, it.word, sugs[1]), vim.log.levels.INFO)
				end,
			},
			{
				key = "<C-q>",
				desc = "送进 quickfix",
				fn = function(_, ctx)
					ctx.close()
					local items = {}
					for _, h in ipairs(hits) do
						items[#items + 1] = {
							bufnr = buf,
							lnum = h.lnum,
							col = h.col + 1,
							text = h.word,
						}
					end
					vim.fn.setqflist({}, "r", { title = "Spell: " .. #items .. " 处", items = items })
					vim.cmd("copen")
				end,
			},
			{
				key = "a",
				desc = "收进项目词典",
				fn = function(it, ctx)
					ctx.close()
					add_word(it.word, "project", buf)
				end,
			},
			{
				key = "A",
				desc = "收进个人词典",
				fn = function(it, ctx)
					ctx.close()
					add_word(it.word, "global", buf)
				end,
			},
			{
				key = "i",
				desc = "本次忽略",
				fn = function(it, ctx)
					ctx.close()
					pcall(vim.cmd, "silent! spellgood " .. vim.fn.fnameescape(it.word))
					diag.update(buf)
				end,
			},
		},
		on_choose = function(it)
			jump_to(buf, it.first)
			-- 跳到第一个出现处再开建议 picker，一次把「看上下文 + 选词」走完
			vim.schedule(function()
				suggest.pick()
			end)
		end,
	})
end

----------------------------------------------------------------------
-- :SpellWords —— 看看自己收过哪些词（add 文件只增不减是要出事的）
----------------------------------------------------------------------

function M.list()
	local buf = vim.api.nvim_get_current_buf()
	local items = {}
	local function collect(file, scope)
		if not file or vim.fn.filereadable(file) == 0 then
			return
		end
		for _, line in ipairs(vim.fn.readfile(file)) do
			local w = vim.trim(line)
			if w ~= "" then
				items[#items + 1] = {
					word = w,
					scope = scope,
					file = file,
					path = vim.fn.fnamemodify(file, ":~:."),
				}
			end
		end
	end
	collect(dict.project_file(buf), "project")
	collect(dict.GLOBAL, "global")
	if #items == 0 then
		vim.notify("还没有任何自定义词", vim.log.levels.INFO)
		return
	end
	table.sort(items, function(a, b)
		return a.word:lower() < b.word:lower()
	end)

	picker.pick({
		title = "拼写词典",
		items = items,
		text = function(it)
			return ("%-24s %s"):format(it.word, it.scope == "project" and "[项目]" or "[个人]")
		end,
		actions = {
			{
				key = "<C-d>",
				desc = "删除该词",
				fn = function(it, ctx)
					local ok = dict.remove(it.word, it.file)
					ctx.close()
					if ok then
						vim.notify(("已删除 %s"):format(it.word), vim.log.levels.INFO)
						diag.update(buf)
					end
				end,
			},
		},
		on_choose = function(it)
			vim.cmd("edit " .. vim.fn.fnameescape(it.file))
			vim.fn.search("^" .. vim.fn.escape(it.word, "\\/.*$^~[]") .. "$", "w")
		end,
	})
end

----------------------------------------------------------------------
-- setup
----------------------------------------------------------------------

local group = vim.api.nvim_create_augroup("Spell", { clear = true })

function M.setup()
	vim.opt.spellsuggest = "best,9"
	vim.opt.spelllang = M.spelllang()
	vim.opt.spellfile = dict.GLOBAL
	vim.fn.mkdir(SPELL_DIR, "p")
	if vim.fn.filereadable(dict.GLOBAL) == 0 then
		vim.fn.writefile(SEED_WORDS, dict.GLOBAL)
	end
	-- 启动时补上「上次退出前没来得及重建」的 .add.spl：
	-- zg 在当前会话里是立刻生效的（进内存词表），只在重启后才依赖 .spl，
	-- 所以重建时机可以散在 setup / FocusGained / VimLeavePre，都过 mtime 检查。
	dict.sync_all()

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = vim.tbl_keys(TEXT_FT),
		callback = function()
			dict.attach(0)
			vim.bo.spelllang = M.spelllang()
			-- camel：只在文档里拆驼峰（DynamicConfig → Dynamic + Config），代码里拆了反而更吵
			vim.bo.spelloptions = "camel"
			-- 大文件不自动开：原生高亮是整屏重绘时按行检查的
			if vim.api.nvim_buf_line_count(0) <= AUTO_MAX_LINES then
				vim.wo.spell = true
				vim.w.spell_auto = true
			end
			diag.update(0)
		end,
	})

	-- 切到代码 buffer：关掉（自动开的）原生高亮，改成注释区的 diagnostics
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "*",
		callback = function()
			local buf = vim.api.nvim_get_current_buf()
			if vim.bo[buf].buftype ~= "" then
				return
			end
			if vim.w.spell_auto and not TEXT_FT[vim.bo[buf].filetype] then
				vim.wo.spell = false
				vim.w.spell_auto = nil
			end
			-- 代码 buffer 也挂上词典：这样 z= / :SpellAll 里也能用项目词
			dict.attach(buf)
			vim.bo[buf].spelllang = M.spelllang()
			diag.schedule(buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost" }, {
		group = group,
		callback = function(args)
			if vim.bo[args.buf].buftype ~= "" then
				return
			end
			diag.schedule(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(args)
			diag.detach(args.buf)
		end,
	})

	vim.api.nvim_create_autocmd("FocusGained", {
		group = group,
		callback = function()
			dict.sync_all()
		end,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			dict.sync_all()
		end,
	})

	vim.api.nvim_create_user_command("SpellAll", M.all, { desc = "列出本 buffer 的拼写问题" })
	vim.api.nvim_create_user_command("SpellWords", M.list, { desc = "查看/删除自定义词典" })
	vim.api.nvim_create_user_command("SpellPromote", function()
		require("feat.spell.words").promote()
	end, { desc = "从项目代码里挑技术词收进词典" })
	vim.api.nvim_create_user_command("SpellSync", function()
		dict.sync(dict.GLOBAL, true)
		local proj = dict.project_file(0)
		if proj then
			dict.sync(proj, true)
		end
		vim.notify("词典已重建", vim.log.levels.INFO)
	end, { desc = "重建 .add.spl" })
	vim.api.nvim_create_user_command("SpellAdd", function(args)
		local word = args.args
		local scope = args.bang and "global" or "project"
		if word == "" then
			word = vim.fn.expand("<cword>")
		end
		add_word(word, scope, 0)
	end, { nargs = "?", bang = true, desc = "收词（默认项目词典，! 收个人词典）" })

	vim.keymap.set("n", "<leader>zw", M.toggle, { desc = "拼写检查开关" })
	vim.keymap.set("n", "z=", suggest.pick, { desc = "拼写建议（picker）" })
	vim.keymap.set("n", "zG", function()
		add_word(vim.fn.expand("<cword>"), "global", 0)
	end, { desc = "收词进个人词典" })
	vim.keymap.set("n", "<leader>za", M.all, { desc = "拼写问题列表" })
	vim.keymap.set("n", "<leader>zl", M.list, { desc = "拼写词典" })
	vim.keymap.set("n", "<leader>zp", function()
		words.promote()
	end, { desc = "技术词候选" })
	vim.keymap.set("n", "<leader>zu", suggest.undo, { desc = "撤回上次拼写替换" })
	vim.keymap.set("n", "<leader>z?", suggest.hover, { desc = "浮窗看建议" })
end

M.dict = dict
M.diag = diag
M.suggest = suggest
M.words = words

return M
