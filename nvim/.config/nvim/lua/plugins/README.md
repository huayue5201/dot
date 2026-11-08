# lua/plugins/ — 插件清单

一个 `.lua` 文件 = 一个插件（或多个 spec 组成的一组）。**目录名只是分类标签**，
不参与加载：`lua/boot/pack.lua` 的 `collect()` 会递归扫描，仍按**文件名**排序，
所以 priority 相同时的声明次序与全部平铺时完全一致。

- 新增插件：放进对应分类目录即可，不需要注册。
- 一个插件需要多个文件时，建成 `分类/名字/init.lua`（该目录会被当成一个 spec 模块，不再递归）。
- 加载是 eager 的：没有 spec 级 `event` / `ft` / `cmd` / `module` / `lazy`；`keys` 默认注册全局映射，
  单条 key 可写 `ft = "lua"`（或 string 列表）改成只在对应 buffer 里注册的 buffer-local 映射。

分类：

| 目录 | 内容 | 数量 |
| --- | --- | --- |
| [`ai/`](ai/) | AI 对话 / 补全 / 外部 agent | 3 |
| [`lsp/`](lsp/) | LSP、格式化、诊断、quickfix | 12 |
| [`dap/`](dap/) | 调试器与容器开发 | 10 |
| [`git/`](git/) | git 界面、diff、冲突、PR | 8 |
| [`ui/`](ui/) | 界面外壳：状态列、标签栏、侧栏、取景器、主题 | 22 |
| [`editor/`](editor/) | 编辑动作：补全、环绕、跳转、滚动动画 | 27 |
| [`lang/`](lang/) | 语言/文件类型相关：treesitter、markdown、拼写、中文 | 18 |
| [`tools/`](tools/) | 独立工具窗：测试、会话、数据库、日志 | 14 |

## ai/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [ai/ask-agent.lua](ai/ask-agent.lua) | huayue5201/ask-agent.nvim | 把问题+代码锚点发给外部 agent（`<leader>aq`） |
| [ai/codecompanion.lua](ai/codecompanion.lua) | olimorris/codecompanion.nvim | AI 聊天 / 内联改写（DeepSeek API） |
| [ai/minuet.lua](ai/minuet.lua) | milanglacier/minuet-ai.nvim | AI 行内补全（ghost text，DeepSeek FIM） |

## lsp/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [lsp/crates.lua](lsp/crates.lua) | saecki/crates.nvim | Cargo.toml 依赖版本管理 |
| [lsp/conform.lua](lsp/conform.lua) | stevearc/conform.nvim | 保存/手动格式化（慢 formatter 异步） |
| [lsp/fidget.lua](lsp/fidget.lua) | j-hui/fidget.nvim | LSP 进度通知 |
| [lsp/lazydev.lua](lsp/lazydev.lua) | folke/lazydev.nvim | 写 lua 配置时的 vim 运行时类型补全 |
| [lsp/lsp-file-operations.lua](lsp/lsp-file-operations.lua) | antosha417/nvim-lsp-file-operations | 改名/移动文件时自动改 import |
| [lsp/mason.lua](lsp/mason.lua) | mason-org/mason.nvim | LSP / 工具安装器 |
| [lsp/namu.lua](lsp/namu.lua) | bassamsdata/namu.nvim | 符号 / 工作区符号选择器 |
| [lsp/nvim-bqf.lua](lsp/nvim-bqf.lua) | kevinhwang91/nvim-bqf | quickfix 增强（预览） |
| [lsp/nvim-lint.lua](lsp/nvim-lint.lua) | mfussenegger/nvim-lint | 外部 linter 诊断（补 LSP 盲区） |
| [lsp/quicker.lua](lsp/quicker.lua) | stevearc/quicker.nvim | quickfix 界面美化 + 上下文预览 |
| [lsp/tiny-code-action.lua](lsp/tiny-code-action.lua) | rachartier/tiny-code-action.nvim | code action 选择浮窗 |
| [lsp/tiny-inline-diagnostic.lua](lsp/tiny-inline-diagnostic.lua) | rachartier/tiny-inline-diagnostic.nvim | 内联诊断（替代内置 virtual_text） |

## dap/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [dap/nvim-dap.lua](dap/nvim-dap.lua) | mfussenegger/nvim-dap | 调试核心（断点 / repl） |
| [dap/nvim-dap-view.lua](dap/nvim-dap-view.lua) | igorlfs/nvim-dap-view | dap-ui 的替代：单窗口 + 视图切换 |
| [dap/nvim-dap-python.lua](dap/nvim-dap-python.lua) | mfussenegger/nvim-dap-python | Python 调试 |
| [dap/nvim-dap-go.lua](dap/nvim-dap-go.lua) | leoluz/nvim-dap-go | Go 调试（dlv） |
| [dap/nvim-dap-docker.lua](dap/nvim-dap-docker.lua) | docker/nvim-dap-docker | 接 `docker buildx debug` |
| [dap/nvim-dap-cortex-debug.lua](dap/nvim-dap-cortex-debug.lua) | jedrzejboczar/nvim-dap-cortex-debug | 嵌入式 ARM / cortex-debug |
| [dap/nvim-dap-disasm.lua](dap/nvim-dap-disasm.lua) | Jorenar/nvim-dap-disasm | 反汇编视图 |
| [dap/nvim-dap-image.lua](dap/nvim-dap-image.lua) | dav1d-wright/nvim-dap-image | 调试时查看图像变量 |
| [dap/nvim-dap-extensions.lua](dap/nvim-dap-extensions.lua) | 本地 | 自定义断点/变量扩展 |
| [dap/nvim-dev-container.lua](dap/nvim-dev-container.lua) | esensar/nvim-dev-container | 读 `.devcontainer.json` 进容器开发 |

## git/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [git/atlas.lua](git/atlas.lua) | emrearmagan/atlas.nvim | GitHub PR / issue 浏览与评审（gh CLI，非 AI） |
| [git/gitsigns.lua](git/gitsigns.lua) | lewis6991/gitsigns.nvim | 状态列 git 标记 / hunk 暂存回滚 |
| [git/neogit.lua](git/neogit.lua) | NeogitOrg/neogit | Magit 风格 git 界面 |
| [git/neogit-ai-commit.lua](git/neogit-ai-commit.lua) | huayue5201/neogit-ai-commit.nvim | 让 AI 生成 commit message（本地 fork） |
| [git/git-conflict.lua](git/git-conflict.lua) | akinsho/git-conflict.nvim | 冲突标记与解决键位 |
| [git/diffbandit.lua](git/diffbandit.lua) | CoreyKaylor/diffbandit.nvim | 三栏 diff（`<leader>H*`） |
| [git/codediff.lua](git/codediff.lua) | esmuellert/codediff.nvim | 侧栏 diff 视图（`<leader>h*`） |
| [git/grug-far.lua](git/grug-far.lua) | MagicDuck/grug-far.nvim | 项目级搜索替换 |

## ui/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [ui/colorscheme.lua](ui/colorscheme.lua) | huayue5201/night-owl.nvim + bytebeast/kissaten.nvim | 主题（night-owl 为主） |
| [ui/statuscol.lua](ui/statuscol.lua) | luukvbaal/statuscol.nvim | 状态列：git/诊断/dap/书签各占一槽 |
| [ui/bufferline.lua](ui/bufferline.lua) | huayue5201/bufferline.nvim | 顶部 buffer 标签栏 |
| [ui/dropbar.lua](ui/dropbar.lua) | Bekaboo/dropbar.nvim | 面包屑导航 |
| [ui/which-key.lua](ui/which-key.lua) | folke/which-key.nvim | 键位提示与分组说明 |
| [ui/tiny-cmdline.lua](ui/tiny-cmdline.lua) | rachartier/tiny-cmdline.nvim | 命令行美化 |
| [ui/colorful-menu.lua](ui/colorful-menu.lua) | xzbdmw/colorful-menu.nvim | 补全菜单按语法着色 |
| [ui/fff.lua](ui/fff.lua) | dmtrKovalenko/fff | 模糊文件查找器（Rust 后端） |
| [ui/glance.lua](ui/glance.lua) | DNLHC/glance.nvim | LSP peek 预览窗 |
| [ui/neo-tree.lua](ui/neo-tree.lua) | nvim-neo-tree/neo-tree.nvim | 文件树侧栏 |
| [ui/nvim-window-picker.lua](ui/nvim-window-picker.lua) | huayue5201/nvim-window-picker | 窗口选择器（本地 fork） |
| [ui/buffer-preview.lua](ui/buffer-preview.lua) | propilideno/buffer-preview.nvim | 切 buffer 前预览内容 |
| [ui/atone.lua](ui/atone.lua) | XXiaoA/atone.nvim | 树状图侧栏（调用/引用图） |
| [ui/bento.lua](ui/bento.lua) | serhez/bento.nvim | 菜单 / 仪表盘（浮窗或 tabline） |
| [ui/nvim-web-devicons.lua](ui/nvim-web-devicons.lua) | nvim-tree/nvim-web-devicons | 文件类型图标 |
| [ui/marks.lua](ui/marks.lua) | chentoast/marks.nvim | 书签（m 系列键位） |
| [ui/todo-comments.lua](ui/todo-comments.lua) | folke/todo-comments.nvim | TODO / FIXME 高亮与检索 |
| [ui/nvim-treesitter-context.lua](ui/nvim-treesitter-context.lua) | nvim-treesitter/nvim-treesitter-context | 顶部固定当前作用域 |
| [ui/visual-whitespace.lua](ui/visual-whitespace.lua) | mcauley-penney/visual-whitespace.nvim | 仅选区显示空白字符 |
| [ui/image.lua](ui/image.lua) | 3rd/image.nvim | 图片渲染（kitty 协议） |
| [ui/focal.lua](ui/focal.lua) | hmdfrds/focal.nvim | 浮动图片查看器 |
| [ui/smart-splits.lua](ui/smart-splits.lua) | smart-splits-nvim/smart-splits.nvim | 分屏 / 复用器之间的跳转与缩放 |

## editor/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [editor/blink.lua](editor/blink.lua) | saghen/blink.cmp | 补全引擎（LSP / path / buffer / snippet） |
| [editor/nvim-autopairs.lua](editor/nvim-autopairs.lua) | windwp/nvim-autopairs | 括号自动配对 |
| [editor/surround.lua](editor/surround.lua) | kylechui/nvim-surround | 增删改包围符号 |
| [editor/treesj.lua](editor/treesj.lua) | Wansmer/treesj | 代码块一键拆 / 合 |
| [editor/dial.lua](editor/dial.lua) | monaqa/dial.nvim | 增减数字 / 日期 / 布尔 |
| [editor/comment-divider.lua](editor/comment-divider.lua) | fangjunzhou/comment-divider.nvim | 插入注释分隔线 / 注释框 |
| [editor/celeste_comment.lua](editor/celeste_comment.lua) | celeste3z/celeste_comment.nvim | 注释切换 |
| [editor/yanky.lua](editor/yanky.lua) | gbprod/yanky.nvim | 剪贴板环（粘贴后可翻历史） |
| [editor/smart-paste.lua](editor/smart-paste.lua) | nemanjamalesija/smart-paste.nvim | 粘贴自动对齐缩进 |
| [editor/text-case.lua](editor/text-case.lua) | johmsalas/text-case.nvim | 大小写 / 命名风格转换（`gau` 等） |
| [editor/visimatch.lua](editor/visimatch.lua) | wurli/visimatch.nvim | 选区模式下高亮匹配项 |
| [editor/vim-illuminate.lua](editor/vim-illuminate.lua) | RRethy/vim-illuminate | 光标下同类符号高亮 |
| [editor/mini-indentscope.lua](editor/mini-indentscope.lua) | nvim-mini/mini.nvim | 缩进范围高亮 |
| [editor/flatten.lua](editor/flatten.lua) | willothy/flatten.nvim | 外部命令打开文件复用当前实例 |
| [editor/neoscroll.lua](editor/neoscroll.lua) | karb94/neoscroll.nvim | 平滑滚动动画（与 smear 兼容配置） |
| [editor/smear-cursor.lua](editor/smear-cursor.lua) | sphamba/smear-cursor.nvim | 光标拖影动画 |
| [editor/refactoring.lua](editor/refactoring.lua) | ThePrimeagen/refactoring.nvim | 提取 / 内联变量与函数 |
| [editor/nvim-scissors.lua](editor/nvim-scissors.lua) | chrisgrieser/nvim-scissors | 代码片段管理 |
| [editor/origami.lua](editor/origami.lua) | chrisgrieser/nvim-origami | 智能折叠（LSP 优先，treesitter 兜底） |
| [editor/chainsaw.lua](editor/chainsaw.lua) | chrisgrieser/nvim-chainsaw | 智能插入调试打印语句 |
| [editor/guess-indent.lua](editor/guess-indent.lua) | NMAC427/guess-indent.nvim | 自动检测缩进风格 |
| [editor/nvim-lastplace.lua](editor/nvim-lastplace.lua) | huayue5201/nvim-lastplace | 回到上次光标位置（本地 fork） |
| [editor/nvim-jump.lua](editor/nvim-jump.lua) | yorickpeterse/nvim-jump | 极简标签跳转（替代 flash，本地 fork，支持中文拼音首字母） |
| [editor/nvim-hlslens.lua](editor/nvim-hlslens.lua) | kevinhwang91/nvim-hlslens | 搜索命中计数与快速跳转 |
| [editor/nvim-regexplainer.lua](editor/nvim-regexplainer.lua) | bennypowers/nvim-regexplainer | 正则可视化解说 |
| [editor/faster.lua](editor/faster.lua) | pteroctopus/faster.nvim | 大文件自动降级（关 treesitter 等） |
| [editor/warp.lua](editor/warp.lua) | nolleh/warp.nvim | 目录书签快速跳转（`<leader>jf`） |

## lang/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [lang/treesitter.lua](lang/treesitter.lua) | nvim-treesitter/nvim-treesitter | 语法树：高亮 / 折叠 / 对象 |
| [lang/nvim-treesitter-textobjects.lua](lang/nvim-treesitter-textobjects.lua) | nvim-treesitter/nvim-treesitter-textobjects | 语法级 textobject 与跳转 |
| [lang/otter.lua](lang/otter.lua) | jmbuhr/otter.nvim | 让 markdown 代码块也有 LSP |
| [lang/rustowl.lua](lang/rustowl.lua) | cordx56/rustowl | Rust 所有权 / 生命周期可视化 |
| [lang/krut.lua](lang/krut.lua) | alexpasmantier/krust.nvim | Rust crate 依赖浮窗（`grk`） |
| [lang/jieba.lua](lang/jieba.lua) | kkew3/jieba.vim | 中文分词（按词移动 / 删除） |
| [lang/im-select.lua](lang/im-select.lua) | hughfenghen/fenghen-im-select.nvim | 进出 insert 自动切输入法 |
| [lang/spellwand.lua](lang/spellwand.lua) | chaneyzorn/spellwand.nvim | 把原生 spell 包成进程内 LSP |
| [lang/dirtytalk.lua](lang/dirtytalk.lua) | psliwka/vim-dirtytalk | 代码词表（给 spell 用） |
| [lang/nvim-translator.lua](lang/nvim-translator.lua) | huayue5201/nvim-translator | 翻译（本地 fork） |
| [lang/sniprun.lua](lang/sniprun.lua) | michaelb/sniprun | 行 / 选区级多语言运行 |
| [lang/markmap.lua](lang/markmap.lua) | Zeioth/markmap.nvim | Markdown → 思维导图 |
| [lang/mdkite.lua](lang/mdkite.lua) | selimacerbas/mdkite.nvim | Markdown 预览（mermaid，`<leader>zm`） |
| [lang/obsidian.lua](lang/obsidian.lua) | obsidian-nvim/obsidian.nvim | Obsidian vault 前端 |
| [lang/render-markdown.lua](lang/render-markdown.lua) | MeanderingProgrammer/render-markdown.nvim | Markdown 原地渲染 |
| [lang/tirenvi.lua](lang/tirenvi.lua) | kibi2/tirenvi.nvim | Markdown / CSV / TSV 表格结构化编辑 |
| [lang/videre.lua](lang/videre.lua) | huayue5201/videre.nvim | JSON / YAML / TOML 画成连线图 |
| [lang/codedocs.lua](lang/codedocs.lua) | jeangiraldoo/codedocs.nvim | 一键插入文档注释（`gcd`） |

## tools/

| 文件 | 插件 | 用途 |
| --- | --- | --- |
| [tools/resession.lua](tools/resession.lua) | stevearc/resession.nvim | 会话保存 / 恢复（tab 工作区） |
| [tools/genghis.lua](tools/genghis.lua) | chrisgrieser/nvim-genghis | 轻量文件操作（`<leader>F`） |
| [tools/gentags.lua](tools/gentags.lua) | linrongbin16/gentags.nvim | 生成 / 更新 ctags |
| [tools/overseer.lua](tools/overseer.lua) | stevearc/overseer.nvim | 任务运行器 |
| [tools/neotest.lua](tools/neotest.lua) | nvim-neotest/neotest | 测试运行框架 |
| [tools/crazy-coverage.lua](tools/crazy-coverage.lua) | mr-u0b0dy/crazy-coverage.nvim | 覆盖率显示（`<leader>tc`） |
| [tools/sqmeow.lua](tools/sqmeow.lua) | 2giosangmitom/sqmeow.nvim | 数据库工作台（SQL / NoSQL） |
| [tools/nvim-store3.lua](tools/nvim-store3.lua) | huayue5201/nvim-store3 | 本地键值存储（todo2 依赖） |
| [tools/todo2.lua](tools/todo2.lua) | huayue5201/todo2 | TODO 管理（本地插件） |
| [tools/cash.lua](tools/cash.lua) | nullromo/cash.nvim | 寄存器 / 剪贴板浏览（`<c-/>`） |
| [tools/nurl.lua](tools/nurl.lua) | rodrigoscc/nurl.nvim | 用 Lua 写 HTTP 请求（替代 kulala） |
| [tools/juan-logs.lua](tools/juan-logs.lua) | minigian/juan-logs.nvim | 大日志文件查看（>100MB） |
| [tools/hexinspector.lua](tools/hexinspector.lua) | Punity122333/hexinspector.nvim | 数字进制 / 位模式查看 |
| [tools/bitwise-visualizer.lua](tools/bitwise-visualizer.lua) | wellatleastitried/bitwise-visualizer.nvim | 位运算可视化 |
