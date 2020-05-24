let b:ctags_running = 0

func! s:update_tags_info(job_buffer)
    let b:tag_dict = {}
    for i in a:job_buffer
        if empty(i)
            continue
        endif
        let item = json_decode(i)
        " call add(l, item)
        if has_key(item, 'line') 
            if has_key(b:tag_dict, item.line)
                let old_name = b:tag_dict[item.line]
                let new_name = item.name
                if len(new_name) > len(old_name)
                    let b:tag_dict[item.line] = item
                endif
            else
                let b:tag_dict[item.line] = item
            endif
        endif
    endfor

endf

function! s:ctags_stdout_cb_nvim(channel, data, event)
    let s:chunks[-1] .= a:data[0]
    call extend(s:chunks, a:data[1:])

endfunction

function! s:ctags_close_cb(channel)
    " read ctags output all.
    let job_buffer = []
    while ch_status(a:channel, {'part':'out'}) == 'buffered'
        let newline = ch_read(a:channel)
        call add(job_buffer, newline)
    endwhile

    call s:update_tags_info(job_buffer)
endfunction

func! s:exit_cb(channel, exit_status)
    let b:ctags_running = 0
endf
func! s:exit_cb_nvim(channel, data, event)
    " read ctags output all.
    " let eof = (a:data == [''])
    " if eof
    "     return
    " endif
    call s:update_tags_info(s:chunks)
    let b:ctags_running = 0
endf

function! s:ctags_err_cb(channel, msg)
    echom 'Error from ctags channel.'  printf("%s, %s", a:event, a:msg)
endfunction

function! s:ctags_err_cb_nvim(channel, data, event)
    let eof = (a:data == [''])
    if eof
        return
    endif
    echom 'Error from ctags channel.'  printf("%s, %s", a:event, a:msg)
endfunction

function! Tag_Update()
    if exists("b:ctags_running") && b:ctags_running == 1
        return 
        " one instance is alreay running.
    endif
    let s:buftype = getbufvar(bufnr(), '&buftype', 'ERROR')
    if !(s:buftype == '' || s:buftype == 'nowrite' || s:buftype == 'acwrite')
        " Not a normal buffer, do not going on.
        return
    endif
    let filename = expand('%:p')
    if filename != '' && filereadable(filename)
        let b:ctags_running = 1
        let cmd = ['ctags', '--fields=*','-f','-', '--extras=+q', '--output-format=json', filename ]
        if has('nvim')
            let s:chunks = ['']
            let callbacks = {"on_stdout": function("s:ctags_stdout_cb_nvim"), 
                        \ 'on_stderr':function("s:ctags_err_cb_nvim"),
                        \ 'on_exit':function('s:exit_cb_nvim'),
                        \ "standout_buffered": v:true }
            let job = jobstart(cmd, callbacks)
        else
            let callbacks = {"close_cb": function("s:ctags_close_cb"),
                        \ 'err_cb':function("s:ctags_err_cb"),
                        \ "out_mode": "nl", 
                        \ "exit_cb": function("s:exit_cb")}
            let job = job_start(cmd, callbacks)
        endif
    endif

endfunction

function! Tag_Get_Current_Tag()
    let filename = expand('%:p')
    if filename == '' || !filereadable(filename)
        return ''
    endif
    if !exists('b:tag_dict')
        " tag_dict does not exist, perform a tag updating task.
        call Tag_Update()
        return ""
    endif
    let s:cur_line = line('.')
    let s:match_list = []
    let s:ret = ''
    if !empty(b:tag_dict)
        for line in range(s:cur_line, 1, -1)
            if has_key(b:tag_dict, line) && get(b:tag_dict[line], 'end', 99999999) >= s:cur_line
                let s:ret = b:tag_dict[line].name
                break
            endif
        endfor
    endif
    return s:ret

endfunction

" augroup Taggy
"     autocmd!
"     au BufReadPost * call Tag_Update()
"     au BufWritePost * call Tag_Update()
" augroup END
