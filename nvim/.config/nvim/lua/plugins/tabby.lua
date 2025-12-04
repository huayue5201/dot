-- https://github.com/nanozuki/tabby.nvim

return {
	"nanozuki/tabby.nvim",
	event = "UIEnter",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		-- local theme = {
		-- 	fill = "TabLineFill",
		-- 	head = "TabLine",
		-- 	current_tab = "TabLineSel",
		-- 	tab = "TabLine",
		-- 	win = "TabLine",
		-- 	tail = "TabLine",
		-- }
		-- local theme = "oasis"
		-- vim.api.nvim_set_hl(0, "TabbyHeadIcon", { fg = "#7FBBB3", bg = "#414B50" })
		-- vim.api.nvim_set_hl(0, "TabbyHead", { fg = "#7FBBB3", bg = "#414B50" })

		require("tabby").setup({
			-- theme = "oasis", -- Automatically matches your current Oasis style
			-- line = function(line)
			-- 	return {
			-- 		{
			-- 			{ "  ", hl = "TabbyHeadIcon" },
			-- 			line.sep("", "TabbyHead", theme.fill),
			-- 		},
			-- 		line.tabs().foreach(function(tab)
			-- 			local hl = tab.is_current() and theme.current_tab or theme.tab
			--
			-- 			-- remove count of wins in tab with [n+] included in tab.name()
			-- 			local name = tab.name()
			-- 			local index = string.find(name, "%[%d")
			-- 			local tab_name = index and string.sub(name, 1, index - 1) or name
			--
			-- 			-- indicate if any of buffers in tab have unsaved changes
			-- 			local modified = false
			-- 			local win_ids = require("tabby.module.api").get_tab_wins(tab.id)
			-- 			for _, win_id in ipairs(win_ids) do
			-- 				if pcall(vim.api.nvim_win_get_buf, win_id) then
			-- 					local bufid = vim.api.nvim_win_get_buf(win_id)
			-- 					if vim.api.nvim_buf_get_option(bufid, "modified") then
			-- 						modified = true
			-- 						break
			-- 					end
			-- 				end
			-- 			end
			-- 			return {
			-- 				line.sep("", hl, theme.fill),
			-- 				tab.number(),
			-- 				tab_name,
			-- 				modified and "",
			-- 				tab.close_btn(""),
			-- 				line.sep("", hl, theme.fill),
			-- 				hl = hl,
			-- 				margin = " ",
			-- 			}
			-- 		end),
			-- 		line.spacer(),
			-- 		{
			-- 			line.sep("", theme.tail, theme.fill),
			-- 			{ "  ", hl = theme.tail },
			-- 		},
			-- 		hl = theme.fill,
			-- }
			-- end,
		})
		-- 重命名 Tab（Tabby 内置命令）
		vim.keymap.set("n", "<leader>trn", ":Tabby rename_tab ", { desc = "tabby: 重命名 Tab" })

		vim.keymap.set("n", "<leader>tp", ":Tabby pick_window<CR>", { desc = "tabby: Tab 列表", silent = true })
	end,
}
