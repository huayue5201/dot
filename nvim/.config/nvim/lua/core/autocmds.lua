-- File: ~/dotfiles/nvim/.config/nvim/lua/core/autocmds.lua

local utils = require("user.utils")

-- ============================
-- 通用函数：为当前 buffer 应用快捷键映射
-- ============================
local function apply_keymaps()
	local ft = vim.bo.filetype
	local bt = vim.bo.buftype
	local bufname = vim.fn.bufname("%")
	local applied = vim.b.keymaps_applied or {}

	-- 确定当前窗口的类型标识（优先级：filetype > buftype > 特殊匹配）
	local buf_type = ft ~= "" and ft or bt

	for key, type_configs in pairs(utils.buf_keymaps) do
		-- 跳过已映射的按键
		if not applied[key] then
			-- 获取配置（精确匹配 或 dap-repl 特殊处理）
			local config = type_configs[buf_type]

			if not config and bufname:match("dap%-repl") then
				config = type_configs["dap-repl"]
			end

			-- 如果有配置，应用映射
			if config and config.cmd then
				local cmd = config.cmd
				local desc = config.desc or ("映射: " .. key)

				-- 根据命令类型创建映射函数
				local map_func = (cmd == "next_error" or cmd == "prev_error")
						and function()
							utils.dispatch_command(cmd)
						end
					or function()
						utils.dispatch_command(cmd)
					end

				vim.keymap.set("n", key, map_func, {
					buffer = true,
					silent = true,
					noremap = true,
					nowait = true,
					desc = desc,
				})

				applied[key] = true
			end
		end
	end

	vim.b.keymaps_applied = applied
end

-- ============================
-- 注册自动命令
-- ============================

-- 快捷键映射：当进入 buffer 或切换文件类型时应用
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	desc = "根据配置表自动应用窗口快捷键",
	callback = apply_keymaps,
})

-- 其他 autocmd（保持你原来的）
vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("RemoveTrailingWhitespace", { clear = true }),
	desc = "保存前自动删除行尾空格",
	callback = function()
		vim.cmd([[%s/\s\+$//e]])
	end,
})

vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("DisableCommentContinuation", { clear = true }),
	desc = "禁止换行自动继承注释效果",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

-- Buffer 设置
local buffer_settings = utils.settings
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("CustomBufferSettings", { clear = true }),
	desc = "根据配置表自动应用 buffer 设置",
	callback = function(args)
		local buf = args.buf
		local ft = vim.bo[buf].filetype
		local bt = vim.bo[buf].buftype
		local kind = (ft ~= "" and ft) or bt

		if buffer_settings[kind] and buffer_settings[kind].setup then
			buffer_settings[kind].setup()
		end
	end,
})

-- ============================
-- 用户命令
-- ============================
vim.api.nvim_create_user_command("SmartClose", function()
	utils.smart_close()
end, { desc = "智能关闭当前窗口" })

vim.api.nvim_create_user_command("NextError", function()
	utils.next_error()
end, { desc = "跳转到下一个错误" })

vim.api.nvim_create_user_command("PrevError", function()
	utils.prev_error()
end, { desc = "跳转到上一个错误" })
