-- tasks/stylua_format.lua

return {
    name = "styLua",
    type = "format",
    format = {
    filetypes = { "lua" },
        cmd = "stylua",
        args = {
            "--search-parent-directories",
            "--indent-type=Spaces",
            "--indent-width=4",
        },
        reload = false, -- 临时文件方案不需要 reload
        notify = true,
    },
    description = "使用 StyLua 格式化当前 Lua 文件（使用临时文件方案）",
}

