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
			text = { searching = "   Searching", loading = "   Loading" },
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

		-- Crates keymaps
		map_filetype("toml", "n", "<leader>ct", crates.toggle, { desc = "Crates: toggle" })
		map_filetype("toml", "n", "<leader>cr", crates.reload, { desc = "Crates: reload" })
		map_filetype("toml", "n", "<leader>cv", crates.show_versions_popup, { desc = "Crates: show versions" })
		map_filetype("toml", "n", "<leader>cf", crates.show_features_popup, { desc = "Crates: show features" })
		map_filetype("toml", "n", "<leader>cd", crates.show_dependencies_popup, { desc = "Crates: show dependencies" })
		map_filetype("toml", "n", "<leader>cu", crates.update_crate, { desc = "Crates: update crate" })
		map_filetype("v", "<leader>cu", crates.update_crates, { desc = "Crates: update selected crates" })
		map_filetype("toml", "n", "<leader>ca", crates.update_all_crates, { desc = "Crates: update all crates" })
		map_filetype("toml", "n", "<leader>cU", crates.upgrade_crate, { desc = "Crates: upgrade crate" })
		map_filetype("v", "<leader>cU", crates.upgrade_crates, { desc = "Crates: upgrade selected crates" })
		map_filetype("toml", "n", "<leader>cA", crates.upgrade_all_crates, { desc = "Crates: upgrade all crates" })
		map_filetype(
			"toml",
			"n",
			"<leader>cx",
			crates.expand_plain_crate_to_inline_table,
			{ desc = "Crates: expand crate to inline table" }
		)
		map_filetype(
			"toml",
			"n",
			"<leader>cX",
			crates.extract_crate_into_table,
			{ desc = "Crates: extract crate to table" }
		)
		map_filetype("toml", "n", "<leader>cH", crates.open_homepage, { desc = "Crates: open homepage" })
		map_filetype("toml", "n", "<leader>cR", crates.open_repository, { desc = "Crates: open repository" })
		map_filetype("toml", "n", "<leader>cD", crates.open_documentation, { desc = "Crates: open documentation" })
		map_filetype("toml", "n", "<leader>cC", crates.open_crates_io, { desc = "Crates: open crates.io" })
		map_filetype("toml", "n", "<leader>cL", crates.open_lib_rs, { desc = "Crates: open lib.rs" })

		-- Show documentation (fallback to LSP hover)
		local function show_documentation()
			if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
				require("crates").show_popup()
			else
				vim.lsp.buf.hover()
			end
		end
		map_filetype("toml", "n", "K", show_documentation, { desc = "Crates: show documentation", silent = true })
	end,
}
