-- https://github.com/RRethy/vim-illuminate

return {
  "RRethy/vim-illuminate",
  event = "BufReadPost",
  config = function()
    require('illuminate').configure({
      -- providers: 用于获取缓冲区中引用的提供者，按照优先级排序
      providers = {
        'lsp',
        'treesitter',
        'regex',
      },
      -- delay: 延迟时间（以毫秒为单位）
      delay = 100,
      -- filetype_overrides: 针对特定文件类型的覆盖配置。
      -- 键是文件类型字符串，值是支持 .configure 方法中相同键的表，但不包括 filetypes_denylist 和 filetypes_allowlist
      filetype_overrides = {},
      -- filetypes_denylist: 不高亮的文件类型，会覆盖 filetypes_allowlist
      filetypes_denylist = {
        'dirbuf',
        'dirvish',
        'fugitive',
      },
      -- filetypes_allowlist: 允许高亮的文件类型，会被 filetypes_denylist 覆盖
      -- 如果需要生效，必须将 filetypes_denylist 设置为空表 {}
      filetypes_allowlist = {},
      -- modes_denylist: 不高亮的模式，会覆盖 modes_allowlist
      -- 查看 `:help mode()` 获取可能的值
      modes_denylist = {},
      -- modes_allowlist: 允许高亮的模式，会被 modes_denylist 覆盖
      -- 查看 `:help mode()` 获取可能的值
      modes_allowlist = {},
      -- providers_regex_syntax_denylist: 不高亮的语法，会覆盖 providers_regex_syntax_allowlist
      -- 仅适用于 'regex' 提供器
      -- 使用命令 :echom synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name') 查看语法名称
      providers_regex_syntax_denylist = {},
      -- providers_regex_syntax_allowlist: 允许高亮的语法，会被 providers_regex_syntax_denylist 覆盖
      -- 仅适用于 'regex' 提供器
      -- 使用命令 :echom synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name') 查看语法名称
      providers_regex_syntax_allowlist = {},
      -- under_cursor: 是否高亮光标下的单词
      under_cursor = true,
      -- large_file_cutoff: 超过此行数时，使用 large_file_config 配置
      -- 当达到此阈值时，将禁用 under_cursor 选项
      large_file_cutoff = nil,
      -- large_file_config: 针对大文件的配置（根据 large_file_cutoff 决定）。
      -- 支持与 .configure 方法相同的键。
      -- 如果为 nil，则针对大文件将禁用 vim-illuminate。
      large_file_overrides = nil,
      -- min_count_to_highlight: 需要匹配的最小数量以启用高亮
      min_count_to_highlight = 1,
      -- should_enable: 一个回调函数，用于覆盖所有其他设置以启用/禁用高亮。
      -- 此函数会被频繁调用，因此不要在其中执行耗时操作。
      should_enable = function(bufnr) return true end,
      -- case_insensitive_regex: 设置正则表达式的大小写敏感性
      case_insensitive_regex = false,
    })
  end
}
