-- lua/project_config/detect.lua
local M = {}

M.rules = {
	{
		name = "rust-embedded",
		priority = 100, -- 数字越大优先级越高
		match = function(cwd)
			return vim.fn.filereadable(cwd .. "/Cargo.toml") == 1 and vim.fn.isdirectory(cwd .. "/.probe-rs") == 1
		end,
		dap = "probe-rs-debug",
		lsp = { "rust-analyzer", "taplo" },
		env = { chip = "nRF52840", svdFile = "nrf52840.svd" },
	},
	{
		name = "c-cross",
		priority = 80,
		match = function(cwd)
			return vim.fn.filereadable(cwd .. "/CMakeLists.txt") == 1 and vim.fn.filereadable(cwd .. "/cross.toml") == 1
		end,
		dap = "openocd",
		lsp = { "clangd" },
	},
	{
		name = "js-web",
		priority = 50,
		match = function(cwd)
			return vim.fn.filereadable(cwd .. "/package.json") == 1
		end,
		dap = "vscode-js-debug",
		lsp = { "vtsls" },
	},
	{
		name = "lua-tooling",
		priority = 30,
		match = function(cwd)
			return vim.fn.filereadable(cwd .. "/init.lua") == 1
		end,
		dap = "local-lua-debugger-vscode",
		lsp = { "lua_ls" },
	},
}

-- 返回优先级最高的匹配规则
function M.detect()
	local cwd = vim.fn.getcwd()
	local matched = {}
	for _, rule in ipairs(M.rules) do
		if rule.match(cwd) then
			table.insert(matched, rule)
		end
	end
	table.sort(matched, function(a, b)
		return (a.priority or 0) > (b.priority or 0)
	end)
	return matched[1] -- 返回最高优先级
end

return M
