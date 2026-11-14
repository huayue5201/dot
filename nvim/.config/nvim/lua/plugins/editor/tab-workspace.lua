-- https://github.com/huayue5201/tab-workspace.nvim
-- 一个 tab 一个工作区：buffer 归属、cwd、多根、LSP 生命周期、本地配置、会话。
-- 插件本身不认识本仓库的 bufferline / lsp_ext，二者的差异都由这里的回调提供。

return {
	dir = "~/neovim-plugins/tab-workspace.nvim",
	config = function()
		-- 本仓库原来的 marker 列表（插件默认只留通用 marker）
		local root_markers = {
			".git",
			".hg",
			".emmyrc.json",
			".luarc.json",
			"stylua.toml",
			"selene.toml",
			".env.lua",
			"nvim-pack-lock.json",
			"pyproject.toml",
			"setup.py",
			"setup.cfg",
			"requirements.txt",
			"Cargo.toml",
			"go.mod",
			"package.json",
			"deno.json",
			"tsconfig.json",
			"Makefile",
			"CMakeLists.txt",
			"flake.nix",
			"compose.yaml",
			"docker-compose.yml",
			"Justfile",
		}

		--- bufferline 的重绘入口：插件只负责改 buflisted，怎么重绘由宿主决定。
		local function on_change()
			local bl = package.loaded["bufferline"]
			if type(bl) == "table" and type(bl.redraw) == "function" then
				bl.redraw()
				return
			end
			vim.schedule(function()
				pcall(vim.cmd, "redrawtabline")
			end)
		end

		--- lsp_ext.servers 的「按项目启停」；没装时退回 Neovim 全局判断。
		local function is_server_enabled(name, bufnr)
			local ok, servers = pcall(require, "lsp_ext.servers")
			if ok and type(servers.is_enabled) == "function" then
				local okk, enabled = pcall(servers.is_enabled, name, bufnr)
				if okk and enabled ~= nil then
					return enabled ~= false
				end
			end
			local okk, enabled = pcall(vim.lsp.is_enabled, name)
			return okk and enabled == true
		end

		require("tab_workspace").setup({
			auto_root = true,
			root_markers = root_markers,
			-- 本仓库依赖 .nvim.lua 的独占语义（exrc 只在启动时扫一次且不可回滚）
			takeover_exrc = true,
			is_server_enabled = is_server_enabled,
			on_change = on_change,
		})
	end,
}
