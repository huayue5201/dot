-- 保存时自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*.txt", "*.lua", "*.js", "*.py" },
	desc = "保存前自动删除行尾空格",
	command = "%s/\\s\\+$//e",
})

-- 恢复上次光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "打开文件时恢复上次光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = "*",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		if #lines > 0 and mark[1] > 0 and mark[1] <= #lines then
			vim.schedule(function()
				pcall(vim.api.nvim_win_set_cursor, 0, mark)
			end)
		end
	end,
})

-- =============================================
-- 快捷键映射配置
-- =============================================

-- 文件类型特定的快捷键映射
local buf_keymaps = require("utils.utils").buf_keymaps
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型设置按键",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local set_markers = vim.b.keymaps_set or {}

		for key, configs in pairs(buf_keymaps) do
			local conf = configs[ft]
			if conf and not set_markers[key] then
				local opts = { buffer = true, silent = true, noremap = true, nowait = true }
				if type(conf.cmd) == "function" then
					vim.keymap.set("n", key, conf.cmd, opts)
				else
					vim.keymap.set("n", key, function()
						vim.cmd(conf.cmd)
					end, opts)
				end
				set_markers[key] = true
			end
		end

		vim.b.keymaps_set = set_markers
	end,
})

local buffer_settings = require("utils.utils").settings
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型/缓冲区类型应用",
	group = vim.api.nvim_create_augroup("CustomBufferSettings", { clear = true }),
	callback = function(args)
		local buf = args.buf
		local ft = vim.bo[buf].filetype
		local bt = vim.bo[buf].buftype
		-- 选择优先 filetype，其次 buftype
		local kind = (ft ~= "" and ft) or bt
		-- 匹配 filetype/buftype
		if buffer_settings[kind] then
			buffer_settings[kind].setup()
		end
	end,
})
