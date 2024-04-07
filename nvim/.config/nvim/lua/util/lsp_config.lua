-- lua/util/lsp_config.lua

-- 参考资料:https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/

local M = {}

M.lspSetup = function()
	-- 配置诊断显示方式
	vim.diagnostic.config({
		-- virtual_text = false,
		virtual_text = {
			source = "always", -- 总是显示虚拟文本
			prefix = "■", -- 虚拟文本前缀为方块
			severity = {
				min = vim.diagnostic.severity.ERROR, -- 只显示错误级别的虚拟文本
			},
		},
		float = {
			source = "always", -- 总是显示浮动窗口
			border = "rounded", -- 浮动窗口边框为圆角
		},
		signs = false, -- 显示诊断标记
		-- signs = {
		-- 	text = {
		-- 		[vim.diagnostic.severity.ERROR] = "✘",
		-- 		[vim.diagnostic.severity.WARN] = "▲",
		-- 		[vim.diagnostic.severity.HINT] = "⚑",
		-- 		[vim.diagnostic.severity.INFO] = "»",
		-- 	},
		-- },
		underline = true, -- 对诊断信息使用下划线
		update_in_insert = false, -- 插入模式下不更新诊断信息
		severity_sort = true, -- 按严重性对诊断进行排序
	})

	-- 插入后立刻禁用诊断,正常是插入键入文本后才会禁用诊断
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s" },
		desc = "Disable diagnostics in insert and select mode",
		callback = function(e)
			vim.diagnostic.disable(e.buf)
		end,
	})

	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = "i:n",
		desc = "Enable diagnostics when leaving insert mode",
		callback = function(e)
			vim.diagnostic.enable(e.buf)
		end,
	})

	-- 关键字高亮,由lsp提供
	vim.api.nvim_set_hl(0, "LspReferenceRead", { link = "Search" })
	vim.api.nvim_set_hl(0, "LspReferenceText", { link = "Search" })
	vim.api.nvim_set_hl(0, "LspReferenceWrite", { link = "Search" })

	local function highlight_symbol(event)
		local id = vim.tbl_get(event, "data", "client_id")
		local client = id and vim.lsp.get_client_by_id(id)
		if client == nil or not client.supports_method("textDocument/documentHighlight") then
			return
		end

		local group = vim.api.nvim_create_augroup("highlight_symbol", { clear = false })

		vim.api.nvim_clear_autocmds({ buffer = event.buf, group = group })

		vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
			group = group,
			buffer = event.buf,
			callback = vim.lsp.buf.document_highlight,
		})

		vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
			group = group,
			buffer = event.buf,
			callback = vim.lsp.buf.clear_references,
		})
	end

	-- 设置键映射
	keymap("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "代码错误列表" })
	keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "跳转到前一个错误" })
	keymap("n", "]d", vim.diagnostic.goto_next, { desc = "跳转到下一个错误" })
	keymap("n", "<leader>p", vim.diagnostic.open_float, { desc = "打开浮动窗口查看错误信息" })

	-- 创建 LspAttach 事件的自动命令
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspConfig", {}), -- 创建自动命令组
		callback = function(event)
			-- 调用highlight_symbol函数
			highlight_symbol(event)
			-- 启用 <C-x><C-o> 触发的补全
			vim.bo[event.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
			-- 按键键映射
			local bufmap = function(mode, lhs, rhs)
				local opt = { buffer = event.buf }
				vim.keymap.set(mode, lhs, rhs, opts)
			end
			-- 设置缓冲区本地键映射
			bufmap("n", "gd", vim.lsp.buf.definition, { desc = "跳转到定义", unique = false })
			bufmap("n", "gD", vim.lsp.buf.declaration, { desc = "跳转到声明", unique = false })
			bufmap("n", "gy", vim.lsp.buf.type_definition, { desc = "跳转到类型定义" })
			bufmap("n", "gl", vim.lsp.buf.implementation, { desc = "跳转到接口实现" })
			bufmap("n", "gr", vim.lsp.buf.references, { desc = "查找所有引用" })
			-- bufmap("n", "K", vim.lsp.buf.hover, { desc = "显示悬停信息" }, )
			bufmap("n", "<leader>ih", function()
				vim.lsp.inlay_hint.enable(event.buf, not vim.lsp.inlay_hint.is_enabled())
			end, { desc = "内嵌提示" })
			bufmap({ "n", "i" }, "<c-k>", vim.lsp.buf.signature_help, { desc = "显示函数签名帮助" })
			bufmap({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "执行代码操作" })
			bufmap({ "n", "v" }, "<leader>rn", vim.lsp.buf.rename, { desc = "重命名符号" })
			bufmap("n", "<leader>aw", vim.lsp.buf.add_workspace_folder, { desc = "添加工作区目录" })
			bufmap("n", "<leader>rw", vim.lsp.buf.remove_workspace_folder, { desc = "移除工作区目录" })
			bufmap("n", "<leader>wl", function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, { desc = "列出工作区目录" })
			-- bufmap("n", "<S-A-f>", function()
			--     vim.lsp.buf.format({ async = true })
			-- end, { desc = "代码格式化" }, )
		end,
	})
end

return M
