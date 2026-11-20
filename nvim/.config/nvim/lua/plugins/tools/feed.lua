-- https://github.com/neo451/feed.nvim
-- 在 Neovim 里读 RSS/Atom：这里只用来盯「插件发版」，不用来读博客。
-- 订阅是声明式的：改下面的 feeds → 重启 nvim（setup 时把新 feed 及其 tags 写进库）
-- → `:Feed update` 抓取 → `:Feed` 打开索引（默认 `+unread @2-weeks-ago`）。
-- `:Feed sync` 只做反向清理：删掉配置里已经不存在的 feed（`!` 连条目一起删）。
-- 索引/条目缓冲里：`?` 看键位、`b` 浏览器打开、`+/-` 打标签、`s` 搜索、`r` 刷新。
--
-- 列表由 lua/plugins/** 的 spec 探测生成（2026-11-20）：
--   132 个上游仓库里 87 个有 GitHub Release → 订阅 releases.atom（`user/repo/releases` 简写）；
--   剩下 45 个只有提交（无 release 也无 tag），文件末尾以注释形式列出，订阅它们等于订阅 commits，
--   噪音很大，需要时再手动放开。tags 来自 spec 所在目录，方便 `:Feed =+ui` 这类按组过滤。
--
-- 依赖：neovim 0.12+、pandoc、curl、tar、tree-sitter-cli >= 0.26.1、C 编译器，
-- 以及 nvim-treesitter 的 xml/html/markdown/markdown_inline 四个 parser。
return {
	"neo451/feed.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("feed").setup({
			feeds = {
				-- ui（9）
				{ "3rd/image.nvim/releases", tags = { "ui" } },
				{ "Bekaboo/dropbar.nvim/releases", tags = { "ui" } },
				{ "folke/todo-comments.nvim/releases", tags = { "ui" } },
				{ "hmdfrds/focal.nvim/releases", tags = { "ui" } },
				{ "nvim-lua/plenary.nvim/releases", tags = { "ui" } },
				{ "nvim-tree/nvim-web-devicons/releases", tags = { "ui" } },
				{ "nvim-treesitter/nvim-treesitter-context/releases", tags = { "ui" } },
				{ "serhez/bento.nvim/releases", tags = { "ui" } },
				{ "sphamba/smear-cursor.nvim/releases", tags = { "ui" } },
				-- editor（22）
				{ "bennypowers/nvim-regexplainer/releases", tags = { "editor" } },
				{ "bramdelta/blink-dap/releases", tags = { "editor" } },
				{ "celeste3z/celeste_comment.nvim/releases", tags = { "editor" } },
				{ "chrisgrieser/nvim-origami/releases", tags = { "editor" } },
				{ "fangjunzhou/comment-divider.nvim/releases", tags = { "editor" } },
				{ "gbprod/yanky.nvim/releases", tags = { "editor" } },
				{ "johmsalas/text-case.nvim/releases", tags = { "editor" } },
				{ "karb94/neoscroll.nvim/releases", tags = { "editor" } },
				{ "kevinhwang91/nvim-hlslens/releases", tags = { "editor" } },
				{ "kylechui/nvim-surround/releases", tags = { "editor" } },
				{ "mikavilpas/blink-ripgrep.nvim/releases", tags = { "editor" } },
				{ "minigian/juan-logs.nvim/releases", tags = { "editor" } },
				{ "monaqa/dial.nvim/releases", tags = { "editor" } },
				{ "nemanjamalesija/smart-paste.nvim/releases", tags = { "editor" } },
				{ "nolleh/warp.nvim/releases", tags = { "editor" } },
				{ "nvim-mini/mini.indentscope/releases", tags = { "editor" } },
				{ "petertriho/nvim-scrollbar/releases", tags = { "editor" } },
				{ "pteroctopus/faster.nvim/releases", tags = { "editor" } },
				{ "saghen/blink.cmp/releases", tags = { "editor" } },
				{ "smart-splits-nvim/smart-splits.nvim/releases", tags = { "editor" } },
				{ "willothy/flatten.nvim/releases", tags = { "editor" } },
				{ "windwp/nvim-autopairs/releases", tags = { "editor" } },
				-- lang（8）
				{ "cordx56/rustowl/releases", tags = { "lang" } },
				{ "jeangiraldoo/codedocs.nvim/releases", tags = { "lang" } },
				{ "kkew3/jieba.vim/releases", tags = { "lang" } },
				{ "obsidian-nvim/obsidian.nvim/releases", tags = { "lang" } },
				{ "selimacerbas/kitehost.nvim/releases", tags = { "lang" } },
				{ "selimacerbas/mdkite.nvim/releases", tags = { "lang" } },
				{ "tpope/vim-repeat/releases", tags = { "lang" } },
				{ "Zeioth/markmap.nvim/releases", tags = { "lang" } },
				-- lsp（11）
				{ "antosha417/nvim-lsp-file-operations/releases", tags = { "lsp" } },
				{ "bassamsdata/namu.nvim/releases", tags = { "lsp" } },
				{ "folke/lazydev.nvim/releases", tags = { "lsp" } },
				{ "j-hui/fidget.nvim/releases", tags = { "lsp" } },
				{ "kevinhwang91/nvim-bqf/releases", tags = { "lsp" } },
				{ "mason-org/mason.nvim/releases", tags = { "lsp" } },
				{ "mfussenegger/nvim-lint/releases", tags = { "lsp" } },
				{ "nvim-treesitter/nvim-treesitter/releases", tags = { "lsp" } },
				{ "saecki/crates.nvim/releases", tags = { "lsp" } },
				{ "stevearc/conform.nvim/releases", tags = { "lsp" } },
				{ "stevearc/quicker.nvim/releases", tags = { "lsp" } },
				-- dap（3）
				{ "docker/nvim-dap-docker/releases", tags = { "dap" } },
				{ "esensar/nvim-dev-container/releases", tags = { "dap" } },
				{ "mfussenegger/nvim-dap/releases", tags = { "dap" } },
				-- git（8）
				{ "akinsho/git-conflict.nvim/releases", tags = { "git" } },
				{ "CoreyKaylor/diffbandit.nvim/releases", tags = { "git" } },
				{ "emrearmagan/atlas.nvim/releases", tags = { "git" } },
				{ "esmuellert/codediff.nvim/releases", tags = { "git" } },
				{ "janbuchar/difftsigns.nvim/releases", tags = { "git" } },
				{ "lewis6991/gitsigns.nvim/releases", tags = { "git" } },
				{ "m00qek/baleia.nvim/releases", tags = { "git" } },
				{ "NeogitOrg/neogit/releases", tags = { "git" } },
				-- ai（2）
				{ "milanglacier/minuet-ai.nvim/releases", tags = { "ai" } },
				{ "olimorris/codecompanion.nvim/releases", tags = { "ai" } },
				-- tools（18）
				{ "2giosangmitom/sqmeow.nvim/releases", tags = { "tools" } },
				{ "dmtrKovalenko/fff/releases", tags = { "tools" } },
				{ "folke/which-key.nvim/releases", tags = { "tools" } },
				{ "fredrikaverpil/neotest-golang/releases", tags = { "tools" } },
				{ "linrongbin16/gentags.nvim/releases", tags = { "tools" } },
				{ "MagicDuck/grug-far.nvim/releases", tags = { "tools" } },
				{ "MisanthropicBit/neotest-busted/releases", tags = { "tools" } },
				{ "mr-u0b0dy/crazy-coverage.nvim/releases", tags = { "tools" } },
				{ "MunifTanjim/nui.nvim/releases", tags = { "tools" } },
				{ "nullromo/cash.nvim/releases", tags = { "tools" } },
				{ "nvim-neo-tree/neo-tree.nvim/releases", tags = { "tools" } },
				{ "nvim-neotest/neotest/releases", tags = { "tools" } },
				{ "nvim-neotest/nvim-nio/releases", tags = { "tools" } },
				{ "Olical/conjure/releases", tags = { "tools" } },
				{ "rodrigoscc/nurl.nvim/releases", tags = { "tools" } },
				{ "stevearc/overseer.nvim/releases", tags = { "tools" } },
				{ "stevearc/resession.nvim/releases", tags = { "tools" } },
				{ "wellatleastitried/bitwise-visualizer.nvim/releases", tags = { "tools" } },
				-- other（6）
				{ "bytebeast/kissaten.nvim/releases", tags = { "other" } },
				{ "EdenEast/nightfox.nvim/releases", tags = { "other" } },
				{ "folke/tokyonight.nvim/releases", tags = { "other" } },
				{ "igorlfs/nvim-dap-view/releases", tags = { "other" } },
				{ "nvim-tree/nvim-tree.lua/releases", tags = { "other" } },
				{ "rcarriga/nvim-dap-ui/releases", tags = { "other" } },
				-- 以下只有提交、没有 release/tag：订阅会变成提交流水，需要时再放开
				-- ui
				-- "chentoast/marks.nvim",
				-- "luukvbaal/statuscol.nvim",
				-- "nvim-telescope/telescope-fzf-native.nvim",
				-- "rachartier/tiny-cmdline.nvim",
				-- editor
				-- "chrisgrieser/nvim-chainsaw",
				-- "chrisgrieser/nvim-scissors",
				-- "huayue5201/nvim-lastplace",
				-- "mcauley-penney/visual-whitespace.nvim",
				-- "NMAC427/guess-indent.nvim",
				-- "RRethy/vim-illuminate",
				-- "saghen/blink.lib",
				-- "ThePrimeagen/refactoring.nvim",
				-- "Wansmer/treesj",
				-- "wurli/visimatch.nvim",
				-- "xzbdmw/colorful-menu.nvim",
				-- lang
				-- "0xdeadf1sh/AssemblyForNeovim",
				-- "a-usr/xml2lua.nvim",
				-- "alexpasmantier/krust.nvim",
				-- "huayue5201/videre.nvim",
				-- "hughfenghen/fenghen-im-select.nvim",
				-- "LiadOz/nvim-dap-repl-highlights",
				-- "nvim-treesitter/nvim-treesitter-textobjects",
				-- "Owen-Dechow/graph_view_toml_parser",
				-- "Owen-Dechow/graph_view_yaml_parser",
				-- "psliwka/vim-dirtytalk",
				-- lsp
				-- "DNLHC/glance.nvim",
				-- "rachartier/tiny-code-action.nvim",
				-- "rachartier/tiny-inline-diagnostic.nvim",
				-- dap
				-- "jbyuki/one-small-step-for-vimkind",
				-- "jedrzejboczar/nvim-dap-cortex-debug",
				-- "Jorenar/nvim-dap-disasm",
				-- "leoluz/nvim-dap-go",
				-- "mfussenegger/nvim-dap-python",
				-- git
				-- "huayue5201/neogit-ai-commit.nvim",
				-- tools
				-- "antoinemadec/FixCursorHold.nvim",
				-- "chrisgrieser/nvim-genghis",
				-- "huayue5201/neotest-rust",
				-- "Punity122333/hexinspector.nvim",
				-- "saifulapm/neotree-file-nesting-config",
				-- "XXiaoA/atone.nvim",
				-- other
				-- "dav1d-wright/nvim-dap-image",
				-- "huayue5201/ask-agent.nvim",
				-- "huayue5201/nvim-store3",
				-- "Owen-Dechow/videre.nvim",
				-- "ShiraiEd/Wolf359_nvim_rust_theme",
			},
		})
	end,
}
