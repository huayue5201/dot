return {
    name = "cppcheck_test",
    type = "lint",
    description = "测试 cppcheck 解析器",
    lint = {
        filetypes = { "c", "cpp" },
        cmd = "cppcheck",
        args = {
            "--enable=all",
            "--template={file}:{line}:{column}:{severity}:{message}",
            "{file_path}",
        },
        parser = "cppcheck-pr",
        opts = {
            format = "{file}:{line}:{column}:{severity}:{message}",
        },
    },
}

