-- https://github.com/danmar/cppcheck/

 return {
    name = "cppcheck",
    type = "lint",
    lint = {
        filetypes = { "c", "cpp" },
        cmd = "cppcheck",
        args = {
            "--enable=warning,performance,portability",
            "--suppress=missingIncludeSystem",
            "--inline-suppr",
            "--quiet",
            function(ctx)
                return ctx.file_type == "cpp" and "--std=c++17" or "--std=c11"
            end,
            -- 使用兼容的模板格式
            "--template={file}:{line}:{column}:{severity}:{message}",
            "${file_path}"
        },
        cwd = "${project_root}",
        env = {
            CPPCHECK_INCLUDE_PATH = "${project_root}/include"
        },
        uses_filename = true,
        output_format = "custom",
        -- 添加专用解析器
        parser = function(output)
            -- 内联cppcheck解析器
            local diagnostics = {}
            for line in output:gmatch("[^\r\n]+") do
                local file, lnum, col, severity, message =
                    line:match("^(.-):(%d+):(%d+):([^:]+):(.+)$")

                if file then
                    table.insert(diagnostics, {
                        filename = file,
                        lnum = tonumber(lnum),
                        col = tonumber(col),
                        message = message,
                        severity = severity
                    })
                end
            end
            return diagnostics
        end
    }
}
