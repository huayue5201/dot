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
	root_markers = { "Cargo.toml", ".git" },
	-- Neovim 0.13 用 workspace_required 替代旧 lspconfig 的 single_file_support
	workspace_required = false,
	settings = {
		["rust-analyzer"] = {
			showUnlinkedFileNotification = false,
			typing = { autoformat = true },
			completion = {
				callable = {
					-- https://rust-analyzer.github.io/book/configuration.html#completion.callable.snippets
					snippets = "add_parentheses", -- or 'none'
				},
			},
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
				location = "above_whole_item", -- 或 "above_name"
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
		require("lsp-config.rust_macro_preview").setup(client, bufnr)
	end,
}
