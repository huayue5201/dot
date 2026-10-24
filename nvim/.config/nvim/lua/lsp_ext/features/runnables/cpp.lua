-- lua/lsp_ext/features/runnables/cpp.lua
-- C/C++（clangd）代码透镜支持
--
-- clangd 的 code lens 命令（"N references" / "base of ..." / 类型层级等）是**客户端侧**
-- 命令：clangd 只把命令名和参数发过来，真正展示位置列表要客户端做。Neovim 原生不处理，
-- 表现就是透镜能显示、点下去报 `does not support command clangd.showLocations`。
--
-- 参数形状统一是「若干个 Location / LocationLink 嵌套在 arguments 里」，
-- 所以统一交给 features/runnables/locations.lua 解析：1 个位置直接跳，多个进 quickfix。
--
-- 注意：Apple 的 clangd（/usr/bin/clangd，Xcode 21）根本没声明 codeLensProvider，
-- 不会发透镜；这里是为了 LLVM 官方版 / mason 版 clangd 准备的。

local locations = require("lsp_ext.features.runnables.locations")

local M = {}

---@param command table
---@return boolean handled
local function show_locations(command)
	return locations.show_from_args(command.arguments)
end

M.commands = {
	-- 引用 / 使用处
	["clangd.showLocations"] = show_locations,
	["clangd.showLocationsAt"] = show_locations,
	-- 类型层级（base of / derived）
	["clangd.typeHierarchy"] = show_locations,
}

M.keymaps = {}

return M
