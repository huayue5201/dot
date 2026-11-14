-- lua/lsp_ext/autocmds.lua
---@brief 所有 LSP 相关 autocmd 的注册中心
---@diagnostic disable: need-check-nil
local M = {}

local keys = require("lsp_ext.keys")
local registry = require("lsp_ext.registry")
local servers = require("lsp_ext.servers")
local state = require("lsp_ext.state")
local ctx = require("lib.context")

-- 缓存调试状态，热路径不再反复读 vim.g
local debug_active = ctx.is_debug()

-- 存储当前缓冲区的状态
local buffer_states = {}

---------------------------------------------------------
-- 插入/选择模式禁用/启用诊断
---------------------------------------------------------
local function auto_diagnostic()
	vim.api.nvim_create_autocmd("ModeChanged", {
		-- 必须归组 clear：setup() 在 :ConfigReload 时会再跑一遍，不 clear 就叠加成
		-- 两个回调，诊断被禁/启用两次
		group = vim.api.nvim_create_augroup("LspAutoDiagnostic", { clear = true }),
		pattern = { "n:i", "v:s", "i:n", "s:v" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function(args)
			local bufnr = args.buf
			local mode = vim.fn.mode()

			-- 如果调试处于活动状态，不做任何操作
			if debug_active then
				return
			end

			-- 诊断功能不需要检查客户端支持，因为 vim.diagnostic 是 Neovim 内置功能
			local diagnostics_enabled = state.get("lsp.diagnostics", bufnr)

			-- 只在诊断启用时才进行切换
			if diagnostics_enabled then
				if mode == "i" or mode == "s" or mode == "v" then
					-- 进入插入或选择模式
					vim.diagnostic.enable(false, { bufnr = bufnr })
					buffer_states[bufnr] = buffer_states[bufnr] or {}
					buffer_states[bufnr].diagnostics_enabled = false
				else
					-- 退出插入或选择模式
					vim.diagnostic.enable(true, { bufnr = bufnr })
					buffer_states[bufnr] = buffer_states[bufnr] or {}
					buffer_states[bufnr].diagnostics_enabled = true
				end
			end
		end,
	})
end

---------------------------------------------------------
-- 应用当前缓冲区的设置
---------------------------------------------------------
local function apply_buffer_settings(bufnr)
	-- 调试中：强制禁用 LSP 功能
	if debug_active then
		vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		vim.diagnostic.enable(false, { bufnr = bufnr })
		buffer_states[bufnr] = buffer_states[bufnr] or {}
		buffer_states[bufnr].inlay_hint_enabled = false
		buffer_states[bufnr].diagnostics_enabled = false
		return
	end

	local inlay_hint_enable = state.get("lsp.inlay_hints", bufnr)
	local diagnostics_enabled = state.get("lsp.diagnostics", bufnr)

	buffer_states[bufnr] = buffer_states[bufnr] or {}

	if inlay_hint_enable then
		vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		buffer_states[bufnr].inlay_hint_enabled = true
	else
		vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		buffer_states[bufnr].inlay_hint_enabled = false
	end

	if diagnostics_enabled then
		vim.diagnostic.enable(true, { bufnr = bufnr })
		buffer_states[bufnr].diagnostics_enabled = true
	else
		vim.diagnostic.enable(false, { bufnr = bufnr })
		buffer_states[bufnr].diagnostics_enabled = false
	end
end

---------------------------------------------------------
-- 处理设置变化
---------------------------------------------------------
local function setup_settings_watcher()
	-- 监听设置变化（nvim-store3 set 事件），跨项目实例自动接入
	state.subscribe(function(key, value)
		if debug_active then
			return
		end

		if key ~= "lsp.inlay_hints" and key ~= "lsp.diagnostics" then
			return
		end

		-- 兼容历史字符串值
		local enabled = value
		if type(value) == "string" then
			enabled = value == "on" or value == "active" or value == "enabled"
		end

		for _, client in ipairs(vim.lsp.get_clients()) do
			-- attached_buffers 是 table<integer,string>（bufnr -> languageId）：
			-- 用 ipairs 会把 languageId 字符串当 bufnr 传下去，直接抛
			-- "buf: expected number, got string"
			for bufnr in pairs(client.attached_buffers or {}) do
				if key == "lsp.inlay_hints" then
					vim.lsp.inlay_hint.enable(enabled, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].inlay_hint_enabled = enabled
					end
				else
					vim.diagnostic.enable(enabled, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].diagnostics_enabled = enabled
					end
				end
			end
		end
	end)
end

---------------------------------------------------------
-- LspAttach
---------------------------------------------------------
local function setup_lsp_attach()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			local bufnr = args.buf
			local client = vim.lsp.get_client_by_id(args.data.client_id)

			-- 按键映射
			keys.attach(bufnr)

			-- 代码透镜（▶ Run / ▶ Debug 等）：0.13 起默认不渲染，交给本模块自行请求/渲染，
			-- 以支持“悬停高亮 + 点击运行”（原生渲染的高亮组是硬编码的）。
			require("lsp_ext.features.code_lens").setup(client, bufnr)

			-- Rust 宏展开预览（setup 内部自行守卫：仅 rust-analyzer + 支持 expandMacro）
			require("lsp_ext.features.rust_macro_preview").setup(client, bufnr)

			-- Rust 结构化替换（setup 内部自行守卫：仅 rust-analyzer + 支持 experimental/ssr）
			require("lsp_ext.features.rust_ssr").setup(client, bufnr)

			-- Rust runnable/debuggable：补齐 ▶ Run / ▶ Debug 代码透镜与运行/调试快捷键
			require("lsp_ext.features.runnables").setup(client, bufnr)

			-- LSP UTF-8 守卫：发送前扫描 params，发现非法 UTF-8 就替换为 U+FFFD 并告警。
			-- 背景：rust-analyzer 收到非法 UTF-8 报文会直接 run_session 报错退出
			-- （invalid utf-8 sequence ...），didOpen/didChange 又是广播给所有 client 的。
			-- 详见模块头部注释。幂等，多次 LspAttach 只会包一次。
			require("lsp_ext.features.utf8_guard").setup(client)

			-- 应用当前缓冲区的持久化设置
			apply_buffer_settings(bufnr)

			-- 索引未完成时首次请求会回空，defer 兜底补取一次（不依赖 server 发 progress）
			vim.defer_fn(function()
				if M.refresh_after_ready then
					M.refresh_after_ready(client.id)
				end
			end, 3000)

			-- 文档颜色
			if client:supports_method("textDocument/colorProvider") then
				vim.lsp.document_color.enable(true, {
					bufnr = bufnr,
				}, {
					style = "virtual",
				})
			end

			-- 链接编辑范围
			if client:supports_method("textDocument/linkedEditingRange") then
				vim.lsp.linked_editing_range.enable(true, { client_id = client.id, bufnr = bufnr })
			end

			-- workspace 级诊断改为按需：不再在 LspAttach 时自动扫描整个项目
			-- （rust-analyzer 会因此触发全 workspace 检查/等待 flycheck，代价很大）。
			-- 现在由 `grD` → lsp_ext/actions.lua:open_all_diagnostics 显式触发。
		end,
	})
end

---------------------------------------------------------
-- server 就绪后补取内联提示 / 代码透镜
---------------------------------------------------------
-- 问题：LspAttach 时 server 往往还没建完索引，首次 textDocument/inlayHint 与
-- textDocument/codeLens 请求会拿到空结果，而 Neovim 不会自动重试。表现为：打开 rust
-- 文件后内联提示、代码透镜是关闭状态，直到某次插入模式切换/写入触发新的请求。
-- 这里监听 $/progress 的 end 事件（rust-analyzer 的 Indexing / Roots Scanned 等），
-- 把空结果补取一次；再加一个 defer 兜底，防止 server 根本不发 progress。
local function setup_ready_refresh()
	local group = vim.api.nvim_create_augroup("UserLspReadyRefresh", { clear = true })
	local timers = {}

	--- 仅在“本该有内容却没有”时重取，避免反复请求
	---@param bufnr integer
	local function refresh_buffer(bufnr)
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
			local ok, hints = pcall(vim.lsp.inlay_hint.get, { bufnr = bufnr })
			if not (ok and #hints > 0) then
				-- 索引未完成时首次请求会回空：关掉再开一次，逼核心重新请求
				vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
				vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				buffer_states[bufnr] = buffer_states[bufnr] or {}
				buffer_states[bufnr].inlay_hint_enabled = true
			end
		end

		local ok, code_lens = pcall(require, "lsp_ext.features.code_lens")
		if ok then
			code_lens.schedule_refresh(bufnr)
		end
	end

	--- 对某个 client 的所有 buffer 做一次补取（同一 client 去抖）
	---@param client_id integer
	local function refresh_client(client_id)
		if timers[client_id] then
			return
		end
		timers[client_id] = true
		vim.defer_fn(function()
			timers[client_id] = nil
			local client = vim.lsp.get_client_by_id(client_id)
			if not client then
				return
			end
			for bufnr in pairs(client.attached_buffers or {}) do
				refresh_buffer(bufnr)
			end
		end, 200)
	end

	M.refresh_after_ready = refresh_client

	vim.api.nvim_create_autocmd("LspProgress", {
		group = group,
		desc = "server 索引进度结束时补取内联提示/代码透镜",
		callback = function(args)
			local data = args.data or {}
			local value = data.params and data.params.value
			if not value or value.kind ~= "end" or not data.client_id then
				return
			end
			refresh_client(data.client_id)
		end,
	})
end

--- FileType autocmd 必须在配置重载后重建：pattern 是 setup 时算好的一份快照
local function setup_filetype_autocmd()
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("LspFileType", { clear = true }),
		desc = "根据文件类型启动或停止 LSP",
		pattern = registry.get_lsp_config("filetypes"),
		callback = function(args)
			servers.apply_for_buffer(args.buf)
		end,
	})
end

---------------------------------------------------------
-- 注册全部 autocmd
---------------------------------------------------------
function M.setup()
	-- 模式切换时临时开关诊断
	auto_diagnostic()

	-- 设置变化监听器
	setup_settings_watcher()

	-- server 索引完成后补取内联提示 / 代码透镜
	setup_ready_refresh()

	-- 调试状态变化时重新应用所有已知 buffer 的设置
	ctx.on_debug_change(function(active)
		debug_active = active
		for bufnr in pairs(buffer_states) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				apply_buffer_settings(bufnr)
			end
		end
	end)

	-- FileType：按项目状态启停 server
	-- 独立成函数是因为 lsp/*.lua 热重载后 pattern 必须重建（见下面的 BufWritePost）
	setup_filetype_autocmd()

	-- LSP 客户端附加
	setup_lsp_attach()

	-- 缓冲区级 UTF-8 守卫：在非法字节进入 buffer 后就地修复，
	-- 保证 client 内部文档与 buffer 一致（避免 range 落在字符中间导致 server panic）。
	require("lsp_ext.features.utf8_guard").setup_buffer_guard()

	-- 缓冲区卸载时清理状态
	vim.api.nvim_create_autocmd("BufUnload", {
		callback = function(args)
			buffer_states[args.buf] = nil
		end,
	})

	-- lsp/*.lua 改动后重载配置
	vim.api.nvim_create_autocmd("BufWritePost", {
		-- 注意：pattern 里带 "/" 时 Vim 拿完整路径匹配，"lsp/*.lua" 只能匹配相对路径，
		-- 实际编辑 /Users/…/lsp/foo.lua 永远不触发
		pattern = { "**/lsp/*.lua", "**/after/lsp/*.lua" },
		group = vim.api.nvim_create_augroup("LSPConfigAutoReload", { clear = true }),
		callback = function()
			local _, count = registry.reload_lsp_configs()
			-- 光刷缓存不够：FileType pattern 与已开 buffer 的 server 都是旧快照
			setup_filetype_autocmd()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
					pcall(servers.apply_for_buffer, buf)
				end
			end
			vim.notify(string.format("LSP configurations reloaded (%d configs total)", count), vim.log.levels.INFO)
		end,
	})
end

--- 按「当前 buffer 该是什么状态」重算开关。
--- 调试结束时由 lua/dap_ext/dap_keys.lua 调用：原来那里直接 vim.diagnostic.enable(true)
--- 全局打开，会把用户在特定项目里关掉的诊断/内联提示全部复活。
function M.refresh()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			apply_buffer_settings(buf)
		end
	end
end

return M
