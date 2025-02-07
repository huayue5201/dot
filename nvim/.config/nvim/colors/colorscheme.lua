-- 基础颜色
vim.api.nvim_set_hl(0, "Normal", { fg = "#d4d4d4", bg = "#1c1c1c" }) -- 正常文本
vim.api.nvim_set_hl(0, "Comment", { fg = "#8a8a8a", italic = true }) -- 注释
vim.api.nvim_set_hl(0, "Constant", { fg = "#d787af" }) -- 常量
vim.api.nvim_set_hl(0, "String", { fg = "#afd787" }) -- 字符串
vim.api.nvim_set_hl(0, "Identifier", { fg = "#87afd7" }) -- 变量名
vim.api.nvim_set_hl(0, "Function", { fg = "#d7af87" }) -- 函数名
vim.api.nvim_set_hl(0, "Keyword", { fg = "#87afd7" }) -- 关键字
vim.api.nvim_set_hl(0, "Type", { fg = "#87afd7" }) -- 类型
vim.api.nvim_set_hl(0, "Special", { fg = "#d7af87" }) -- 特殊字符
vim.api.nvim_set_hl(0, "Error", { fg = "#ff5f5f", bg = "#1c1c1c" }) -- 错误
vim.api.nvim_set_hl(0, "Warning", { fg = "#ffaf5f", bg = "#1c1c1c" }) -- 警告
vim.api.nvim_set_hl(0, "Info", { fg = "#5fd7ff", bg = "#1c1c1c" }) -- 信息
vim.api.nvim_set_hl(0, "Hint", { fg = "#afd787", bg = "#1c1c1c" }) -- 提示

-- UI 元素
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a2a" }) -- 光标行
vim.api.nvim_set_hl(0, "Visual", { bg = "#3a3a3a" }) -- 可视模式
vim.api.nvim_set_hl(0, "LineNr", { fg = "#8a8a8a", bg = "#1c1c1c" }) -- 行号
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#d4d4d4", bg = "#2a2a2a" }) -- 光标行号
vim.api.nvim_set_hl(0, "Pmenu", { fg = "#d4d4d4", bg = "#2a2a2a" }) -- 弹出菜单
vim.api.nvim_set_hl(0, "PmenuSel", { fg = "#1c1c1c", bg = "#87afd7" }) -- 选中菜单项
vim.api.nvim_set_hl(0, "StatusLine", { fg = "#d4d4d4", bg = "#2a2a2a" }) -- 状态栏
vim.api.nvim_set_hl(0, "StatusLineNC", { fg = "#8a8a8a", bg = "#1c1c1c" }) -- 非活动状态栏

-- 语义令牌高亮组
vim.api.nvim_set_hl(0, "@lsp.type.namespace", { fg = "#87afd7" }) -- 命名空间
vim.api.nvim_set_hl(0, "@lsp.type.type", { fg = "#87afd7" }) -- 类型
vim.api.nvim_set_hl(0, "@lsp.type.class", { fg = "#87afd7" }) -- 类
vim.api.nvim_set_hl(0, "@lsp.type.enum", { fg = "#87afd7" }) -- 枚举
vim.api.nvim_set_hl(0, "@lsp.type.interface", { fg = "#87afd7" }) -- 接口
vim.api.nvim_set_hl(0, "@lsp.type.struct", { fg = "#87afd7" }) -- 结构体
vim.api.nvim_set_hl(0, "@lsp.type.typeParameter", { fg = "#87afd7" }) -- 类型参数
vim.api.nvim_set_hl(0, "@lsp.type.parameter", { fg = "#d4d4d4" }) -- 函数参数
vim.api.nvim_set_hl(0, "@lsp.type.variable", { fg = "#d4d4d4" }) -- 变量
vim.api.nvim_set_hl(0, "@lsp.type.property", { fg = "#d4d4d4" }) -- 属性
vim.api.nvim_set_hl(0, "@lsp.type.enumMember", { fg = "#d787af" }) -- 枚举成员
vim.api.nvim_set_hl(0, "@lsp.type.event", { fg = "#d7af87" }) -- 事件
vim.api.nvim_set_hl(0, "@lsp.type.function", { fg = "#d7af87" }) -- 函数
vim.api.nvim_set_hl(0, "@lsp.type.method", { fg = "#d7af87" }) -- 方法
vim.api.nvim_set_hl(0, "@lsp.type.macro", { fg = "#d7af87" }) -- 宏
vim.api.nvim_set_hl(0, "@lsp.type.keyword", { fg = "#87afd7" }) -- 关键字
vim.api.nvim_set_hl(0, "@lsp.type.modifier", { fg = "#87afd7" }) -- 修饰符
vim.api.nvim_set_hl(0, "@lsp.type.comment", { fg = "#8a8a8a", italic = true }) -- 注释
vim.api.nvim_set_hl(0, "@lsp.type.string", { fg = "#afd787" }) -- 字符串
vim.api.nvim_set_hl(0, "@lsp.type.number", { fg = "#d787af" }) -- 数字
vim.api.nvim_set_hl(0, "@lsp.type.regexp", { fg = "#afd787" }) -- 正则表达式
vim.api.nvim_set_hl(0, "@lsp.type.operator", { fg = "#d4d4d4" }) -- 操作符

-- Treesitter 高亮组
vim.api.nvim_set_hl(0, "@function", { fg = "#d7af87" }) -- 函数
vim.api.nvim_set_hl(0, "@function.call", { fg = "#d7af87" }) -- 函数调用
vim.api.nvim_set_hl(0, "@method", { fg = "#d7af87" }) -- 方法
vim.api.nvim_set_hl(0, "@method.call", { fg = "#d7af87" }) -- 方法调用
vim.api.nvim_set_hl(0, "@variable", { fg = "#d4d4d4" }) -- 变量
vim.api.nvim_set_hl(0, "@variable.builtin", { fg = "#87afd7" }) -- 内置变量
vim.api.nvim_set_hl(0, "@parameter", { fg = "#d4d4d4" }) -- 函数参数
vim.api.nvim_set_hl(0, "@property", { fg = "#d4d4d4" }) -- 属性
vim.api.nvim_set_hl(0, "@string", { fg = "#afd787" }) -- 字符串
vim.api.nvim_set_hl(0, "@string.regex", { fg = "#afd787" }) -- 正则表达式
vim.api.nvim_set_hl(0, "@number", { fg = "#d787af" }) -- 数字
vim.api.nvim_set_hl(0, "@boolean", { fg = "#d787af" }) -- 布尔值
vim.api.nvim_set_hl(0, "@keyword", { fg = "#87afd7" }) -- 关键字
vim.api.nvim_set_hl(0, "@keyword.function", { fg = "#87afd7" }) -- 函数关键字
vim.api.nvim_set_hl(0, "@keyword.return", { fg = "#87afd7" }) -- return 关键字
vim.api.nvim_set_hl(0, "@type", { fg = "#87afd7" }) -- 类型
vim.api.nvim_set_hl(0, "@type.builtin", { fg = "#87afd7" }) -- 内置类型
vim.api.nvim_set_hl(0, "@constructor", { fg = "#87afd7" }) -- 构造函数
vim.api.nvim_set_hl(0, "@namespace", { fg = "#87afd7" }) -- 命名空间
vim.api.nvim_set_hl(0, "@punctuation.delimiter", { fg = "#d4d4d4" }) -- 分隔符
vim.api.nvim_set_hl(0, "@punctuation.bracket", { fg = "#d4d4d4" }) -- 括号
vim.api.nvim_set_hl(0, "@comment", { fg = "#8a8a8a", italic = true }) -- 注释
vim.api.nvim_set_hl(0, "@operator", { fg = "#d4d4d4" }) -- 操作符
