-- https://rust-analyzer.github.io/book/index.html

local uv = vim.uv or vim.loop

-- 安全读取文件
local function read_file(path)
	local fd = uv.fs_open(path, "r", 420)
	if not fd then
		return nil
	end

	local stat = uv.fs_fstat(fd)
	if not stat then
		uv.fs_close(fd)
		return nil
	end

	local data = uv.fs_read(fd, stat.size, 0)
	uv.fs_close(fd)
	return data
end

-- 判断是否为嵌入式 Rust 项目
local function detect_embedded_target(root_dir)
	-- 检查 .cargo/config.toml
	for _, fname in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
		local content = read_file(vim.fs.joinpath(root_dir, fname))
		if content then
			local target = content:match('target%s*=%s*"(.-)"')
			if target and (target:match("thumb") or target:match("riscv") or target:match("arm")) then
				return target
			end
		end
	end

	-- 检查 target/ 目录
	local target_dir = vim.fs.joinpath(root_dir, "target")
	local handle = uv.fs_scandir(target_dir)
	if handle then
		while true do
			local name = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			if name:match("^thumb") or name:match("^riscv") or name:match("^arm") then
				return name
			end
		end
	end

	-- 检查 Cargo.toml 中的依赖
	local cargo_toml = read_file(vim.fs.joinpath(root_dir, "Cargo.toml"))
	if cargo_toml then
		-- 简单的关键词匹配，如果有 toml 解析库会更准确
		local embedded_patterns = {
			"embedded%-hal",
			"embassy%-",
			"defmt%-rt",
			"cortex%-m",
			"riscv%-rt",
		}
		for _, pattern in ipairs(embedded_patterns) do
			if cargo_toml:find(pattern) then
				return "thumbv7em-none-eabihf" -- 默认目标
			end
		end
	end

	-- 检查裸机项目常见文件
	for _, f in ipairs({ "link.x", "memory.x", ".probe-rs", "build.rs" }) do
		if uv.fs_stat(vim.fs.joinpath(root_dir, f)) then
			return "thumbv7em-none-eabihf"
		end
	end

	return nil
end

return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml" },
	single_file_support = true,
	settings = {
		["rust-analyzer"] = {
			showUnlinkedFileNotification = false,
			typing = { autoformat = true },
			check = {
				command = "clippy",
				allTargets = false,
			},
			diagnostics = {
				enable = true,
				trigger = "onType",
			},
			cargo = {
				allFeatures = true,
				autoreload = true,
				buildScripts = { enable = true },
			},
			procMacro = { enable = true },
			formatting = { enable = true },
			imports = {
				granularity = { group = "module" },
				prefix = "self",
			},
			inlayHints = {
				bindingModeHints = { enable = true },
				chainingHints = { enable = true },
				closingBraceHints = { enable = true, minLines = 25 },
				closureCaptureHints = { enable = true },
				closureReturnTypeHints = { enable = "never" },
				discriminantHints = { enable = "never" },
				expressionAdjustmentHints = { enable = "never", disableReborrows = true },
				genericParameterHints = { type = { enable = true } },
				implicitDrops = { enable = true },
				lifetimeElisionHints = { enable = "never" },
				parameterHints = { enable = true },
				typeHints = { enable = true },
			},
			lens = {
				enable = true,
				references = {
					adt = { enable = true },
					enumVariant = { enable = true },
					method = { enable = true },
					trait = { enable = true },
				},
			},
		},
	},
	on_new_config = function(config, root_dir)
		local target = detect_embedded_target(root_dir)
		if target then
			config.settings["rust-analyzer"].cargo.target = target
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = true
			config.settings["rust-analyzer"].check.noDefaultFeatures = true
		else
			config.settings["rust-analyzer"].cargo.target = nil
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = false
			config.settings["rust-analyzer"].check.noDefaultFeatures = false
		end
	end,
	on_attach = function(client, bufnr)
		local macro_preview_win = nil

		local macro_stack = {} -- 保存每一层展开结果
		local macro_level = 0 -- 当前层级

		local function render_macro_window(content)
			-- 自动计算尺寸
			local lines = vim.split(content, "\n")
			local max_width = math.floor(vim.o.columns * 0.45)
			local max_height = math.floor(vim.o.lines * 0.5)

			local content_width = 0
			for _, l in ipairs(lines) do
				content_width = math.max(content_width, vim.fn.strdisplaywidth(l))
			end

			local width = math.min(math.max(content_width + 4, 30), max_width)
			local height = math.min(#lines + 3, max_height)

			-- 右上角定位
			local row = 1
			local col = vim.o.columns - width - 2

			-- 创建 buffer
			local buf = vim.api.nvim_create_buf(false, true)

			-- 标题栏
			local title = string.format(" Macro Expansion (level %d) ", macro_level)
			local border_line = string.rep("─", math.max(0, width - #title - 2))
			local header = " " .. title .. border_line

			local display_lines = { header, "" }
			vim.list_extend(display_lines, lines)

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
			vim.bo[buf].filetype = "rust"
			vim.bo[buf].modifiable = false
			vim.bo[buf].readonly = true

			-- 创建浮窗
			if macro_preview_win and vim.api.nvim_win_is_valid(macro_preview_win) then
				vim.api.nvim_win_close(macro_preview_win, true)
			end

			local win = vim.api.nvim_open_win(buf, true, {
				relative = "editor",
				style = "minimal",
				border = "rounded",
				width = width,
				height = height,
				row = row,
				col = col,
			})

			-- 窗口选项
			vim.wo[win].wrap = false
			vim.wo[win].cursorline = false
			vim.wo[win].number = false
			vim.wo[win].relativenumber = false

			-- 关闭函数
			local function close_preview()
				if macro_preview_win and vim.api.nvim_win_is_valid(macro_preview_win) then
					vim.api.nvim_win_close(macro_preview_win, true)
				end
				macro_preview_win = nil
				macro_stack = {}
				macro_level = 0
			end

			-- 快捷键
			vim.keymap.set("n", "q", close_preview, { buffer = buf, noremap = true, silent = true })
			vim.keymap.set("n", "<Esc>", close_preview, { buffer = buf, noremap = true, silent = true })

			-- 下一层宏展开
			vim.keymap.set("n", "]m", function()
				local next_macro = content:match("([%w_]+!%b())")
				if not next_macro then
					vim.notify("没有更多可展开的宏", vim.log.levels.INFO)
					return
				end

				-- 请求下一层展开
				local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
				params.textDocument = nil
				params.position = nil
				params.macro = next_macro

				vim.lsp.buf_request(0, "rust-analyzer/expandMacro", params, function(err, result)
					if err or not result then
						vim.notify("宏展开失败", vim.log.levels.ERROR)
						return
					end

					macro_level = macro_level + 1
					table.insert(macro_stack, content)
					render_macro_window(result.expansion or "// No expansion")
				end)
			end, { buffer = buf, noremap = true, silent = true })

			-- 返回上一层
			vim.keymap.set("n", "[m", function()
				if macro_level == 0 then
					vim.notify("已经是最外层", vim.log.levels.INFO)
					return
				end

				local prev = table.remove(macro_stack)
				macro_level = macro_level - 1
				render_macro_window(prev)
			end, { buffer = buf, noremap = true, silent = true })

			-- 自动清理
			vim.api.nvim_create_autocmd("WinClosed", {
				callback = function(ev)
					if tonumber(ev.match) == win then
						macro_preview_win = nil
						macro_stack = {}
						macro_level = 0
					end
				end,
				once = true,
			})

			macro_preview_win = win
		end

		-- 主入口：展开当前光标处宏
		local function toggle_macro_preview()
			if macro_preview_win and vim.api.nvim_win_is_valid(macro_preview_win) then
				vim.api.nvim_win_close(macro_preview_win, true)
				macro_preview_win = nil
				macro_stack = {}
				macro_level = 0
				return
			end

			local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
			vim.lsp.buf_request(0, "rust-analyzer/expandMacro", params, function(err, result)
				if err or not result then
					vim.notify("宏展开失败", vim.log.levels.ERROR)
					return
				end

				macro_stack = {}
				macro_level = 0
				render_macro_window(result.expansion or "// No expansion")
			end)
		end
		vim.api.nvim_buf_create_user_command(bufnr, "RustExpandMacro", toggle_macro_preview, {
			desc = "切换 Rust 宏展开预览窗口",
		})

		local opts = { buffer = bufnr, noremap = true, silent = true, desc = "Toggle Rust Macro Preview" }
		vim.keymap.set("n", "grm", toggle_macro_preview, opts)
	end,
}
