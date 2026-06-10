-- https://github.com/rachartier/tiny-code-action.nvim

return {
	"rachartier/tiny-code-action.nvim",
	event = "LspAttach",
	config = function()
		require("tiny-code-action").setup({
			picker = {
				"buffer",
				opts = {
					hotkeys = true, -- Enable hotkeys for quick selection of actions
					hotkeys_mode = "text_diff_based", -- Modes for generating hotkeys
					auto_preview = false, -- Enable or disable automatic preview
					auto_accept = false, -- Automatically accept the selected action (with hotkeys)
					position = "cursor", -- Position of the picker window
					winborder = "single", -- Border style for picker and preview windows
					keymaps = {
						preview = "K", -- Key to show preview
						close = { "q", "<Esc>" }, -- Keys to close the window (can be string or table)
						select = "<CR>", -- Keys to select action (can be string or table)
						preview_close = { "q", "<Esc>" }, -- Keys to return from preview to main window (can be string or table)
					},
					custom_keys = {
						{ key = "m", pattern = "Fill match arms" },
						{ key = "r", pattern = "Rename.*" }, -- Lua pattern matching
					},
					group_icon = " └",
				},
			},
		})

		-- Listen for main window opening
		vim.api.nvim_create_autocmd("User", {
			pattern = "TinyCodeActionWindowEnterMain",
			callback = function(event)
				local buf = event.data.buf
				local win = event.data.win
				vim.notify("Code action main window opened: buf=" .. buf .. ", win=" .. win)
			end,
		})

		-- Listen for preview window opening
		vim.api.nvim_create_autocmd("User", {
			pattern = "TinyCodeActionWindowEnterPreview",
			callback = function(event)
				local buf = event.data.buf
				local win = event.data.win
				-- Custom logic for preview window
			end,
		})

		vim.keymap.set({ "n", "x" }, "gra", function()
			require("tiny-code-action").code_action()
		end, { noremap = true, silent = true, desc = "code action" })
	end,
}
