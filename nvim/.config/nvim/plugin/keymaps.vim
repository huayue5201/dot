" 在终端模式下绑定 Ctrl-L 清除屏幕
tnoremap <C-l> <C-\><C-n>:call term_sendkeys(0, 'clear' . "\r")<CR>

" 删除当前文件的交换文件
nnoremap <leader>csw :call DeleteCurrentSwapFile()<CR>

function! DeleteCurrentSwapFile()
    let current_file = expand('%:p')
    if empty(current_file)
        echo "没有对应的文件路径。"
        return
    endif

    " 获取 Neovim 的交换文件目录配置
    let swap_dir = &directory
    " 移除末尾的 // 和逗号分隔的其他路径
    let swap_dir = substitute(swap_dir, '//.*$', '', '')
    let swap_dir = substitute(swap_dir, ',.*$', '', '')

    " 展开路径
    let swap_dir = expand(swap_dir)

    " 构造交换文件的完整路径（Neovim 格式）
    " 将路径中的 / 替换为 %，并添加 .swp 后缀
    let escaped_path = substitute(current_file, '/', '%', 'g')
    let swap_file = swap_dir . '/' . escaped_path . '.swp'

    " 检查主交换文件
    if filereadable(swap_file)
        if delete(swap_file) == 0
            echo "已删除交换文件: " . swap_file
            return
        else
            echo "删除失败: " . swap_file
        endif
    endif

    " 尝试其他后缀（.swo, .swn, .swm）
    let found = 0
    for suffix in ['.swo', '.swn', '.swm']
        let try_file = swap_dir . '/' . escaped_path . suffix
        if filereadable(try_file)
            echo "找到交换文件: " . try_file
            if delete(try_file) == 0
                echo "已删除: " . try_file
                let found = 1
                break
            endif
        endif
    endfor

    if !found
        " 尝试使用 v:swapname 获取实际路径
        let actual_swap = v:swapname
        if !empty(actual_swap) && filereadable(actual_swap)
            echo "找到交换文件: " . actual_swap
            if delete(actual_swap) == 0
                echo "已删除: " . actual_swap
                return
            endif
        endif

        echo "未找到交换文件: " . swap_file
    endif
endfunction

" 删除所有交换文件
nnoremap <leader>csW :call DeleteAllSwapFiles()<CR>

function! DeleteAllSwapFiles()
    let count = 0
    let swap_dir = &directory
    let swap_dir = substitute(swap_dir, '//.*$', '', '')
    let swap_dir = substitute(swap_dir, ',.*$', '', '')
    let swap_dir = expand(swap_dir)

    if !isdirectory(swap_dir)
        echo "交换文件目录不存在: " . swap_dir
        return
    endif

    " 递归查找所有交换文件
    let files = split(globpath(swap_dir, '**/*.swp'), '\n')
    let files += split(globpath(swap_dir, '**/*.swo'), '\n')
    let files += split(globpath(swap_dir, '**/*.swn'), '\n')
    let files += split(globpath(swap_dir, '**/*.swm'), '\n')

    if empty(files)
        echo "未找到交换文件"
        return
    endif

    " 去重
    let files = uniq(sort(files))

    for file in files
        if delete(file) == 0
            let count += 1
        endif
    endfor

    echo "已删除 " . count . " 个交换文件"
endfunction
