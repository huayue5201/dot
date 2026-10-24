# lua/ 目录约定

放新文件前先问：它是**启动骨架**、**界面部件**、**功能**，还是**共享小工具**？

| 目录 | 放什么（一句话） | 举例 |
|---|---|---|
| `boot/` | 启动阶段按序执行的脚本：加载器、安装器、启动前后修补、全局选项/映射/自动命令 | `pack.lua`、`settings.lua`、`keymaps.lua` |
| `ui/` | 可被别处复用的界面部件（不是插件） | `statusline.lua`、`float_list.lua`、`colors.lua` |
| `feat/` | 自研的完整功能，一个功能一个文件或一个目录 | `navigation/`、`tab_workspace/`、`fork_upstream.lua` |
| `lib/` | 被多个域共用的小工具，不自己开窗口 | `context.lua`、`lsp_request.lua`、`tool.lua`、`cargo.lua` |
| `local/` | 「自研替代某个插件」的小模块 | `lightbulb.lua`、`textdiff.lua` |
| `plugins/` | 第三方插件的 spec，一插件一文件 | `gitsigns.lua`、`blink.lua` |
| `lsp_ext/` | 在**内置 LSP 客户端**之上加的一层：面板、features、icons、servers 注册 | `panel.lua`、`features/rust_ssr.lua` |
| `dap_ext/` | 在**nvim-dap** 之上加的一层 | `adapters/`、`dap_keys.lua` |
| `vendor/` | 自维护的第三方后端补丁（被插件按模块名引用） | `smart-splits-backend-herdr.lua` |

顶层还有 Vim 原生目录：`lsp/`（`vim.lsp.config` 声明）、`ftplugin/`、`after/`、`snippets/`。

规则：

- `boot/` 里的顺序敏感，`init.lua` 的 require 顺序就是依赖顺序，别随意重排。
- `*_ext/` = 给某个外部系统（内置 LSP、nvim-dap）加的增强层；不依赖外部系统概念的，进 `feat/`。
- 只有被 2 个以上域用到才进 `lib/`；只被一个功能用到的，就近放在该功能目录里。
- 目录名和文件名统一 `snake_case`。`config` 不出现在目录名里（它只属于文件名：`settings.lua`、`dap_keys.lua`）。
- **外部工具的输出不能进 UI**：跑 `cargo`/`git`/`rg` 之类得到的 stdout/stderr 只能落成结构化数据（路径、诊断项、计数），
  禁止 `vim.notify(table.concat(out, ...))` 这种把原始输出直接喷出来的写法。
  `lib/tool.lua` 就是这么做的：`run()` 只返回 `{ok, code, diagnostics, data}`，参数解析留在各工具的 adapter（如 `lib/cargo.lua`），
  原始输出只能由用户显式 `:ToolLog` 查看。
- 改目录后用 `git mv` 保留 rename 记录，并删掉 `~/.cache/nvim/luac`（`vim.loader` 按路径缓存字节码）。
