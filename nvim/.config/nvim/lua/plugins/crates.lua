-- https://github.com/saecki/crates.nvim

return {
	"saecki/crates.nvim",
	event = { "BufRead Cargo.toml" },
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
			text = { searching = "   搜索中", loading = "   加载中" },
			popup = { autofocus = true, hide_on_select = true, style = "minimal", border = "shadow" },
			lsp = { enabled = true, actions = true, completion = true, hover = true },
		})

		local function map_filetype(ft, mode, lhs, rhs, opts)
			vim.api.nvim_create_autocmd("FileType", {
				pattern = ft,
				callback = function()
					vim.keymap.set(
						mode,
						lhs,
						rhs,
						vim.tbl_extend("force", opts or {}, { buffer = true, silent = true })
					)
				end,
			})
		end

		-- Crates 按键映射
		map_filetype("toml", "n", "<leader>ot", crates.toggle, { desc = "依赖: 切换" })
		map_filetype("toml", "n", "<leader>or", crates.reload, { desc = "依赖: 重载" })
		map_filetype("toml", "n", "<leader>ov", crates.show_versions_popup, { desc = "依赖: 显示版本" })
		map_filetype("toml", "n", "<leader>of", crates.show_features_popup, { desc = "依赖: 显示功能" })
		map_filetype("toml", "n", "<leader>od", crates.show_dependencies_popup, { desc = "依赖: 显示依赖项" })
		map_filetype("toml", "n", "<leader>ou", crates.update_crate, { desc = "依赖: 更新当前包" })
		map_filetype("v", "<leader>ou", crates.update_crates, { desc = "依赖: 更新选中包" })
		map_filetype("toml", "n", "<leader>oa", crates.update_all_crates, { desc = "依赖: 更新所有包" })
		map_filetype("toml", "n", "<leader>oU", crates.upgrade_crate, { desc = "依赖: 升级当前包" })
		map_filetype("v", "<leader>oU", crates.upgrade_crates, { desc = "依赖: 升级选中包" })
		map_filetype("toml", "n", "<leader>oA", crates.upgrade_all_crates, { desc = "依赖: 升级所有包" })
		map_filetype(
			"toml",
			"n",
			"<leader>ox",
			crates.expand_plain_crate_to_inline_table,
			{ desc = "依赖: 展开到内联表" }
		)
		map_filetype(
			"toml",
			"n",
			"<leader>oX",
			crates.extract_crate_into_table,
			{ desc = "依赖: 提取到独立表" }
		)
		map_filetype("toml", "n", "<leader>oH", crates.open_homepage, { desc = "依赖: 打开主页" })
		map_filetype("toml", "n", "<leader>oR", crates.open_repository, { desc = "依赖: 打开仓库" })
		map_filetype("toml", "n", "<leader>oD", crates.open_documentation, { desc = "依赖: 打开文档" })
		map_filetype("toml", "n", "<leader>oC", crates.open_crates_io, { desc = "依赖: 打开 crates.io" })
		map_filetype("toml", "n", "<leader>oL", crates.open_lib_rs, { desc = "依赖: 打开 lib.rs" })

		-- 显示文档（回退到 LSP 悬停提示）
		local function show_documentation()
			if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
				require("crates").show_popup()
			else
				vim.lsp.buf.hover()
			end
		end
		map_filetype("toml", "n", "K", show_documentation, { desc = "依赖: 显示文档", silent = true })
	end,
}
