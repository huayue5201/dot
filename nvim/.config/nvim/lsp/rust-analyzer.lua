-- https://rust-analyzer.github.io/book/index.html

local uv = vim.uv or vim.loop

-- 判断是否为嵌入式 Rust 项目
local function is_embedded_project(root_dir)
	local function read_file(path)
		local fd = uv.fs_open(path, "r", 438)
		if not fd then
			return nil
		end
		local stat = uv.fs_fstat(fd)
		local data = uv.fs_read(fd, stat.size, 0)
		uv.fs_close(fd)
		return data
	end

	-- 安全检查：如果文件读取失败，content为nil，后续操作会报错
	-- 检查 .cargo/config.toml
	for _, fname in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
		local content = read_file(root_dir .. "/" .. fname)
		-- 增加nil检查
		if content and content:find('target%s*=%s*".-(thumb[^"]*|riscv[^"]*|arm[^"]*)"') then
			return true
		end
	end

	-- 检查 target/ 目录下的目标架构（不变）
	local handle = uv.fs_scandir(root_dir .. "/target")
	if handle then
		while true do
			local name = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			if name:match("^thumb") or name:match("^riscv") or name:match("^arm") then
				return true
			end
		end
	end

	-- 检查 Cargo.toml 中的依赖（不变）
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
				return true
			end
		end
	end

	-- 检查裸机项目常见文件（不变）
	for _, f in ipairs({ "link.x", "memory.x", ".probe-rs" }) do
		if uv.fs_stat(root_dir .. "/" .. f) then
			return true
		end
	end

	return false
end

return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml" },
	single_file_support = true,
	settings = {
		["rust-analyzer"] = {
			showUnlinkedFileNotification = false,
			checkonSave = {
				enable = true,
				command = "clippy",
			},
			check = {
				command = "check",
				allTargets = false,
			},
			diagnostics = {
				enable = true,
				trigger = "onType", -- 设置为 "onSave" 也可以根据性能考虑
			},
			cargo = {
				autoreload = true,
				buildScripts = {
					enable = true,
				},
			},
			formatting = {
				enable = true,
			},
			assist = {
				importGranularity = "module", -- 自动导入时的粒度，模块、类型等
				importPrefix = "by_self", -- 自动导入时使用的前缀
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
				expressionAdjustmentHints = {
					enable = "never",
					disableReborrows = true,
				},
				genericParameterHints = {
					type = { enable = true },
				},
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
			procMacro = { -- 启用过程宏支持
				enable = true,
			},
		},
	},
	on_new_config = function(config, root_dir)
		if is_embedded_project(root_dir) then
			config.settings["rust-analyzer"].cargo.target = "thumbv7em-none-eabihf" -- 或您的具体目标
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = true
			config.settings["rust-analyzer"].check.noDefaultFeatures = true
		else
			-- 明确设置标准项目的配置，避免残留的嵌入式配置
			config.settings["rust-analyzer"].cargo.target = nil
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = false
			config.settings["rust-analyzer"].check.noDefaultFeatures = false
		end
	end,
	on_attach = function(client, bufnr)
		-- 状态变量：只记录当前预览窗口
		local macro_preview_win = nil

		-- 切换宏预览的主函数
		local function toggle_macro_preview()
			-- 情况1：如果窗口有效，则关闭预览
			if macro_preview_win and vim.api.nvim_win_is_valid(macro_preview_win) then
				vim.api.nvim_win_close(macro_preview_win, true)
				macro_preview_win = nil
				return
			end

			-- 情况2：否则，请求服务器展开宏并打开预览
			vim.lsp.buf_request_all(
				0,
				--- @diagnostic disable-next-line: param-type-mismatch
				"rust-analyzer/expandMacro",
				function(lsp_client)
					-- 修正：安全地获取编码，并正确传递参数
					local encoding = lsp_client.offset_encoding
					if encoding == nil then
						encoding = "utf-16"
					end
					return vim.lsp.util.make_position_params(0, encoding)
				end,
				function(result)
					-- 创建水平分割窗口
					vim.cmd("split")
					local win = vim.api.nvim_get_current_win()
					local buf = vim.api.nvim_create_buf(false, true)
					vim.api.nvim_win_set_buf(win, buf)

					-- 1. 准备并写入内容
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
						vim.api.nvim_set_option_value("filetype", "rust", { buf = buf })
					else
						lines_to_insert = { "Error: No result returned." }
					end
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_insert)

					-- 2. 设置键映射（在设为只读前绑定）
					local close_preview = function()
						if vim.api.nvim_win_is_valid(macro_preview_win) then
							vim.api.nvim_win_close(macro_preview_win, true)
							macro_preview_win = nil
						end
					end
					vim.keymap.set(
						"n",
						"q",
						close_preview,
						{ buffer = buf, noremap = true, silent = true, desc = "关闭宏预览" }
					)
					vim.keymap.set(
						"n",
						"<Esc>",
						close_preview,
						{ buffer = buf, noremap = true, silent = true, desc = "关闭宏预览" }
					)

					-- 4. 【关键】最后，将缓冲区设置为只读/不可修改
					vim.api.nvim_set_option_value("readonly", true, { buf = buf })
					vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

					-- 5. 记录窗口并设置窗口选项
					macro_preview_win = win
					vim.api.nvim_set_option_value("cursorline", false, { win = win })
				end
			)
		end

		-- 创建缓冲区本地用户命令（推荐方式）
		vim.api.nvim_buf_create_user_command(bufnr, "RustExpandMacro", toggle_macro_preview, {
			desc = "切换 Rust 宏展开预览窗口（打开/关闭）",
		})

		local opts = { buffer = bufnr, noremap = true, silent = true, desc = "Toggle Rust Macro Preview" }
		vim.keymap.set("n", "<leader>lm", toggle_macro_preview, opts)
	end,
}
