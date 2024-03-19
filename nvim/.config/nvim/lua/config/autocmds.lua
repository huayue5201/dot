-- 创建一个自动命令，当文件类型为 "markdown" 时执行
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown", -- 文件类型为 Markdown
	callback = function()
		-- 在插入模式下，将回车键 (`<CR>`) 添加到 `formatoptions` 选项中
		vim.opt_local.formatoptions:append("r")
		-- 在普通模式下，将 `o` 添加到 `formatoptions` 选项中
		vim.opt_local.formatoptions:append("o")
		-- 设置注释模式为特定的列表
		vim.opt_local.comments = {
			"b:- [ ]", -- 未完成的任务列表项
			"b:- [x]", -- 已完成的任务列表项
			"b:*", -- 无序列表
			"b:-", -- 其他注释标记
			"b:+",
		}
	end,
})

-- 保存时自动格式话
-- 1
-- vim.api.nvim_create_autocmd("LspAttach", {
-- 	group = vim.api.nvim_create_augroup("lsp", { clear = true }),
-- 	callback = function(args)
-- 		-- 2
-- 		vim.api.nvim_create_autocmd("BufWritePre", {
-- 			-- 3
-- 			buffer = args.buf,
-- 			callback = function()
-- 				-- 4 + 5
-- 				vim.lsp.buf.format({ async = false, id = args.data.client_id })
-- 			end,
-- 		})
-- 	end,
-- })

-- 光标自动定位到最后编辑的位置
-- 在 BufReadPost 事件后执行命令，将光标定位到上次编辑的位置
vim.api.nvim_create_autocmd("BufReadPost", {
	command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]],
})

-- 换行不要延续注释符号
-- 在 BufEnter 事件后执行命令，设置不延续注释符号的格式选项
vim.api.nvim_create_autocmd("BufEnter", { command = [[set formatoptions-=cro]] })

-- 用q关闭窗口
-- 根据 FileType 设置不同的文件类型的快捷键，以关闭窗口
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "help", "startuptime", "qf", "lspinfo" },
	command = [[nnoremap <buffer><silent> q :close<CR>]],
})
vim.api.nvim_create_autocmd("FileType", {
	pattern = "man",
	command = [[nnoremap <buffer><silent> q :quit<CR>]],
})

-- 仅在活动窗口显示光标线
-- 创建光标线高亮组，根据 InsertLeave 和 WinEnter 事件设置是否显示光标线
local cursorGrp = vim.api.nvim_create_augroup("CursorLine", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
	pattern = "*",
	command = "set cursorline",
	group = cursorGrp,
})
vim.api.nvim_create_autocmd(
	{ "InsertEnter", "WinLeave" },
	{ pattern = "*", command = "set nocursorline", group = cursorGrp }
)

--- 保存时删除所有尾随空格
-- 在 BufWritePre 事件前执行命令，删除尾随空格
local TrimWhiteSpaceGrp = vim.api.nvim_create_augroup("TrimWhiteSpaceGrp", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
	command = [[:%s/\s\+$//e]],
	group = TrimWhiteSpaceGrp,
})

-- 创建高亮组并添加 TextYankPost 自动命令
-- 在 TextYankPost 事件后执行回调函数，高亮复制的文本
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- 根据特定的按键在 Normal 模式下切换 hlsearch
local function in_normal_mode()
	return vim.fn.mode() == "n"
end
local function toggle_hlsearch(char)
	-- 只在 Normal 模式下执行
	if not in_normal_mode() then
		return
	end
	local toggle_keys = { "<CR>", "n", "N", "*", "#", "?", "/" }
	local should_toggle = vim.tbl_contains(toggle_keys, vim.fn.keytrans(char))
	-- 获取当前 hlsearch 的状态
	local hlsearch_enabled = vim.opt.hlsearch:get()
	-- 如果需要切换 hlsearch，则设置
	if hlsearch_enabled ~= should_toggle then
		vim.opt.hlsearch = should_toggle
	end
end
-- 注册切换 hlsearch 的按键处理函数
vim.on_key(toggle_hlsearch, vim.api.nvim_create_namespace("toggle_hlsearch"))
