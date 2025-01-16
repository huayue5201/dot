vim.lsp.start({
  name = "lua-language-server",
  cmd = { "lua-language-server" },
  root_dir = vim.fs.root(0, {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    "selene.toml",
    "selene.yml",
    ".git",
  }),
  filetypes = { "lua" },
  on_init = function(client)
    -- 获取工作目录
    local path = client.workspace_folders[1].name
    -- 如果存在配置文件 .luarc.json 或 .luarc.jsonc，则跳过其他设置
    if vim.loop.fs_stat(path .. "/.luarc.json") or vim.loop.fs_stat(path .. "/.luarc.jsonc") then
      return
    end
    -- 否则，扩展 Lua 的默认配置
    client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
      runtime = {
        version = "LuaJIT", -- 指定 Lua 版本为 LuaJIT
      },
      workspace = {
        library = {
          vim.env.VIMRUNTIME,
        },
        checkThirdParty = false,
      },
    })
  end,
  settings = {
    Lua = {
      hint = {
        enable = true, -- 启用代码提示
      },
      codelens = {
        enable = true, -- 启用 CodeLens 功能
      },
      runtime = {
        version = "LuaJIT", -- 指定 Lua 版本
      },
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME, -- 加载 Neovim 的 runtime 文件
        },
        -- 可选：加载所有 runtime 文件（可能会减慢速度）
        -- library = vim.api.nvim_get_runtime_file("", true),
      },
      globals = {
        "vim", -- 声明全局变量 vim
      },
    },
  },
})

-- 调用lsp配置
require("utils.lsp_config").lspSetup()
