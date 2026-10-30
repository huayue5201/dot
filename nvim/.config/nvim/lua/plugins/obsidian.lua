-- https://github.com/obsidian-nvim/obsidian.nvim
-- 在 nvim 里编辑 Obsidian vault：[[wiki 链接]] 补全/跳转、backlinks、tags、
-- daily notes、搜索（ripgrep）、图片粘贴等。内置 LSP（client 名 "obsidian-ls"）提供补全，
-- blink 的 lsp source 会自动接管，无需额外补全配置。
return {
	"obsidian-nvim/obsidian.nvim",
	sem_version = "*",
	-- 只在 markdown 上按需加载；非 vault 的 .md 会被插件静默忽略（无映射、无 LSP）
	opts = {
		-- 清理旧的 ObsidianXxx 命令，统一用 `:Obsidian <sub>`（4.0 起 legacy 将被移除）
		legacy_commands = false,

		workspaces = {
			{ name = "notes", path = "~/notes" },
			{ name = "data_pulse", path = "~/rust-project/data_pulse/note" },
		},

		-- 本机没装 telescope/fzf-lua/mini.pick/snacks，picker.name 留空会自动回退到
		-- 原生 vim.ui.select。装了其中任意一个后重启即可自动启用。
		-- picker = { name = "mini.pick" },

		-- 新建笔记默认开在 vsplit，避免从代码里建笔记时顶掉代码窗口
		open_notes_in = "vsplit",

		-- 与 Obsidian 本体保持一致（见各 vault 的 .obsidian/*.json）：
		-- 日记落 daily/YYYY-MM-DD.md，模板 templates/daily.md，附件落 attachments/。
		-- 格式串用 moment.js 风格，和 Obsidian 的 Daily notes 设置同源，两边互通。
		daily_notes = {
			folder = "daily",
			date_format = "YYYY-MM-DD",
			template = "templates/daily",
			default_tags = { "daily" },
		},
		-- 粘贴图片默认落 attachments/（v3 默认值，显式写出以防上游变更后两边错位）
		attachments = {
			folder = "attachments",
		},
		-- 新笔记按标题命名（与你现有 md 文件风格一致，也便于 [[链接]] 可读）
		note_id_func = function(title)
			if title ~= nil then
				return title:gsub(" ", "-"):gsub("[/\\:#?\"|*<>]", "")
			end
			return tostring(os.time())
		end,

		-- 笔记内 buffer 局部映射（依赖当前笔记 / 光标，统一 <leader>n 前缀）
		callbacks = {
			enter_note = function()
				-- Obsidian 的附加 UI（链接 conceal、复选框渲染等）需要 conceallevel 为 1 或 2，
				-- 否则每次进笔记都会报 warning。只对本 buffer 设置。
				vim.opt_local.conceallevel = 2
				local function map(lhs, cmd, desc)
					vim.keymap.set("n", lhs, "<cmd>Obsidian " .. cmd .. "<cr>", { buffer = true, desc = "Obsidian: " .. desc })
				end
				-- 当前笔记动作（note_action）
				map("<leader>nb", "backlinks", "反向链接")
				map("<leader>nl", "links", "列出链接")
				map("<leader>nL", "link", "插入链接（已有笔记）")
				map("<leader>nN", "link_new", "插入链接（新建）")
				map("<leader>nf", "follow_link", "跟随链接")
				map("<leader>np", "paste_img", "粘贴图片")
				map("<leader>nc", "toggle_checkbox", "切换复选框")
				map("<leader>ne", "extract_note", "抽取为新笔记")
				map("<leader>nr", "rename", "重命名笔记")
				map("<leader>nT", "toc", "生成目录")
			end,
		},
	},
	-- 创建 / 导航类命令不依赖当前笔记，设为全局，代码里也能随时写笔记
	config = function(_, opts)
		require("obsidian").setup(opts)
		local function map(lhs, cmd, desc)
			vim.keymap.set("n", lhs, "<cmd>Obsidian " .. cmd .. "<cr>", { desc = "Obsidian: " .. desc })
		end
		map("<leader>nn", "new", "新笔记")
		map("<leader>nt", "new_from_template", "从模板新建")
		map("<leader>no", "quick_switch", "快速切换/打开")
		map("<leader>ns", "search", "搜索")
		map("<leader>ng", "tags", "标签")
		map("<leader>nd", "today", "今日日记")
		map("<leader>nD", "dailies", "日记列表")
		map("<leader>nw", "workspace", "切换 workspace")
		map("<leader>nh", "help", "帮助")
	end,
}
