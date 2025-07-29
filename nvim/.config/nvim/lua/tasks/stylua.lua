-- tasks/stylua_format.lua

return {
    name = "styLua",
    type = "format",
    format = {
        filetypes = { "lua" },
        cmd = "stylua",
        args = {
            "-",
            "--search-parent-directories",
            "--indent-type=Spaces",
            "--indent-width=4",
        },
    },
    description = "使用 StyLua 格式化当前 Lua 文件（使用临时文件方案）",
}

