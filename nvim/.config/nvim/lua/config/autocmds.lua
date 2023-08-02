-- 自动定位到最后编辑的位置
vim.cmd([[
    autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif
]])

-- yy高亮复制范围
vim.cmd([[
    augroup YankHighlight
    autocmd!
    autocmd TextYankPost * silent! lua vim.highlight.on_yank()
    augroup end
 ]])
