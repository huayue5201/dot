" 设置 fzf 窗口在下方占用 40%
let g:fzf_layout = { 'down': '40%' }

" 使用 fzf#wrap 包装调用，确保应用布局设置
nnoremap <Leader>ff :call fzf#run(fzf#wrap({'sink': 'e', 'down': '40%'}))<CR>

" 自动隐藏状态栏并在离开 fzf 窗口时恢复状态栏
autocmd! FileType fzf
autocmd FileType fzf set laststatus=0 noshowmode noruler
  \| autocmd BufLeave <buffer> set laststatus=2 showmode ruler

" 使用 g:fzf_action 自定义打开文件的方式
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }
