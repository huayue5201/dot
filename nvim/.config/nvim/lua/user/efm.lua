-- user/efm.lua

local M = {}

--- 设置 efm-langserver 的配置
-- @param languages table 语言配置
-- 例如:
-- local languages = {
--     lua = {
--         lintCommand = "luacheck",
--         lintFormats = {"%f:%l:%c: %m"},
--         formatCommand = "stylua",
--         formatStdin = true
--     },
--     json = {
--         lintCommand = "jsonlint",
--         lintFormats = {"%f:%l:%c: %m"},
--         formatCommand = "jsonlint -i",
--         formatStdin = true
--     },
-- }
function M.setup(languages)
    -- 默认的 efm-langserver 配置
    local default_efm_config = {
        init_options = {documentFormatting = true},
        settings = {
            rootMarkers = {".git/"},
            languages = {},
        },
    }

    -- 合并用户提供的语言设置
    local efm_config = vim.tbl_extend("force", default_efm_config, {
        settings = {
            languages = languages or {},
        },
    })

    -- 启动 efm-langserver
    vim.lsp.start(vim.tbl_extend("force", {
        cmd = {"efm-langserver", "-logfile", "/tmp/efm.log"},
    }, efm_config))
end

return M

-- -- 使用说明
-- -- 首先，导入 efm 模块
-- local efm = require('user.efm')

-- -- 定义你需要的 lint 和格式化 设置
-- local languages = {
--     lua = {
--         lintCommand = "luacheck",
--         lintFormats = {"%f:%l:%c: %m"},
--         formatCommand = "stylua",
--         formatStdin = true
--     },
--     json = {
--         lintCommand = "jsonlint",
--         lintFormats = {"%f:%l:%c: %m"},
--     },
-- }

-- -- 调用 setup 函数，并传入你的语言设置
-- efm.setup(languages)
