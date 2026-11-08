-- https://github.com/Zeioth/markmap.nvim
-- 把当前 markdown 文件渲染成思维导图（markmap → HTML，用浏览器打开）。
-- 外部依赖：可执行文件 `markmap`（markmap-cli），本机已 `npm i -g markmap-cli` 装好，
-- 所以不需要插件 README 里那步 `yarn global add markmap-cli`（build 字段就省略了）。
-- 命令：:MarkmapOpen（打开）:MarkmapSave（只生成 html）:MarkmapWatch（改动即刷新）
--       :MarkmapWatchStop，`:checkhealth markmap` 可查依赖是否齐。
--
-- 只在 markdown buffer 挂键位（插件不校验 ft，在别的文件里按会把任意文件当 md 渲染），
-- 并且 `markmap` 不在 PATH 时干脆不挂（jobstart 失败只会丢一条 shell 错误，没有提示）。
return {
	"Zeioth/markmap.nvim",
	sem_version = "*",
	opts = {
		-- 空字符串 = 跟当前文件同目录同名 .html；这里固定写到 /tmp，避免污染笔记仓库
		html_output = "/tmp/markmap.html",
		hide_toolbar = false,
	},
	config = function(_, opts)
		require("markmap").setup(opts)

		if vim.fn.executable("markmap") == 0 then
			vim.notify(
				"markmap: 未找到 markmap 可执行文件（npm i -g markmap-cli），相关键位不注册",
				vim.log.levels.WARN
			)
			return
		end

		local maps = {
			{ key = "<localleader>mm", cmd = "MarkmapOpen", desc = "Markmap: 打开思维导图" },
			{ key = "<localleader>mw", cmd = "MarkmapWatch", desc = "Markmap: 打开并实时刷新" },
			{ key = "<localleader>ms", cmd = "MarkmapSave", desc = "Markmap: 只保存 html" },
			{ key = "<localleader>mS", cmd = "MarkmapWatchStop", desc = "Markmap: 停止刷新" },
		}

		local function install(buf)
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local is_md = vim.bo[buf].filetype == "markdown"
			for _, m in ipairs(maps) do
				pcall(vim.keymap.del, "n", m.key, { buffer = buf })
				if is_md then
					vim.keymap.set("n", m.key, "<cmd>" .. m.cmd .. "<cr>", {
						buffer = buf,
						desc = m.desc,
					})
				end
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("markmap_ft_guard", { clear = true }),
			-- 不限定 pattern：ft 从 markdown 切走时也要把旧键位清掉
			callback = function(event)
				install(event.buf)
			end,
		})

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				install(buf)
			end
		end
	end,
}
