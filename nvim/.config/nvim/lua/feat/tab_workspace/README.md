# tab_workspace —— 一 tab 一工作区

## 模型

一个 **tab = 一个工作区**，没有额外的"工作区实体/注册表"：

| 维度 | 载体 |
|---|---|
| 根目录 | tab 作用域的 `:tcd`（`root.lua` 里 `pinned` 显式锁定、`prev` 回退点） |
| buffer 归属 | `state.lua` 的 `tab -> bufnr 集合`；`buflisted` 只反映当前 tab |
| 语言服务 | `lsp.lua`：离开 tab 延迟停掉它独占的 client，回来再拉起 |
| 持久化 | resession 会话（v2 格式：按 tab 顺序存 `{ root, names }`） |
| 本地配置 | `<根>/.nvim.lua`，进入工作区加载、离开逐项回滚（`local_settings.lua`） |
| UI 锚点 | statusline 左侧 ` 名字 n/N`，名字 = 根目录末段 |

设计上刻意没有的东西：multi-root、工作区自定义命名、全局工作区注册表。
需要跨项目并排看时开两个 tab，不需要给工作区再起一个名字。

## 文件职责

| 文件 | 职责 |
|---|---|
| `util.lua` | 判定什么 buffer / 窗口属于工作区（特殊 buftype、侧栏、会话加载期） |
| `state.lua` | buffer 归属表、最近访问的 tab |
| `listed.lua` | `buflisted` 同步（"listed = 当前 tab 可见"的唯一实现） |
| `lifecycle.lua` | 关闭 buffer、清理已关闭 tab 的孤儿 buffer |
| `session.lua` | resession 扩展：导出/恢复归属 |
| `session_guard.lua` | 会话归属校验（防止"存 A 打开成 B"）、autosave、载入后修 cwd |
| `lsp.lua` | 每 tab 的 LSP 生命周期 |
| `root.lua` | 按当前文件判定项目根（marker / LSP），自动切 tab 根；锁定与回退 |
| `workspace.lua` | 切根、新建/关闭/切换工作区、保存/载入会话、统一 picker |
| `local_settings.lua` | `<根>/.nvim.lua` 的加载与回滚；`w.task` / `w.launch` 注册 |

入口是上一层的 `lua/feat/tab_workspace.lua`（只做 setup、autocmd 与公共 API 转发）。

## 生命周期（谁在什么时候触发）

```
BufEnter/BufWinEnter  归属当前 tab + maybe_follow（文件不在根内才切根）
TabEnter              relist（同步，避免首帧闪烁）→ 下一个事件循环再校归属 + lsp.sync
TabLeave              记下"上一个 tab"，给 alternate 用
TabClosed             root.prune → schedule(lifecycle.prune + lsp.on_tab_closed)
DirChanged / User TabWorkspaceRoot / VimEnter
                      local_settings.sync（加载/回滚 .nvim.lua）
resession post_load   session.on_post_load → local_settings.sync
```

## 公共 API

```lua
local ws = require("feat.tab_workspace")
ws.new_workspace(dir?)   ws.close_workspace()   ws.alternate()   ws.picker()
ws.set_root(dir)         ws.prompt_root()       ws.root_back()   ws.root_unpin()
ws.save_session(name?)   ws.load_session(name?)
ws.edit_local_settings() ws.reload_local_settings()
ws.visible_buffers()     ws.close_buffer(buf)   ws.is_managed_buf(buf)
```

键位（`boot/keymaps.lua`）：

| 键 | 动作 |
|---|---|
| `<leader>lwn` | 新建工作区（新 tab + 选目录） |
| `<leader>lwc` | 关闭工作区 |
| `<leader>lwa` | 在最近两个工作区之间来回 |
| `<leader>lwl` | 工作区列表（打开中的 tab + 已保存会话 + 新目录） |
| `<leader>lws` / `<leader>lwr` / `<leader>lwR` | 锁定根 / 回退到上一个根并锁定 / 解除锁定 |
| `<leader>lwe` | 编辑当前工作区的 `.nvim.lua` |
| `<leader>lsl` / `<leader>lst` / `<leader>lss` / `<leader>lsd` | 会话：加载（与 lwl 同一 picker）/ 保存 / 保存 tab / 删除 |

## `.nvim.lua`（工作区本地配置）

放在工作区根目录，行为对标 Emacs `.dir-locals.el`、VS Code `.vscode/settings.json`：
配置跟着目录走，离开工作区时逐项还原。完整参考（全部 `w.*` 参数、占位符、回滚矩阵、示例、排查）
见 [nvim-lua.md](./nvim-lua.md)，下面只是速览。

```lua
w.opt({ tabstop = 4, shiftwidth = 4 })          -- 根下所有 buffer 的 buffer-local 选项
w.global_opt({ spelllang = { "cjk", "en" } })   -- 全局选项
w.au("BufWritePre", { pattern = "*.rs" }, function(args) end)
w.cmd("Build", function(args) end, { desc = "构建" })
w.map("n", "<leader>B", "<cmd>Build<cr>", { desc = "构建" })
w.task({ name = "构建", cmd = { "make" }, cwd = "${workspaceFolder}" })
w.launch({ name = "调试", filetype = "rust", type = "codelldb", request = "launch" })
```

- **信任**：走 Neovim 的 `:trust`（`vim.secure.read`）。未信任时静默跳过，`:trust` 后重新进入工作区即可。
- **作用域**：按「文件路径在根下」判定（不是按当前 tab），后台载入的 buffer 也正确；新打开的文件通过
  `BufReadPost` / `FileType` 自动套用。
- **回滚**：逐 buffer 恢复原选项 → 恢复全局选项 → 删用户命令 → 删 buffer-local 键位 → 删整个 augroup →
  从 `dap.configurations` 按引用摘除注入的调试配置。
- **边界**：只有经 `w.*` 登记的改动有回滚保证；文件里其它任意 Lua 副作用（改 `runtimepath`、装全局键位等）
  不受保护——这是刻意的，不给"能改一切又都能撤销"的假承诺。
- `w.task` 接 overseer（`:OverseerRun` / `<leader>ru`），`w.launch` 接 nvim-dap（`:DapContinue`）。
  任务里的 `${workspaceFolder}` / `${file}` / `${fileBasename}` / `${fileDirname}` 在任务启动时展开；
  调试配置里的占位符保持原样，交给 nvim-dap 运行时展开（它认同一套变量）。
- 为什么不用 `'exrc'`：它只在启动时扫一次启动目录，`:tcd` 进别的项目既不加载也不回滚，且执行的是
  未登记的裸 Lua。`local_settings.setup()` 会把 `exrc` 关掉，`.nvim.lua` 由本模块独占。

## 测试

```sh
nvim --headless -u NONE -l tests/tab_workspace_root.lua
nvim --headless -u NONE -l tests/tab_workspace_session.lua
nvim --headless -u NONE -l tests/tab_workspace_local_settings.lua
```

都是"用户视角"的行为测试：只做用户会做的动作（`:edit`、`:tcd`、开 tab、走 API），断言 `getcwd()`、
`buflisted`、选项值、命令/模板是否存在这类可观察结果，不断言内部实现。
