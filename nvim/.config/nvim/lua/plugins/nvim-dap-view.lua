-- https://github.com/igorlfs/nvim-dap-view?tab=readme-ov-file#expanding-variables

return {
    "igorlfs/nvim-dap-view",
    lazy = true,
    config = function()
        -- 设置自定义高亮颜色
        vim.api.nvim_set_hl(0, "ViewBreakpoints", { fg = "#FF3030" }) -- 红色
        vim.api.nvim_set_hl(0, "ViewScopes", { fg = "#FFD700" }) -- 金色
        vim.api.nvim_set_hl(0, "ViewExceptions", { fg = "#20B2AA" }) -- 海蓝色
        vim.api.nvim_set_hl(0, "ViewWatch", { fg = "#8B7E66", bg = nil }) -- 橙色
        vim.api.nvim_set_hl(0, "ViewThreads", { fg = "#8B4789" }) -- 紫红色
        vim.api.nvim_set_hl(0, "ViewREPL", { fg = "#228B22" }) -- 绿色
        vim.api.nvim_set_hl(0, "ViewConsole", { fg = "#FF7F00" }) -- 淡紫色

        -- 引入 nvim-dap-view 插件并配置
        local dv = require("dap-view")
        dv.setup({
            winbar = {
                show = true,
                -- 可以将 "console" 合并到其他视图
                sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl", "console" },
                -- 默认显示的视图
                default_section = "watches",
                headers = {
                    breakpoints = "%#ViewBreakpoints# %*" .. "Breakpoints [B]",
                    scopes = "%#ViewScopes#󰰡 %*" .. "Scopes [S]",
                    exceptions = "%#ViewExceptions# %*" .. "Exceptions [E]",
                    watches = "%#ViewWatch#󰖊 %*" .. "Watches [W]",
                    threads = "%#ViewThreads# %*" .. "Threads [T]",
                    repl = "%#ViewREPL# %*" .. "REPL [R]",
                    console = "%#ViewConsole# %*" .. "Console [C]",
                },
                controls = {
                    enabled = true,
                    position = "right",
                    buttons = {
                        "play",
                        "step_into",
                        "step_over",
                        "step_out",
                        "step_back",
                        "run_last",
                        "terminate",
                        "disconnect",
                    },
                    icons = {
                        pause = "",
                        play = "",
                        step_into = "",
                        step_over = "",
                        step_out = "",
                        step_back = "",
                        run_last = "",
                        terminate = "",
                        disconnect = "",
                    },
                    custom_buttons = {},
                },
            },
            windows = {
                height = 13,
                terminal = {
                    -- 'left'|'right'|'above'|'below': Terminal position in layout
                    position = "left",
                    -- 需要始终隐藏的调试适配器
                    hide = {},
                    -- 启动新会话时隐藏终端
                    start_hidden = false,
                },
                anchor = function()
                    -- 获取当前 tab 页中的所有窗口
                    local windows = vim.api.nvim_tabpage_list_wins(0)

                    -- 遍历窗口，查找第一个终端窗口
                    for _, win in ipairs(windows) do
                        local bufnr = vim.api.nvim_win_get_buf(win)
                        if vim.bo[bufnr].buftype == "terminal" then
                            return win -- 找到后返回该窗口 ID
                        end
                    end
                end,
            },
            -- 控制选择断点或导航堆栈时的跳转行为
            -- switchbuf = "usetab,newtab",
        })

        -- 配置快捷键切换 nvim-dap-view
        vim.keymap.set("n", "<leader>dv", function()
            dv.toggle(true)
        end, { desc = "切换 nvim-dap-view" })

        vim.keymap.set("n", "<localleader>w", "<cmd>DapViewJump watches<cr>", { desc = "dap-view watches" })
        vim.keymap.set("n", "<localleader>s", "<cmd>DapViewJump scopes<cr>", { desc = "dap-view scopes" })
        vim.keymap.set("n", "<localleader>e", "<cmd>DapViewJump exceptions<cr>", { desc = "dap-view exceptions" })
        vim.keymap.set("n", "<localleader>b", "<cmd>DapViewJump breakpoints<cr>", { desc = "dap-view breakpoints" })
        vim.keymap.set("n", "<localleader>t", "<cmd>DapViewJump threads<cr>", { desc = "dap-view threads" })
        vim.keymap.set("n", "<localleader>r", "<cmd>DapViewJump repl<cr>", { desc = "dap-view repl" })
        vim.keymap.set("n", "<localleader>c", "<cmd>DapViewJump console<cr>", { desc = "dap-view repl" })

        -- 配置添加/删除观察点
        vim.operator("n", "<leader>dav", "<cmd>DapViewWatch<cr>", {
            operator_opts = { motion = "l" },
            desc = "添加/删除观察点",
        })
    end,
}

