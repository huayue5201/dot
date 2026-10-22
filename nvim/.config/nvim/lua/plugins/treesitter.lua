-- https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
-- https://github.com/neovim/neovim/issues/39006
-- 需要安装: brew install tree-sitter-cli

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	branch = "main",
	dependencies = {
		"LiadOz/nvim-dap-repl-highlights",
	},
	config = function()
		require("nvim-dap-repl-highlights").setup()

		-- 自愈：修复指向 nvim-treesitter 但已失效的 queries 软链。
		-- nvim-treesitter 的 TSUpdate 对已装 parser 只比对 revision，不会检查/修复
		-- 查询软链；一旦插件路径变化（如插件管理器迁移）这些链接就会全部断掉，
		-- 导致没有内置查询的语言（sql/rust/go 等）丢失高亮。
		local function heal_query_links()
			local uv = vim.uv or vim.loop
			local ok_cfg, ts_config = pcall(require, "nvim-treesitter.config")
			local ok_ins, ts_install = pcall(require, "nvim-treesitter.install")
			if not (ok_cfg and ok_ins) then
				return
			end

			local qdir = ts_config.get_install_dir("queries")
			local handle = uv.fs_scandir(qdir)
			if not handle then
				return
			end

			local repaired = {}
			while true do
				local name = uv.fs_scandir_next(handle)
				if not name then
					break
				end
				local link = vim.fs.joinpath(qdir, name)
				local st = uv.fs_lstat(link)
				-- 只修“软链 + 已失效 + 目标原本就是 nvim-treesitter 查询”，
				-- 避免动到用户自己指向别处的链接。
				if st and st.type == "link" and not uv.fs_stat(link) then
					local target = uv.fs_readlink(link)
					if target and target:find("nvim%-treesitter/runtime/queries/") then
						local src = ts_install.get_package_path("runtime", "queries", name)
						if src and uv.fs_stat(src) then
							uv.fs_unlink(link)
							uv.fs_symlink(src, link, { dir = true })
							repaired[#repaired + 1] = name
						end
					end
				end
			end

			if #repaired > 0 then
				vim.notify(
					("treesitter: 修复了 %d 个失效的查询链接: %s"):format(
						#repaired,
						table.concat(repaired, ", ")
					),
					vim.log.levels.INFO
				)
			end
		end

		local ensure_installed = {
			"c",
			"lua",
			"vim",
			"vimdoc",
			"python",
			"javascript",
			"typescript",
			"bash",
			"html",
			"css",
			"json",
			"http", -- rest.nvim 需要（.http 文件解析）
			"markdown",
			"markdown_inline",
			"dap_repl",
			"go",
			"rust",
			"sql", -- sqmeow 查询感知补全（列/别名建议）需要
			"regex",
			"comment",
			"query",
		}

		-- 安装解析器
		require("nvim-treesitter").install(ensure_installed)
		heal_query_links()

		-- 启用高亮、折叠、缩进等功能
		vim.api.nvim_create_autocmd("FileType", {
			pattern = ensure_installed,
			callback = function(args)
				local buf = args.buf
				local winid = vim.api.nvim_get_current_win()
				vim.treesitter.start(buf)
				-- 折叠用 manual：不再每编辑重算 treesitter foldexpr（2720 行实测 1.08ms/edit
				-- vs manual 0.21ms）。代价：不再自动按函数折叠，需要时用 zf/zF 手建，
				-- zc/zo/za/zR/zM 仍可用。
				vim.wo[winid].foldmethod = "manual"
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
			end,
		})
	end,
}
