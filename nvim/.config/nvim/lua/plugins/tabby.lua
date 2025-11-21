-- https://github.com/nanozuki/tabby.nvim

return {
	"nanozuki/tabby.nvim",
	event = "UIEnter",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local function get_lvim_space_tabs()
			local pub_status_ok, pub = pcall(require, "lvim-space.pub")
			if pub_status_ok then
				return pub.get_tab_info()
			else
				return { workspace_name = "Unknown", tabs = {} }
			end
		end

		local components = function()
			local comps = {}
			local lvim_data = get_lvim_space_tabs()

			-- Add LVIM Space tabs
			for _, tab in ipairs(lvim_data.tabs or {}) do
				local hl = tab.active and active_highlight or inactive_highlight
				table.insert(comps, {
					type = "text",
					text = { "  " .. tab.name .. "  ", hl = hl },
				})
			end

			-- Add workspace name
			table.insert(comps, {
				type = "text",
				text = { "  " .. (lvim_data.workspace_name or "Unknown") .. "  " },
			})

			return comps
		end

		-- tabby 配置
		require("tabby").setup({
			theme = "oasis", -- 使用 oasis.nvim 的配色
			components = components,
		})

		-- 重命名 Tab（Tabby 内置命令）
		vim.keymap.set("n", "<leader>tr", ":Tabby rename_tab ", { desc = "tabby: 重命名 Tab" })

		vim.keymap.set("n", "<leader>tp", ":Tabby pick_window<CR>", { desc = "tabby: Tab 列表", silent = true })
	end,
}
