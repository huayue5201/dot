" https://github.com/kevinhwang91/nvim-bqf

if exists('b:current_syntax')
   finish
endif

" 匹配文件名
syn match qfFileName /^[^│]*/ nextgroup=qfSeparatorLeft
" 匹配分隔符
syn match qfSeparatorLeft /│/ contained nextgroup=qfLineNr
" 匹配行号
syn match qfLineNr /[^│]*/ contained nextgroup=qfSeparatorRight
" 匹配分隔符右边的内容，包括错误、警告、信息、提示等
syn match qfSeparatorRight '│' contained nextgroup=qfError,qfWarning,qfInfo,qfNote
" 匹配错误信息
syn match qfError / E .*$/ contained
" 匹配警告信息
syn match qfWarning / W .*$/ contained
" 匹配信息
syn match qfInfo / I .*$/ contained
" 匹配提示
syn match qfNote / [NH] .*$/ contained

" 设置高亮
hi def link qfFileName Directory
hi def link qfSeparatorLeft Delimiter
hi def link qfSeparatorRight Delimiter
hi def link qfLineNr LineNr
hi def link qfError DiagnosticError
hi def link qfWarning DiagnosticWarn
hi def link qfInfo DiagnosticInfo
hi def link qfNote DiagnosticHint

let b:current_syntax = 'qf'
