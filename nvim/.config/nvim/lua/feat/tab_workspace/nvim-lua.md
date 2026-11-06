# `.nvim.lua` 参考

工作区本地配置文件的完整说明。想先了解"工作区"是什么，看同目录的 `README.md`。

## 是什么

在工作区根目录放一个 `.nvim.lua`，它只在这个工作区里生效。切走（切 tab、切根目录、关 tab）时，
通过 `w.*` 登记的每一项改动都会被还原；切回来时重新加载。

对标物：Emacs 的 `.dir-locals.el`、VS Code 的 `.vscode/settings.json`、JetBrains 的 `.idea/`。
区别是这里**不需要新建格式**：`w.*` 只是 Lua 里几个登记函数。

## 位置与发现规则

- 位置：`<工作区根>/.nvim.lua`，工作区根 = 当前 tab 的 `:tcd` 值（statusline 左侧显示的那个名字）。
- 只认**当前 tab 的根**，不向父目录递归查找。monorepo 里想给子项目单独配置，就在子项目目录建。
- 没有这个文件：什么都不做（零开销，不报错）。
- 修改后重载：`:lua require("feat.tab_workspace").reload_local_settings()`，
  或切到别的根再切回来。编辑入口 `<leader>lwe`（文件不存在时按模板创建）。

## 信任

首次加载会走 Neovim 的 `vim.secure.read`，也就是 `:trust` 那套：

- 未信任 → 静默跳过，配置不生效；
- 选择信任后会写进信任列表，之后自动加载；
- 想撤销信任：`:trust` 查看/管理。

因为文件是可执行 Lua，信任是必须的一步；`.nvim.lua` 里可以做任何事，不限于本节列出的 API。

## 生效时机

| 事件 | 行为 |
|---|---|
| `VimEnter` | 启动时按当前 tab 的根加载 |
| `TabEnter` | 切 tab → 卸载旧工作区配置、加载新工作区的 |
| `DirChanged` | `:tcd` / `:cd` 换了根 → 同上 |
| `User TabWorkspaceRoot` | `<leader>lws` / `lwr` / `lwR` 改了根 → 同上 |
| 会话恢复 `post_load` | 恢复完各 tab 的根之后同步一次 |
| `BufReadPost` / `FileType` | 新打开的文件若在根下，自动套用 `w.opt` 与 `w.map` |

作用域判定看**文件路径是否在根下**，不是"当前 tab 的 buffer 列表"，所以后台载入的 buffer 也正确。

## API

所有 API 都在文件顶部的局部变量 `w` 上（进入文件时已预置，不用 require）。

### `w.opt(table)`

根目录下所有 buffer 的 **buffer-local** 选项。已打开的 buffer 立即生效，之后打开的自动生效。

```lua
w.opt({ tabstop = 4, shiftwidth = 4, expandtab = false, textwidth = 100 })
```

回滚：每个 buffer 恢复到**它自己**加载时的原值（不是全局值）。同一 buffer 被重复设置只记第一次的原值。

### `w.global_opt(table)`

全局选项（`vim.o` 级别）。适合 `spelllang`、`path`、`grepprg` 这类没有 buffer-local 版本的选项。

```lua
w.global_opt({ spelllang = { "cjk", "en" } })
w.global_opt({ grepprg = "rg --vimgrep" })
```

回滚：恢复设置前的原值（数组型选项也按原样恢复）。

### `w.au(event, opts?, fn)`

自动命令，挂在工作区自己的 augroup 里，**离开工作区时整个 augroup 被删除**，不需要你清理。

```lua
w.au("BufWritePre", { pattern = "*.rs" }, function(args)
  vim.lsp.buf.format({ bufnr = args.buf })
end)

w.au({ "BufEnter", "FocusGained" }, function() end) -- 无 opts 的简写
```

### `w.cmd(name, fn, opts?)`

用户命令。离开时删除。

```lua
w.cmd("Build", function(args)
  vim.cmd("!make " .. args.args)
end, { nargs = "*", desc = "构建当前项目" })
```

命令名是全局的：如果同名命令已存在（别的插件或另一个工作区），会跳过并提示，不会覆盖。

### `w.map(modes, lhs, rhs, opts?)`

根下所有 buffer 的 buffer-local 键位。离开时删除。

```lua
w.map("n", "<leader>B", "<cmd>Build<cr>", { desc = "构建" })
w.map({ "n", "v" }, "<leader>F", function() ... end)
```

注意这里是 **buffer-local**：不会占用全局键位，也不会在别的项目里误触。

### `w.task(spec)`

登记一个任务，出现在 overseer 的 `:OverseerRun`（`<leader>ru`）列表里。离开工作区后从列表消失。

| 字段 | 必填 | 说明 |
|---|---|---|
| `name` | ✅ | 列表里显示的名字 |
| `cmd` | ✅ | 命令行，字符串（走 shell）或数组（直接 spawn） |
| `args` | | 参数数组，追加在 `cmd` 后面 |
| `cwd` | | 工作目录，默认 `${workspaceFolder}` |
| `env` | | 环境变量表 |
| `components` | | overseer 组件，默认 `{ "default" }`；要快速修复加 `"on_output_quickfix"` |
| `desc` / `tags` / `condition` | | 原样传给 overseer |

```lua
w.task({ name = "构建", cmd = { "cargo", "build" }, components = { "default", "on_output_quickfix" } })
w.task({
  name = "跑当前测试",
  cmd = { "cargo", "test" },
  args = { "${fileBasenameNoExtension}" },
  env = { RUST_BACKTRACE = "1" },
})
```

`${...}` 在**任务启动那一刻**展开（所以 `${file}` 是触发时的 buffer）。

### `w.launch(spec)`

登记一个调试配置，注入 `dap.configurations[filetype]`，`:DapContinue` 列表里可选。离开时按引用摘除。

除 `filetype`（用于选择注入到哪个 filetype 的配置列表）外，其余字段就是标准 nvim-dap 配置，原样透传：

```lua
w.launch({
  name = "调试当前文件",
  filetype = "rust",
  type = "codelldb",
  request = "launch",
  program = "${workspaceFolder}/target/debug/app",
  args = {},
  cwd = "${workspaceFolder}",
})
```

占位符**不展开**，交给 nvim-dap 运行时处理（它认 `${file}`、`${workspaceFolder}`、`${fileBasename}`、
`${fileDirname}`、`${env:VAR}` 等）。因为 `${workspaceFolder}` 在 nvim-dap 里取的是当前 cwd，而工作区的
cwd 就是它的根，所以两者天然一致。

## 占位符

任务里支持（调试配置交给 nvim-dap）：

| 占位符 | 展开为 |
|---|---|
| `${workspaceFolder}` | 工作区根 |
| `${workspaceFolderBasename}` | 根的末段 |
| `${file}` | 触发时的 buffer 完整路径 |
| `${fileBasename}` | 文件名 |
| `${fileBasenameNoExtension}` | 文件名去扩展名 |
| `${fileDirname}` | buffer 所在目录 |
| `${fileExtname}` | 扩展名 |

未知占位符原样保留，不做猜测替换。

## 回滚边界

| 登记方式 | 离开时 |
|---|---|
| `w.opt` | 每个 buffer 恢复自己的原值 |
| `w.global_opt` | 恢复原值 |
| `w.au` | augroup 整体删除 |
| `w.cmd` | `:delcommand` |
| `w.map` | `nvim_buf_del_keymap` |
| `w.task` | 从 overseer 模板列表消失 |
| `w.launch` | 从 `dap.configurations` 摘除 |

**不保证回滚的**（刻意）：直接写 `vim.o`、`vim.keymap.set`（全局）、改 `runtimepath`、装 autocmd 到别人的
augroup、后台定时器。这些没有登记，没法精确撤销——文件开头就写了这条。需要可回滚就用 `w.*`。

`vim.secure.read` 未信任、或语法错误时：不加载任何一项（不会留半套配置），错误进 `:messages`。

## 示例：一个 Rust 项目

```lua
-- .nvim.lua
w.opt({ tabstop = 4, shiftwidth = 4, textwidth = 100 })

w.task({ name = "构建", cmd = { "cargo", "build" }, components = { "default", "on_output_quickfix" } })
w.task({ name = "全部测试", cmd = { "cargo", "test" }, components = { "default", "on_output_quickfix" } })
w.task({ name = "Clippy", cmd = { "cargo", "clippy", "--all-targets" } })

w.launch({
  name = "调试可执行文件",
  filetype = "rust",
  type = "codelldb",
  request = "launch",
  program = "${workspaceFolder}/target/debug/app",
})

w.map("n", "<leader>B", "<cmd>OverseerRun<cr>", { desc = "本项目任务" })
```

## 示例：monorepo 里只给子项目配置

`repo/packages/api/.nvim.lua` 只在该子目录成为工作区根时生效。在 `repo/` 开工作区则完全不加载——
没有"向上继承"，避免一个大仓库的配置偷偷影响所有子项目。

## 排查

| 症状 | 检查 |
|---|---|
| 配置没生效 | `:messages` 有无 `工作区配置: ...`；根是否真的是该目录（`:pwd` / statusline）；文件是否被 `:trust` |
| 切走后选项还留着 | 是否用了 `w.*` 以外的写法直接改选项 |
| 任务没出现 | `<leader>ru` 里看列表；`w.task` 是否漏了 `cmd`；overseer 是否加载 |
| 调试配置没出现 | `filetype` 是否写对（按当前 buffer 的 `:set ft?`）；`:DapContinue` 才列配置 |

相关测试：`tests/tab_workspace_local_settings.lua`（进项目生效 / 新 buffer 生效 / 切走全量还原 /
切回重新生效 / 任务与调试注入摘除 / 语法错误不留半套配置）。
