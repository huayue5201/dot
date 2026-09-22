-- https://github.com/celeste3z/celeste_comment.nvim

return {
	"celeste3z/celeste_comment.nvim",
	lazy = false,
	config = function()
		require("celeste_comment").setup(
			---@type Celeste.Comment.PartialOpts
			{
				-- Restore cursor position after comment/uncomment.
				keep_cursor = true,

				-- Restore selection after commenting.
				-- Possible values: "never" | "adjust" | "expand_block" | "expand_line" | "keep_visual"
				-- Can also combine, e.g. "expand_line | keep_visual" which means: force line comments to
				-- `V` mode and stay in visual mode
				-- See `:help celeste_comment-config-keep_selection` for more details
				keep_selection = "never",

				-- Insert space between comment marker and text.
				insert_space = true,

				-- Place comment at start of line, skip indent alignment
				line_comment_no_indent = false,

				-- Match comment markers case-insensitively (e.g. `@REM` vs `@rem` vs `@rEm`)
				case_insensitive = false,

				-- Detect indent size and indent style (tabs vs spaces) from buffer content.
				-- Does not modify any buffer options. See `:help celeste_comment-config-detect_indent`
				-- for more details.
				detect_indent = false,

				-- Whether to use `vim.api.nvim_buf_set_text` to commit edits.
				-- `nvim_buf_set_text` only modifies parts of lines, preserving regular marks and
				-- extmarks on non-modified parts.
				-- `nvim_buf_set_lines` + `lockmarks` replaces whole lines, has better performance
				-- but only preserves regular marks.
				use_set_text = false,

				-- Relaxed block comment detection: ignore whitespace around markers.
				block_relaxed_detect = true,

				-- Max lines to search for block comment pairs.
				block_textobj_nlines = 200,

				-- How to handle empty lines during comment toggle.
				-- See `:help celeste_comment-config-ignore_empty_lines` for more details
				-- Possible values: "never" | "mixed" | "always"
				ignore_empty_lines = "always",

				-- Fallback to block comment when line comment wraps.
				-- See `:help celeste_comment-config-fallback_to_block` for more details
				-- Possible values: "never" | "if_line_cms_wrapped"
				fallback_to_block = "if_line_cms_wrapped",

				-- Log level (nvim-0.13+). Ignored on older versions.
				log_level = vim.log.levels.OFF,

				-- Comment string configuration.
				cms_confs = nil,

				mappings = {
					-- Line comment by motion (n)
					line_toggle = "gc",
					-- Line comment current line (n)
					line_toggle_cur = "gcc",
					-- Line comment visual selection (x)
					line_toggle_visual = "gc",
					-- Insert mode line toggle (i), example `{"<M-/>", "<M-_>"}`
					line_toggle_insert = "",

					-- Block comment by motion (n, x)
					block_toggle = "gb",
					-- Block comment current line (n)
					block_toggle_cur = "gbc",
					-- Block comment visual selection (x)
					block_toggle_visual = "gb",

					-- All textobjects below works without treesitter
					-- NOTE: not works for end of line comment, like 'some code -- comment here'
					-- Linewise textobject outer (o)
					line_textobject = "gc",
					-- Blockwise textobject outer (o)
					block_textobject = "gb",
					-- Auto textobject outer (o, x), example 'ac'
					auto_textobject = "",
					-- Auto textobject inner (o, x), example 'ic'
					auto_textobject_inner = "",

					-- Auto uncomment (n), example `gcu`
					uncomment_auto = "",

					-- Insert comment below (n), example `gco`
					line_add_below = "",
					-- Insert comment above (n), example `gcO`
					line_add_above = "",
					-- Insert comment at end of line (n), example `gcA`
					line_add_eol = "",

					-- Invert comment per line (n, x), example `gcI`
					line_invert = "",
					-- Force add line comment (n, x), example `gCC`
					line_force_add = "",
					-- Force remove line comment (n, x), example `gCU`
					line_force_remove = "",

					-- Cursor sticky dot-repeat.
					-- If a "." mapping already exists, this will not override it.
					-- You can also call `require("celeste_comment").track_state()` in your
					-- own dot-repeat keymap to enable sticky cursor behavior.
					-- See `:help celeste_comment-api` for more details.
					dot_repeat = ".",
				},

				hooks = {
					-- Called before commit edits, receives context
					pre_commit_edits = nil,
					-- Called after commit edits, receives context
					post_commit_edits = nil,
					-- Custom comment string resolver function
					cms_conf_resolver = nil,
					-- Custom indent resolver function
					indent_resolver = nil,
				},
			}
		)
	end,
}
