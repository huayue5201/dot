-- tasks/make_build.lua
return {
    name = "make",
    type = "command", -- 使用 CommandFramework
    command = { -- 注意这里用 command 子表，和 format 那里对应
        filetypes = { "c" }, -- 可选：过滤 C 文件
        cmd = "make",
        args = { "all" },
        -- cwd = "${project_root}/build", -- 可选：构建目录
        env = {
            BUILD_TYPE = "release",
        },
        output = true, -- 捕获输出并返回
        timeout = 60, -- 可选：超时时间（秒）
    },
    description = "使用 Make 构建 C 项目",
}

