" 在终端模式下绑定 Ctrl-L 清除屏幕
tnoremap <C-l> <C-\><C-n>:call term_sendkeys(0, 'clear' . "\r")<CR>
