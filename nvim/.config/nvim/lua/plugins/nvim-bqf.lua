-- https://github.com/kevinhwang91/nvim-bqf

return {
	"kevinhwang91/nvim-bqf",
	ft = "qf",
	dependencies = {
		"junegunn/fzf",
		build = function()
			vim.fn["fzf#install"]()
		end,
	},
	config = function()
		local fn = vim.fn

		-- 定义函数 qftf，用于生成快速fix列表项的文本
		function _G.qftf(info)
			local items
			local ret = {}
			if info.quickfix == 1 then
				items = fn.getqflist({ id = info.id, items = 0 }).items
			else
				items = fn.getloclist(info.winid, { id = info.id, items = 0 }).items
			end
			local limit = 31
			local fnameFmt1, fnameFmt2 = "%-" .. limit .. "s", "…%." .. (limit - 1) .. "s"
			local validFmt = "%s │%5d:%-3d│%s %s"
			for i = info.start_idx, info.end_idx do
				local e = items[i]
				local fname = ""
				local str
				if e.valid == 1 then
					if e.bufnr > 0 then
						fname = fn.bufname(e.bufnr)
						if fname == "" then
							fname = "[No Name]"
						else
							fname = fname:gsub("^" .. vim.env.HOME, "~")
						end
						if #fname <= limit then
							fname = fnameFmt1:format(fname)
						else
							fname = fnameFmt2:format(fname:sub(1 - limit))
						end
					end
					local lnum = e.lnum > 99999 and -1 or e.lnum
					local col = e.col > 999 and -1 or e.col
					local qtype = e.type == "" and "" or " " .. e.type:sub(1, 1):upper()
					str = validFmt:format(fname, lnum, col, qtype, e.text)
				else
					str = e.text
				end
				table.insert(ret, str)
			end
			return ret
		end

		-- 将 qftf 函数赋值给 vim.o.qftf，以便在 quickfix 窗口中使用
		vim.o.qftf = "{info -> v:lua._G.qftf(info)}"

		-- 设置预览窗口的外观
		vim.cmd([[
hi BqfPreviewBorder guifg=#3e8e2d ctermfg=71
hi BqfPreviewTitle guifg=#3e8e2d ctermfg=71
hi BqfPreviewThumb guibg=#3e8e2d ctermbg=71
hi link BqfPreviewRange Search
]])

		-- 配置 bqf 插件
		require("bqf").setup({
			auto_enable = true, -- 自动启用插件
			auto_resize_height = true, -- 自动调整窗口高度
			preview = {
				win_height = 12, -- 预览窗口高度
				win_vheight = 12,
				delay_syntax = 80, -- 延迟语法高亮时间
				border = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" }, -- 预览窗口边框
				show_title = false, -- 是否显示标题
				should_preview_cb = function(bufnr, qwinid)
					local ret = true
					local bufname = vim.api.nvim_buf_get_name(bufnr)
					local fsize = vim.fn.getfsize(bufname)
					if fsize > 100 * 1024 or bufname:match("^fugitive://") then
						ret = false
					end
					return ret
				end,
			},
			-- 设置快速修复列表操作键映射
			func_map = {
				drop = "o",
				openc = "O",
				split = "<C-s>",
				tabdrop = "<C-t>",
				tabc = "",
				ptogglemode = "z,",
			},
			filter = {
				fzf = {
					action_for = { ["ctrl-s"] = "split", ["ctrl-t"] = "tab drop" },
					extra_opts = { "--bind", "ctrl-o:toggle-all", "--delimiter", "│" },
				},
			},
		})
	end,
}
