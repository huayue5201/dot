# tab_workspace —— 一 tab 一工作区

## 模型

一个 **tab = 一个工作区**，没有额外的"工作区实体/注册表"：

| 维度 | 载体 |
|---|---|
| 根目录 | tab 作用域的 `:tcd`（`root.lua` 里 `pinned` 显式锁定、`prev` 回退点） |
| buffer 归属 | `state.lua` 的 `tab -> bufnr 集合`；`buflisted` 只反映当前 tab |
| 语言服务 | `lsp.lua`：离开 tab 延迟停掉它独占的 client，回来再拉起 |
| 持久化 | resession 会话（v2 格式：按 tab 顺序存 `{ root, names, aux }`） |
| 本地配置 | `<根>/.nvim.lua`，进入工作区加载、离开逐项回滚（`local_settings.lua`） |
| 辅助根 | `roots.lua`：一个工作区 = 1 个主根（cwd）+ N 个辅助根 |
| UI 锚点 | statusline 左侧 `🖿 名字 n/N +M`（M = 辅助根数量），名字 = 根目录末段 |

设计上刻意没有的东西：工作区自定义命名、全局工作区注册表。需要跨项目并排看时开两个 tab，
不需要给工作区再起一个名字。

## 多根（主根 + 辅助根）

一个工作区可以有多个根，但**只有主根是 cwd**（Neovim 的 cwd 是单值，`'path'`/`gf`/终端/`:make`
都跟着它走，`'exrc'` 与依赖 cwd 的插件同理）：

| 根 | 由谁决定 | 作用 |
|---|---|---|
| 主根 | `:tcd`（`root.lua` 自动认根 / 手动 `lwn`、`lws`） | cwd、gitignore 标记、新 buffer 归属判定 |
| 辅助根 | `roots.lua` 的 tab 级列表 | 在 workspace 树里并列展示、`roots.find_root()` 判定 buffer 属于哪个根 |

`roots.reconcile()` 在主根变化时对齐：新主根如果原本在辅助根里就摘掉；旧主根**不会**自动降级成辅助根
（要不要留是用户的决定）。会话把辅助根写在 `aux` 字段里，载入后恢复。

### 树：`neo_tree.lua`（neo-tree 外部源 `workspace`）

一个专门的源，顶格并列展示「主根 + 辅助根」，每行带 `主 `/`辅 ` 徽标，展开后就是 filesystem 源的
真实目录内容（同一套过滤、gitignore、嵌套、监听）。实现方式不是重写一套树，而是复用 neo-tree 自己的渲染：

- `renderer.show_nodes` 一次渲染根列表（`hide_root_node` 时合成根被 skip，真实根顶格）；
- 展开某个根 → `fs.toggle_directory` → `fs_scan.get_items(state, 根目录, ...)`，`parent_id` 是任意真实目录；
- `state.path` 仍设为主根（gitignore 标记、`refresh` 只认一个）。

命令：`<leader>lwt` 或 `:Neotree workspace toggle`（插件配置里也有 `<leader>ew`）。
辅助根的增删：`<leader>lw+`（`workspace.attach_root`）/ `<leader>lw-`（`workspace.detach_root`）。

没做的事（有意）：把辅助根也变成一棵完整树（deep 扫描）会让大仓库开树明显变慢；辅助根默认折叠，
展开时才扫。

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
| `workspace.lua` | 切根、新建/关闭/切换工作区、保存/载入会话、统一 picker、辅助根增删 |
| `roots.lua` | 辅助根：attach/detach/clear/会话恢复/主根变化对齐/`find_root` |
| `neo_tree.lua` | neo-tree 外部源 `workspace`：主根 + 辅助根并列的多根树 |
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
ws.attach_root(dir?)    ws.detach_root(dir?)      ws.roots()
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
| `<leader>lw+` / `<leader>lw-` | 附加辅助根 / 移除辅助根（主根仍是 cwd） |
| `<leader>lwt` / `<leader>ew` | 多根树（neo-tree `workspace` 源） |
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
nvim --headless -u NONE -l tests/tab_workspace_roots.lua
```

都是"用户视角"的行为测试：只做用户会做的动作（`:edit`、`:tcd`、开 tab、走 API），断言 `getcwd()`、
`buflisted`、选项值、命令/模板是否存在这类可观察结果，不断言内部实现。
