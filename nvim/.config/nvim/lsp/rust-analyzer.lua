-- https://rust-analyzer.github.io/book/index.html

local uv = vim.uv or vim.loop

-- 判断是否为嵌入式 Rust 项目
local function detect_embedded_target(root_dir)
	local function read_file(path)
		local fd = uv.fs_open(path, "r", 420) -- 0644
		if not fd then
			return nil
		end
		local stat = uv.fs_fstat(fd)
		if not stat then
			return nil
		end
		local data = uv.fs_read(fd, stat.size, 0)
		uv.fs_close(fd)
		return data
	end

	-- 检查 .cargo/config.toml
	for _, fname in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
		local content = read_file(root_dir .. "/" .. fname)
		if content then
			local target = content:match('target%s*=%s*"(.-)"')
			if target and (target:match("thumb") or target:match("riscv") or target:match("arm")) then
				return target
			end
		end
	end

	-- 检查 target/ 目录
	local handle = uv.fs_scandir(root_dir .. "/target")
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
	local cargo_toml = read_file(root_dir .. "/Cargo.toml")
	if cargo_toml then
		local embedded_libraries = {
			"embedded%-hal",
			"embassy",
			"defmt%-rt",
			"nrf%-hal",
		}
		for _, library in ipairs(embedded_libraries) do
			if cargo_toml:find(library) then
				return "thumbv7em-none-eabihf" -- 默认目标，可按需修改
			end
		end
	end

	-- 检查裸机项目常见文件
	for _, f in ipairs({ "link.x", "memory.x", ".probe-rs" }) do
		if uv.fs_stat(root_dir .. "/" .. f) then
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
			typing = { autoformat = true }, -- 开启 on-type formatting
			checkOnSave = {
				enable = true,
				command = "clippy",
			},
			check = {
				command = "check",
				allTargets = false,
			},
			diagnostics = {
				enable = true,
				trigger = "onType",
			},
			cargo = {
				autoreload = true,
				buildScripts = { enable = true },
			},
			formatting = { enable = true },
			assist = {
				importGranularity = "module",
				importPrefix = "by_self",
			},
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
			procMacro = { enable = true },
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

		local function toggle_macro_preview()
			if macro_preview_win and vim.api.nvim_win_is_valid(macro_preview_win) then
				vim.api.nvim_win_close(macro_preview_win, true)
				macro_preview_win = nil
				return
			end

			local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
			--- @diagnostic disable-next-line: param-type-mismatch
			vim.lsp.buf_request_all(0, "rust-analyzer/expandMacro", params, function(result)
				vim.cmd("split")
				local win = vim.api.nvim_get_current_win()
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_win_set_buf(win, buf)

				local lines_to_insert = {}
				if result then
					for _, res in pairs(result) do
						if res and res.result and res.result.expansion then
							lines_to_insert = vim.split(res.result.expansion, "\n")
							break
						end
					end
					if #lines_to_insert == 0 then
						lines_to_insert = { "No expansion available." }
					end
					vim.bo[buf].filetype = "rust"
				else
					lines_to_insert = { "Error: No result returned." }
				end
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_insert)
				local close_preview = function()
					if macro_preview_win and vim.api.nvim_win_is_valid(macro_preview_win) then
						vim.api.nvim_win_close(macro_preview_win, true)
						macro_preview_win = nil
					end
				end
				vim.keymap.set("n", "q", close_preview, { buffer = buf, noremap = true, silent = true })
				vim.keymap.set("n", "<Esc>", close_preview, { buffer = buf, noremap = true, silent = true })

				vim.bo[buf].readonly = true
				vim.bo[buf].modifiable = false
				vim.wo[win].cursorline = false

				macro_preview_win = win
			end)
		end

		vim.api.nvim_buf_create_user_command(bufnr, "RustExpandMacro", toggle_macro_preview, {
			desc = "切换 Rust 宏展开预览窗口（打开/关闭）",
		})

		local opts = { buffer = bufnr, noremap = true, silent = true, desc = "Toggle Rust Macro Preview" }
		vim.keymap.set("n", "<leader>lm", toggle_macro_preview, opts)
	end,
}
