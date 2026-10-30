-- https://github.com/EmmyLuaLs/emmylua-analyzer-rust
--
-- 注意 1：emmylua_ls 只读工作区根目录的 .emmyrc.json / .emmyrc.lua / .luarc.json，
--         完全不认 lua_ls 的 settings.Lua，配置见同目录层级的 `.emmyrc.json`。
-- 注意 2：启用本文件时请同时移除 lsp/lua-language-server.lua，否则两个 lua
--         server 会同时 attach，诊断重复。
-- 注意 3：lazydev 只给 lua_ls 注入 vim API 类型，emmylua 下 vim.api.* 的补全
--         / 悬浮会退化（仅剩 globals 白名单），需要自己补 meta 库。

return {
	cmd = { "emmylua_ls" },
	filetypes = { "lua" },
	root_markers = { ".emmyrc.json", ".emmyrc.lua", ".luarc.json", ".luarc.jsonc", ".git" },
	single_file_support = true,
}
