-- https://github.com/huayue5201/tab-terminal.nvim
-- 一个 tab 一组终端：底部 panel + winbar 标签 + 右侧全局终端侧栏。
-- 插件本身不认识 tab_workspace：工作区名 / 新终端目录都由这里的回调提供。
return {
	dir = "~/neovim-plugins/tab-terminal.nvim",
	config = function()
		--- 新终端目录：当前 buffer 所属的根（多根工作区里可能是辅助根）；
		--- 没有文件时返回 nil，插件回落到该 tab 的 cwd。
		local function term_cwd(tab)
			local ok, ws = pcall(require, "tab_workspace")
			if not ok then
				return nil
			end
			local name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
			if name == "" then
				return nil
			end
			local ok_root, dir = pcall(ws.find_root, tab, name)
			return ok_root and dir or nil
		end

		--- 侧栏组头：工作区名 + 辅助根数量（"projA +1"）。
		local function workspace_name(tab)
			local ok_ws, ws = pcall(require, "tab_workspace")
			if not ok_ws then
				return nil
			end
			local ok_name, name = pcall(ws.workspace_name, tab)
			if not (ok_name and type(name) == "string" and name ~= "") then
				return nil
			end
			local extra = 0
			local ok_aux, aux = pcall(ws.aux_roots, tab)
			if ok_aux and type(aux) == "table" then
				extra = #aux
			end
			return extra > 0 and ("%s +%d"):format(name, extra) or name
		end

		require("tab_terminal").setup({
			cwd = term_cwd,
			workspace_name = workspace_name,
			keys = {
				toggle = { "<C-;>", "<leader>To" },
				new = "<leader>Tn",
				select = "<leader>Ts",
				rename = "<leader>Tr",
				tabs = "<leader>Tt",
				kill = "<leader>Tq",
				kill_all = "<leader>TQ",
				prev = "<",
				next = ">",
			},
			quick_shell = { key = "<leader>Tu", cmd = { "nu" }, desc = "终端: 新建 nushell" },
		})
	end,
}
