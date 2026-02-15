" 在终端模式下绑定 Ctrl-L 清除屏幕
tnoremap <C-l> <C-\><C-n>:call term_sendkeys(0, 'clear' . "\r")<CR>

" 映射 <leader>sw 删除当前文件的.swp文件
" FIX:ref:71830f
nnoremap <leader>csw :call DeleteCurrentSwapFile()<CR>

" 映射 <leader>sW 递归删除当前目录下所有.swp文件 (谨慎使用)
nnoremap <leader>csW :call DeleteAllSwapFiles()<CR>

function! DeleteCurrentSwapFile()
    let current_file = expand('%:p')
    if empty(current_file)
        echo "没有对应的文件路径。"
        return
    endif
    " 构造对应的.swp文件路径 (注意：交换文件名以 '.' 开头)
    let swapfile = fnamemodify(current_file, ':h') . '/.' . fnamemodify(current_file, ':t') . '.swp'
    if filereadable(swapfile)
        if delete(swapfile) == 0
            echo "已删除交换文件: " . swapfile
        else
            echo "删除失败: " . swapfile
        endif
    else
        echo "未找到交换文件: " . swapfile
    endif
endfunction

function! DeleteAllSwapFiles()
    let swapfiles = split(globpath('.', '.*.swp'), '\n')
    if len(swapfiles) == 0
        echo "当前目录下未找到.swp文件。"
        return
    endif
    let count = 0
    for file in swapfiles
        if delete(file) == 0
            let count += 1
        endif
    endfor
    echo "已删除 " . count . " 个交换文件。"
endfunction
