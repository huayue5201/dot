-- https://rust-analyzer.github.io/book/index.html
--
local uv = vim.uv or vim.loop
local expand_macro = function()
	-- 1. 修正参数：第二个参数应为字符串，并传递 position_encoding
	vim.lsp.buf_request_all(
		0,
		--- @diagnostic disable-next-line: param-type-mismatch
		"rust-analyzer/expandMacro", -- 修改点：去掉花括号，直接传递字符串
		function(client)
			-- 官方推荐方式：使用客户端支持的编码
			--- @diagnostic disable-next-line: param-type-mismatch,redundant-parameter
			return vim.lsp.util.make_position_params(nil, nil, {
				position_encoding = client.offset_encoding or "utf-16",
			})
		end,
		function(result)
			-- 创建新分割并获取其窗口句柄
			vim.cmd("vsplit")
			local win = vim.api.nvim_get_current_win()

			-- 创建暂存缓冲区
			local buf = vim.api.nvim_create_buf(false, true)

			-- 将新缓冲区设置到新窗口
			vim.api.nvim_win_set_buf(win, buf)

			-- 准备显示的内容
			local lines_to_insert = {}
			if result then
				-- 累积所有客户端的结果
				for client_id, res in pairs(result) do
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

			-- 将内容写入缓冲区
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines_to_insert)
		end
	)
end
vim.api.nvim_create_user_command("RustExpandMacro", expand_macro, {})

--- 判断是否为嵌入式 Rust 项目
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
	commands = {
		ExpandMacro = {
			expand_macro,
			description = "Expand Rust macro at cursor position",
		},
	},
	settings = {
		["rust-analyzer"] = {
			showUnlinkedFileNotification = false,
			check = {
				command = "clippy",
				allTargets = true,
			},
			diagnostics = {
				enable = true,
				trigger = "onSave", -- 也可根据性能考虑改为 "onType"
			},
			cargo = {
				buildScripts = {
					enable = true,
				},
				-- 初始化时不设target，在 on_new_config 中动态设置
			},
			imports = {
				granularity = { group = "module" },
				prefix = "self",
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
			procMacro = {
				enable = true,
				-- 可以考虑添加 ignored 列表以优化性能，例如：
				-- ignored = {
				--     ["async-trait"] = { "async_trait" },
				--     ["napi-derive"] = { "napi" },
				-- }
			},
		},
	},
	on_new_config = function(config, root_dir)
		if is_embedded_project(root_dir) then
			config.settings["rust-analyzer"].cargo.target = "thumbv7em-none-eabihf" -- 或你的具体目标
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = true
			config.settings["rust-analyzer"].check.noDefaultFeatures = true
		else
			-- 明确设置标准项目的配置，避免残留的嵌入式配置
			config.settings["rust-analyzer"].cargo.target = nil
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = false
			config.settings["rust-analyzer"].check.noDefaultFeatures = false
		end
	end,
}
