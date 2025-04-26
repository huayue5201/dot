-- https://rust-analyzer.github.io/book/index.html

local uv = vim.uv or vim.loop

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

	-- 检查 .cargo/config.toml 或 config 是否设置了嵌入式 target
	for _, fname in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
		local content = read_file(root_dir .. "/" .. fname)
		if content and content:find('target%s*=%s*".-(thumb[^"]*|riscv[^"]*)"') then
			return true
		end
	end

	-- 检查 target/ 下是否存在 thumb*/riscv*
	local handle = uv.fs_scandir(root_dir .. "/target")
	if handle then
		while true do
			local name = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			if name:match("^thumb") or name:match("^riscv") then
				return true
			end
		end
	end

	-- 检查 Cargo.toml 中是否引入嵌入式库
	local cargo_toml = read_file(root_dir .. "/Cargo.toml")
	if cargo_toml then
		-- 添加更多的嵌入式库检查
		local embedded_libraries = {
			"embedded%-hal", -- 官方 embedded-hal 库
			"embassy", -- 第三方 embassy 库
			"defmt%-rt", -- 如果你使用了 defmt
			"nrf%-hal", -- 适用于 nRF 系列的嵌入式库
			-- 在这里继续添加你希望支持的其他嵌入式库
		}

		-- 遍历所有库进行查找
		for _, library in ipairs(embedded_libraries) do
			if cargo_toml:find(library) then
				return true
			end
		end
	end

	-- 检查裸机项目常见文件
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
			check = {
				command = "clippy",
				allTargets = false,
			},
			cargo = {
				buildScripts = {
					enable = true,
				},
				noDefaultFeatures = false, -- 这里初始默认值，会在 on_new_config 动态修改
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
			},
		},
	},
	-- 当 server 启动后，注入针对嵌入式的配置
	on_new_config = function(config, root_dir)
		if is_embedded_project(root_dir) then
			config.settings["rust-analyzer"].cargo.target = "thumbv7em-none-eabihf"
			config.settings["rust-analyzer"].cargo.noDefaultFeatures = true
			config.settings["rust-analyzer"].check.noDefaultFeatures = true
		end
	end,
}
