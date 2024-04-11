-- lua/util/lsp_config.lua
-- 参考资料:https://vonheikemen.github.io/devlog/tools/neovim-lsp-client-guide/

local M = {}

M.lspSetup = function()
	vim.api.nvim_create_autocmd("LspAttach", {
		desc = "LSP 操作",
		callback = function(event)
			local bufmap = function(mode, lhs, rhs)
				local opts = { buffer = event.buf }
				vim.keymap.set(mode, lhs, rhs, opts)
			end

			-- 在浮动窗口中显示诊断
			bufmap("n", "<leader>p", "<cmd>lua vim.diagnostic.open_float()<cr>")
			-- 跳转到上一个诊断
			bufmap("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<cr>")
			-- 跳转到下一个诊断
			bufmap("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<cr>")
			-- 查看所有诊断
			bufmap("n", "<space>dq", vim.diagnostic.setloclist)
			-- 显示文档信息
			bufmap("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>")
			-- 跳转到定义
			bufmap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>")
			-- 跳转到声明
			bufmap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<cr>")
			-- 列出所有实现
			bufmap("n", "gl", "<cmd>lua vim.lsp.buf.implementation()<cr>")
			-- 跳转到类型定义
			bufmap("n", "gy", "<cmd>lua vim.lsp.buf.type_definition()<cr>")
			-- 列出所有引用
			bufmap("n", "gr", "<cmd>lua vim.lsp.buf.references()<cr>")
			-- 显示函数签名帮助
			bufmap("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<cr>")
			-- 内嵌提示
			bufmap("n", "<leader>i", function()
				vim.lsp.inlay_hint.enable(0, not vim.lsp.inlay_hint.is_enabled(0))
			end)
			-- 重命名
			bufmap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>")
			-- 选择可用的代码操作
			bufmap("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>")
			-- 添加工作区目录
			bufmap("n", "<space>wa", vim.lsp.buf.add_workspace_folder)
			-- 移除工作区目录
			bufmap("n", "<space>wr", vim.lsp.buf.remove_workspace_folder)
			-- 列出工作区目录
			bufmap("n", "<space>wl", function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end)
		end,
	})

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

	-- 文档窗口和签名帮助添加边框
	vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
	vim.lsp.handlers["textDocument/signatureHelp"] =
		vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

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

	vim.api.nvim_create_autocmd("LspAttach", {
		desc = "Setup highlight symbol",
		callback = highlight_symbol,
	})

	-- 打印LSP进度信息
	local function log(msg)
		local client = msg.client or "" -- 获取客户端名称或默认为空字符串
		local title = msg.title or "" -- 获取标题或默认为空字符串
		local message = msg.message or "" -- 获取消息或默认为空字符串
		local percentage = msg.percentage or 0 -- 获取进度百分比或默认为0
		-- 拼接输出字符串
		local out = (client ~= "" and "[" .. client .. "]") or ""
		out = out .. ((percentage > 0) and (" [" .. percentage .. "%]") or "")
		out = out .. ((title ~= "") and (" " .. title) or "")
		out = out .. ((message ~= "") and (" - " .. message) or "")
		vim.api.nvim_command([[echo "]] .. out .. [["]]) -- 在neovim中输出信息
	end
	local series = {} -- 存储进度信息的字典
	vim.lsp.handlers["$/progress"] = function(err, progress, ctx)
		local client = vim.lsp.get_client_by_id(ctx.client_id) -- 获取LSP客户端对象
		local client_name = client.name or "" -- 获取客户端名称或默认为空字符串
		local token = progress.token -- 获取进度令牌
		local value = progress.value -- 获取进度值
		local cur = series[token] or {} -- 获取当前令牌对应的进度信息，如果不存在则创建一个新的表
		cur.client = client_name or cur.client -- 更新客户端名称
		cur.title = value.title or cur.title or "" -- 更新标题
		cur.message = value.message or cur.message or "" -- 更新消息
		cur.percentage = value.percentage or cur.percentage or 0 -- 更新进度百分比
		-- 如果是进度开始
		if value.kind == "begin" then
			cur.message = cur.message .. " - Starting" -- 添加“开始”信息
		end
		-- 如果是进度结束
		if value.kind == "end" then
			cur.message = "Done" -- 添加“完成”信息
			series[token] = nil -- 清除已完成的进度信息
		end
		log(cur) -- 打印当前进度信息
	end
end

return M