-- https://github.com/obsidian-nvim/obsidian.nvim
-- Obsidian vault 的 Neovim 前端（社区维护 fork，原 epwalsh 版已停更）。
-- 纯 Lua + in-process LSP：不做后台索引，打开文件时解析，搜索走 ripgrep。
--
-- 这里取代了原来的 mkdnflow：链接跳转/创建、待办勾选、heading 折叠、反链面板
-- 都由它提供（obsidian 的 <CR> smart_action 是 buffer-local，只在 vault 内的笔记里生效）。
-- 代价：mkdnflow 的表格对齐、列表重编号、死链检查、<localleader>n 那套键位没有了。
--
-- 依赖：Neovim >= 0.11、ripgrep（已装）、macOS 插图片要 pngpaste（brew install pngpaste）。
-- 关键取舍：
--   * link.style = "wiki"  —— 和 Obsidian app 一致，写 [[文件名]] 而不是 [x](y.md)
--   * note_id_func = title_id —— 文件名就是标题（Obsidian 的默认行为）。
--     默认的 zettel_id 会生成 "1762345678-ABCD" 这种 ID，和 app 里看到的文件名对不上。
--   * statusline / ui 都关掉：状态栏是 lua/ui/statusline.lua 自己组装的，
--     渲染是 render-markdown.nvim 负责的，两套同时开只会互相覆盖 conceal。
--   * picker 不设 name → 落回 vim.ui.select（本配置没装 telescope/fzf-lua/snacks/mini.pick）。
--
-- 和 marksman 的关系：lsp/marksman.lua 也会挂到 markdown 上，[[ ]] 的补全项会和
-- obsidian-ls 重名。不去 detach（lsp_ext/servers.lua 的 doautoall(FileType) 会把它重新贴上），
-- 真觉得吵就在 vault 里 :LspToggle 把 marksman 关掉——那个状态是按项目持久化的。

local WORKSPACES = {
	{ name = "notes", path = "~/notes" },
	{
		name = "vault",
		-- iCloud 里那个 vault，路径含中文和 ’
		path = "~/Documents/文稿 - 李佳’s MacBook Pro/Obsidian Vault",
	},
}

return {
	"obsidian-nvim/obsidian.nvim",
	sem_version = "3.*",
	config = function()
		require("obsidian").setup({
			-- 新版子命令体系（:Obsidian new / today / backlinks …）
			legacy_commands = false,

			workspaces = WORKSPACES,

			link = {
				style = "wiki",
				format = "shortest",
				-- 重命名笔记时自动改全库引用（写文件，保守起见可设 false）
				auto_update = true,
			},

			note_id_func = require("obsidian.builtin").title_id,
			new_notes_location = "current_dir",

			daily_notes = {
				-- ~/notes/.obsidian/daily-notes.json: folder=daily, format=YYYY-MM-DD
				-- 里面写的 template "templates/daily" 实际不存在（只有 templates/note.md），故不设 template
				enabled = true,
				folder = "daily",
				date_format = "YYYY-MM-DD",
				workdays_only = false, -- today/yesterday/tomorrow 不跳周末
				default_tags = {}, -- 不在 frontmatter 里塞 daily-notes
			},

			templates = {
				-- ~/notes/.obsidian/templates.json: folder=templates
				folder = "templates",
			},

			completion = {
				min_chars = 1, -- 打一个字符就出 [[ 链接候选
				create_new = true, -- 补全里没有的标题 → 允许直接建新笔记
			},

			-- 关掉自带的这两套 UI，理由见文件头
			statusline = { enabled = false },
			ui = { enable = false },

			attachments = { folder = "attachments" },

			-- 不索引 Obsidian 自己的元数据目录和回收站
			file = {
				ignore_filters = { ".obsidian", ".trash" },
			},
		})

		-- <leader>n = 笔记（which-key 里已有这个分组，见 lua/plugins/ui/which-key.lua:28）
		-- 两档：
		--   全局档  —— 不依赖当前 buffer 的命令（新建/日记/快切/全库搜索/tag/切 vault），
		--               写代码时也能直接 <leader>nq 跳进笔记，这是插件本来就支持的行为
		--               （:Obsidian 命令是全局的，只有它自带的 5 个键是 buffer-local）。
		--   笔记档  —— 只对当前笔记有意义的命令（跟链接/反链/勾选/重命名/toc…），
		--               走 ObsidianNoteEnter 装成 buffer-local，不污染普通 markdown。
		local function g(lhs, cmd, desc)
			vim.keymap.set("n", lhs, "<cmd>Obsidian " .. cmd .. "<cr>", { desc = desc })
		end

		-- 全局：日记
		g("<leader>nd", "today", "[N]ote today")
		g("<leader>ny", "yesterday", "[N]ote yesterday")
		g("<leader>nY", "tomorrow", "[N]ote tomorrow")
		g("<leader>nD", "dailies", "[N]ote dailies")
		-- 全局：新建
		g("<leader>nn", "new", "[N]ote new")
		g("<leader>nN", "new_from_template", "[N]ote new from template")
		g("<leader>nu", "unique_note", "[N]ote unique")
		-- 全局：找笔记
		g("<leader>nq", "quick_switch", "[N]ote quick switch")
		g("<leader>ns", "search", "[N]ote search (rg)")
		g("<leader>nt", "tags", "[N]ote tags")
		g("<leader>nw", "workspace", "[N]ote switch workspace")

		vim.api.nvim_create_autocmd("User", {
			group = vim.api.nvim_create_augroup("obsidian_leader_n", { clear = true }),
			pattern = "ObsidianNoteEnter",
			callback = function(ev)
				local buf = ev.buf
				local function n(lhs, cmd, desc)
					vim.keymap.set("n", lhs, "<cmd>Obsidian " .. cmd .. "<cr>", { buffer = buf, desc = desc })
				end
				local function v(lhs, cmd, desc)
					vim.keymap.set("x", lhs, ":Obsidian " .. cmd .. "<cr>", { buffer = buf, desc = desc })
				end

				-- 链接
				n("<leader>nf", "follow_link", "[N]ote follow link")
				n("<leader>nl", "link", "[N]ote insert link")
				n("<leader>nL", "links", "[N]ote links in this note")
				n("<leader>nb", "backlinks", "[N]ote backlinks")
				-- 内容
				n("<leader>nc", "toggle_checkbox", "[N]ote toggle checkbox")
				n("<leader>np", "properties", "[N]ote properties")
				n("<leader>nT", "toc", "[N]ote table of contents")
				n("<leader>nk", "footnotes", "[N]ote footnotes")
				n("<leader>nm", "bookmarks", "[N]ote bookmarks")
				-- 编辑当前笔记
				n("<leader>nr", "rename", "[N]ote rename")
				n("<leader>ni", "paste_img", "[N]ote paste image")
				n("<leader>no", "open", "[N]ote open in Obsidian")

				-- visual：选中文字 → 抽成新笔记 / 链接到已有笔记
				v("<leader>nx", "extract_note", "[N]ote extract selection")
				v("<leader>nl", "link", "[N]ote link selection")
			end,
		})
	end,
}
