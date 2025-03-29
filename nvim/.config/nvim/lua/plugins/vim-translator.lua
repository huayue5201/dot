-- https://github.com/voldikss/vim-translator?tab=readme-ov-file#gtranslator_default_engines

return {
	"voldikss/vim-translator",
	event = "BufReadPost",
	config = function()
		vim.cmd([[
    """ Configuration example
    " Echo translation in the cmdline
    nmap <silent> <Leader>tm <Plug>Translate
    vmap <silent> <Leader>tm <Plug>TranslateV
    " Display translation in a window
    nmap <silent> <Leader>tw <Plug>TranslateW
    vmap <silent> <Leader>tw <Plug>TranslateWV
    " Replace the text with translation
    nmap <silent> <Leader>tlr <Plug>TranslateR
    vmap <silent> <Leader>tlr <Plug>TranslateRV
    " Translate the text in clipboard
    nmap <silent> <Leader>tx <Plug>TranslateX
        nnoremap <silent><expr> <M-f> translator#window#float#has_scroll() ?
                                \ translator#window#float#scroll(1) : "\<M-f>"
    nnoremap <silent><expr> <M-b> translator#window#float#has_scroll() ?
                              \ translator#window#float#scroll(0) : "\<M-b>"
      ]])
	end,
}
