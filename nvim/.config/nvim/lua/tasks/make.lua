-- lua/tasks/build.lua

return {
    name = "make",
    type = "make",
    make = {
        filetypes = "c",
        cmd = "make",
        args = { "all" },
        -- cwd = "${project_root}/build",
    },
}

