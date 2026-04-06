-- 保存时自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*" },
	desc = "保存前自动删除行尾空格",
	command = "%s/\\s\\+$//e",
})

-- 恢复上次光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	group = vim.api.nvim_create_augroup("RestoreCursor", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype
		if ft == "commit" or ft == "xxd" or ft == "gitrebase" or vim.wo.diff then
			return
		end
		local last_pos = vim.fn.line([['"]])
		local last_line = vim.fn.line("$")
		if last_pos >= 1 and last_pos <= last_line then
			vim.cmd([[normal! g`"]])
		end
	end,
})

vim.api.nvim_create_user_command("SmartClose", function()
	require("user.utils").smart_close()
end, {})

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank({
			higroup = "Visual",
			timeout = 300,
		})
	end,
})

local ns = vim.api.nvim_create_namespace("hl_on_paste")
vim.paste = (function(overridden)
	return function(lines, phase)
		local ret = overridden(lines, phase)
		vim.hl.range(0, ns, "Visual", "'[", "']", { timeout = 300 })
		return ret
	end
end)(vim.paste)
-- =============================================
-- 快捷键映射配置
-- =============================================
local utils = require("user.utils")
local buf_keymaps = utils.buf_keymaps

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型设置按键",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local bufname = vim.fn.bufname("%")
		local set_markers = vim.b.keymaps_set or {}

		for key, configs in pairs(buf_keymaps) do
			-- 只判断是否需要绑定按键，不再处理关闭逻辑
			local conf = configs[ft]

			if not conf and bufname:match("dap%-repl") then
				conf = configs["dap-repl"]
			end

			if conf and not set_markers[key] then
				vim.keymap.set("n", key, function()
					utils.smart_close()
				end, { buffer = true, silent = true, noremap = true, nowait = true })

				set_markers[key] = true
			end
		end

		vim.b.keymaps_set = set_markers
	end,
})

local buffer_settings = require("user.utils").settings
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

-- vim.api.nvim_create_autocmd("LspProgress", {
-- 	buffer = buf,
-- 	callback = function(ev)
-- 		local value = ev.data.params.value
-- 		vim.api.nvim_echo({ { value.message or "done" } }, false, {
-- 			id = "lsp." .. ev.data.client_id,
-- 			kind = "progress",
-- 			source = "vim.lsp",
-- 			title = value.title,
-- 			status = value.kind ~= "end" and "running" or "success",
-- 			percent = value.percentage,
-- 		})
-- 	end,
-- })
