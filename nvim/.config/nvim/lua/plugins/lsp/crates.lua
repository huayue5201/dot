-- https://github.com/saecki/crates.nvim
-- TODO: https://github.com/lvim-tech/lvim-dependencies

return {
	"saecki/crates.nvim",
	tag = "stable",
	config = function()
		local crates = require("crates")
		crates.setup({
			smart_insert = true,
			insert_closing_quote = true,
			autoload = true,
			autoupdate = true,
			autoupdate_throttle = 250,
			loading_indicator = true,
			search_indicator = true,
			date_format = "%Y-%m-%d",
			thousands_separator = ".",
			notification_title = "crates.nvim",
			curl_args = { "-sL", "--retry", "1" },
			max_parallel_requests = 80,
			expand_crate_moves_cursor = true,
			enable_update_available_warning = true,
			on_attach = function(bufnr) end,
			text = { searching = "   Searching", loading = "   Loading" },
			popup = { autofocus = true, hide_on_select = true, style = "minimal", border = "shadow" },
			lsp = { enabled = true, actions = true, completion = true, hover = true },
		})

		-- 只对 Cargo.toml 生效：crates.nvim 自己只在文件名是 Cargo.toml 时 attach，
		-- 普通 .toml 里按这些键只会拿到空浮窗，属于无意义噪音。
		local function is_cargo(buf)
			return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t") == "Cargo.toml"
		end

		local function map_cargo(mode, lhs, rhs, opts)
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "toml",
				callback = function(args)
					pcall(vim.keymap.del, mode, lhs, { buffer = args.buf })
					if not is_cargo(args.buf) then
						return
					end
					vim.keymap.set(
						mode,
						lhs,
						rhs,
						vim.tbl_extend("force", opts or {}, { buffer = true, silent = true })
					)
				end,
			})
		end

		-- which-key：\c 分组只在 Cargo.toml 里有键，所以分组名也得按 buffer 注册
		-- （全局注册的话 which-key 找不到子映射会把这个空组删掉，见 plugin/which-key.lua）
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "toml",
			callback = function(args)
				if not is_cargo(args.buf) then
					return
				end
				pcall(function()
					require("which-key").add({
						{
							"<localleader>c",
							group = "Dependencies (crates)",
							icon = { icon = "󰏗 ", color = "green" },
							buffer = args.buf,
						},
					})
				end)
			end,
		})

		-- Crates 按键映射
		map_cargo("n", "<localleader>ct", crates.toggle, { desc = "Dependency: toggle" })
		map_cargo("n", "<localleader>cr", crates.reload, { desc = "Dependency: reload" })
		map_cargo("n", "<localleader>cv", crates.show_versions_popup, { desc = "Dependency: show versions" })
		map_cargo("n", "<localleader>cf", crates.show_features_popup, { desc = "Dependency: show features" })
		map_cargo("n", "<localleader>cd", crates.show_dependencies_popup, { desc = "Dependency: show dependencies" })
		map_cargo("n", "<localleader>cu", crates.update_crate, { desc = "Dependency: update current crate" })
		map_cargo("v", "<localleader>cu", crates.update_crates, { desc = "Dependency: update selected crates" })
		map_cargo("n", "<localleader>ca", crates.update_all_crates, { desc = "Dependency: update all crates" })
		map_cargo("n", "<localleader>cU", crates.upgrade_crate, { desc = "Dependency: upgrade current crate" })
		map_cargo("v", "<localleader>cU", crates.upgrade_crates, { desc = "Dependency: upgrade selected crates" })
		map_cargo("n", "<localleader>cA", crates.upgrade_all_crates, { desc = "Dependency: upgrade all crates" })
		map_cargo(
			"n",
			"<localleader>cx",
			crates.expand_plain_crate_to_inline_table,
			{ desc = "Dependency: expand to inline table" }
		)
		map_cargo(
			"n",
			"<localleader>cX",
			crates.extract_crate_into_table,
			{ desc = "Dependency: extract into separate table" }
		)
		map_cargo("n", "<localleader>cH", crates.open_homepage, { desc = "Dependency: open homepage" })
		map_cargo("n", "<localleader>cR", crates.open_repository, { desc = "Dependency: open repository" })
		map_cargo("n", "<localleader>cD", crates.open_documentation, { desc = "Dependency: open documentation" })
		map_cargo("n", "<localleader>cC", crates.open_crates_io, { desc = "Dependency: open crates.io" })
		map_cargo("n", "<localleader>cL", crates.open_lib_rs, { desc = "Dependency: open lib.rs" })

		-- 显示文档（回退到 LSP 悬停提示）
		local function show_documentation()
			if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
				require("crates").show_popup()
			else
				vim.lsp.buf.hover()
			end
		end
		map_cargo("n", "K", show_documentation, { desc = "Dependency: show documentation", silent = true })
	end,
}
