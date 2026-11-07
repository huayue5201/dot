-- https://github.com/jmbuhr/otter.nvim
--
-- 注意：加载器是 eager 的，插件一启动就加载，此时当前 buffer 还不是 markdown。
-- 所以 activate() 不能无条件调用（否则会报 "No treesitter parser found for current
-- buffer. Can't activate."），改成挂在宿主 filetype 上，语义和以前 `ft = ...` 懒加载一致。

-- 宿主 filetype：这些 buffer 里的代码块要接入 LSP。
-- codecompanion = CodeCompanion 聊天缓冲区（ft 为 codecompanion，内容就是 markdown，
-- nvim 已把它映射到 markdown 解析器，所以 otter 能直接看出 ```rust / ```lua 代码块）。
local host_fts = { "markdown", "quarto", "rmd", "codecompanion" }

-- 允许激活的「无名字 nofile」宿主：只有聊天缓冲区。其它 nofile 的 markdown
-- （LSP hover 浮窗、todo2 预览、其它 peek）一律不激活。
local nofile_host_fts = { "codecompanion" }

return {
	"jmbuhr/otter.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		local otter = require("otter")
		otter.setup()

		-- 嵌入语言：markdown 代码块里要激活的语言
		-- 参数：languages, completion, diagnostics, tsquery
		-- 已知限制：rust 拿不到分析。raft 是虚拟文件（xxx.md.otter.rs，磁盘上不存在，
		-- 也不在 crate 模块树里），rust-analyzer 把它当归 unlinked file（项目内 root 正确时）
		-- 或 root=nil（无 workspace 时），hover/补全都返回 null。lua / python 的 raft 正常。
		local function activate()
			otter.activate({ "python", "lua", "rust" }, true, false, nil)
		end

		--- 只给「真正的文档」激活：
		--- - 有名字的普通文件（bt == "")：markdown / quarto / rmd 文件；
		--- - CodeCompanion 聊天缓冲区：bt=nofile、无名字，但内容确实是 markdown。
		--- 关键排除项：LSP hover 浮窗的 buffer 也是 ft=markdown（bt=nofile、无名字），
		--- 在上面 activate 会为浮窗里的 ```rust 代码块建一个 `.otter.rs` 影子 buffer
		--- （bt=""、modified=true），并额外起一个 rust-analyzer + 一个 otter-ls client。
		--- 表现就是「按 K 后 LSP 像重新加载了一遍」+「hover 进了未保存清单」。
		--- 同理排除其它预览类 markdown 浮窗（todo2 预览等）。
		---@param bufnr integer
		---@return boolean
		local function should_activate(bufnr)
			if vim.bo[bufnr].buftype == "" then
				return vim.api.nvim_buf_get_name(bufnr) ~= ""
			end
			return vim.tbl_contains(nofile_host_fts, vim.bo[bufnr].filetype)
		end

		--- CodeCompanion 的聊天缓冲区是「边聊边出现」的：FileType 时 buffer 还是空的，
		--- otter.activate 因为一个代码块都找不到会直接返回（源码 init.lua:146 的
		--- `if #languages == 0 then return end`），之后也不会自己重试。
		--- 所以内容变化后再试一次，直到 otter 真的建出 raft（languages 非空）为止。
		--- 注意用 nvim_buf_attach 而不是 TextChanged：CodeCompanion 是用 API
		--- （nvim_buf_set_lines）写内容的，TextChanged 对 API 改动不触发，on_lines 才触发。
		---@param bufnr integer
		local function activate_when_ready(bufnr)
			local keeper = require("otter.keeper")
			local function activated()
				local raft = keeper.rafts and keeper.rafts[bufnr]
				return raft ~= nil and raft.languages ~= nil and #raft.languages > 0
			end
			if activated() then
				return
			end
			local timer
			vim.api.nvim_buf_attach(bufnr, false, {
				on_lines = function()
					if activated() then
						return true -- 已激活：解绑
					end
					if not timer then
						timer = vim.defer_fn(function()
							timer = nil
							if not vim.api.nvim_buf_is_valid(bufnr) or activated() then
								return
							end
							vim.api.nvim_buf_call(bufnr, activate)
						end, 400)
					end
					return false
				end,
			})
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = host_fts,
			group = vim.api.nvim_create_augroup("OtterActivate", { clear = true }),
			callback = function(args)
				if not should_activate(args.buf) then
					return
				end
				if vim.api.nvim_get_current_buf() == args.buf then
					activate()
				else
					vim.api.nvim_buf_call(args.buf, activate)
				end
				activate_when_ready(args.buf)
			end,
			desc = "markdown 等宿主文件里激活嵌入语言",
		})

		if vim.tbl_contains(host_fts, vim.bo.filetype) and should_activate(vim.api.nvim_get_current_buf()) then
			activate()
		end
	end,
}
