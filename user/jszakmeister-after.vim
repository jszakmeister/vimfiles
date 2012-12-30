" Set up some variables that can be overridden by a machine specific
" configuration file.
let g:SZAK_BIGGER_FONT=""

if $VIMMACHINE == ""
    let $VIMMACHINE=substitute(system("uname -n"), "\n", "", "")
endif

let s:VIMMACHINE_CONFIG = $VIMUSERFILES . "/" . $VIMUSER .
    \ "/machine/" . $VIMMACHINE . ".vim"

" If a machine local config exists, source it.
if filereadable(s:VIMMACHINE_CONFIG)
    execute "source " . s:VIMMACHINE_CONFIG
endif

if has("mac") || has("macunix")
    let Tlist_Ctags_Cmd='/Users/jszakmeister/.local/bin/ctags'
    let g:tagbar_ctags_bin = '/Users/jszakmeister/.local/bin/ctags'
endif

" Some reminders of the tag-related shortcuts, since I tend to check my
" configuration first.
" C-] - go to definition
" C-T - Jump back from the definition.
" C-W C-] - Open the definition in a horizontal split

" C-\ - Open the definition in a new tab
" A-] - Open the definition in a vertical split
map <C-\> :tab split<CR>:exec("tag ".expand("<cword>"))<CR>
map <A-]> :vsp <CR>:exec("tag ".expand("<cword>"))<CR>

" Emulate SlickEdit w/Emacs bindings: Use Ctrl-. and Ctrl-,
" to pop in and out of the tags
"nnoremap <C-.> :tag
"nnoremap <C-,> :pop

colorscheme szakdark

if !has("gui_running")
    if (has("mac") || has("macunix")) && $TERM_PROGRAM == "iTerm.app"
        " This works only in iTerm... but that's what I use on the Mac.
        " Set the cursor to a vertical line in insert mode.
        let &t_SI = "\<Esc>]50;CursorShape=1\x7"
        let &t_EI = "\<Esc>]50;CursorShape=0\x7"
    elseif $COLORTERM == "gnome-terminal"
        if &t_Co <= 16
            set t_Co=256
        endif
    endif
endif

" Turn on fancy symbols on the status line
if has("gui_running")
    let fontname=["Droid Sans Mono", "Inconsolata"]
    if g:SZAK_BIGGER_FONT == "true"
        let fontsize="16"
    else
        let fontsize="14"
    endif

    if filereadable(expand("~/Library/Fonts/DroidSansMonoSlashed-Powerline.ttf")) ||
       \ filereadable(expand("~/.fonts/DroidSansMonoSlashed-Powerline.ttf"))
        let fontname=["Droid Sans Mono Slashed for Powerline"]
        let g:Powerline_symbols = 'fancy'
    endif

    if has("mac") || has("macunix")
        let fontstring=join(map(copy(fontname), 'v:val . ":h" . fontsize'), ",")
    else
        let fontstring=join(map(copy(fontname), 'v:val . " " . fontsize'), ",")
    endif

    let &guifont=fontstring
endif

if has("gui_macvim")
    set macmeta
endif

set nowrap

" Use ack for grep
if executable('ack')
    set grepprg=ack
    set grepformat=%f:%l:%m
endif

" Be compatible with both grep on Linux and Mac
let Grep_Xargs_Options = '-0'

" Add a method to switch to the scratch buffer
function! ToggleScratch()
    if expand('%') == g:ScratchBufferName
        quit
    else
        Sscratch
    endif
endfunction

map <leader>s :call ToggleScratch()<CR>

" The next several entries are taken from:
"     <http://stevelosh.com/blog/2010/09/coming-home-to-vim/>

" Split the window vertically, and go to it.
nnoremap <leader>w <C-w>v<C-w>l

" Highlight Clojure's builtins and turn on rainbow parens
let g:vimclojure#HighlightBuiltins=1
let g:vimclojure#ParenRainbow=1

" Treat forms that start with def as lispwords
let g:vimclojure#FuzzyIndent=1

" I keep my nailgun client in ~/.local/bin.  If it's there, then let
" VimClojure know.
if executable(expand("~/.local/bin/ng"))
    let g:vimclojure#NailgunClient=expand("~/.local/bin/ng")
endif

" I often want to close a buffer without closing the window
nnoremap <leader><leader>d :BD<CR>

function! SetupManPager()
    setlocal nonu nolist
    nnoremap <Space> <PageDown>
    nnoremap b <PageUp>
    nnoremap q :quit<CR>
endfunction
command! SetupManPager call SetupManPager()

augroup jszakmeister_vimrc
    autocmd FileType man call setpos("'\"", [0, 0, 0, 0])|exe "normal! gg"
augroup end

" Make Command-T ignore some Clojure/Java-related bits.
set wildignore+=target/**,asset-cache

" I regularly create tmp folders that I don't want searched
set wildignore+=tmp,.lein-*,*.egg-info,.*.swo

" Shortcut for clearing CtrlP caches
nnoremap <Leader><Leader>r :<C-U>CtrlPClearAllCaches<CR>

" Use CtrlP in place of Command-T
nnoremap <Leader><Leader>t :<C-U>CtrlP<CR>
nnoremap <Leader><Leader>b :<C-U>CtrlPBuffer<CR>

" Don't open multiple files in vertical splits.  Just open them, and re-use the
" buffer already at the front.
let g:ctrlp_open_multiple_files = '1vr'

" Add some mappings for Regrep since I don't use the function keys.
vnoremap <expr> <Leader><Leader>g VisualRegrep()
nnoremap <expr> <Leader><Leader>g NormalRegrep()

" Add a mapping for the Quickfix window.  Unfortunately, C-Q doesn't appear to
" work in a terminal.
nnoremap <Leader><Leader>q :call QuickFixWinToggle()<CR>

" On remote systems, I like to chnge the background color so that I remember I'm
" on a remote system. :-)  This does break when you sudo su to root though.
if !empty($SSH_TTY)
    hi Normal guibg=#0d280d
endif

" Redefine a few functions because I want tabstops to always be 8

" -------------------------------------------------------------
" Setup for plain text.
" -------------------------------------------------------------
function! SetupText()
    setlocal tw=80 ts=8 sts=2 sw=2 et ai
    let b:SpellType = "<text>"
endfunction

" -------------------------------------------------------------
" Setup for general source code.
" -------------------------------------------------------------
function! SetupSource()
    setlocal tw=80 ts=8 sts=4 sw=4 et ai
    Highlight longlines tabs trailingspace
    let b:SpellType = "<source>"
endfunction

" -------------------------------------------------------------
" Setup for markup languages like HTML, XML, ....
" -------------------------------------------------------------
function! SetupMarkup()
    setlocal tw=80 ts=8 sts=2 sw=2 et ai
    runtime scripts/closetag.vim
    runtime scripts/xml.vim
    let b:SpellType = "<markup>"
endfunction

" -------------------------------------------------------------
" Setup for Markdown.
" -------------------------------------------------------------
function! SetupMarkdown()
    call SetupMarkup()
endfunction

function! SetupRst()
    setlocal tw=80 ts=8 sts=2 sw=2 et ai
endfunction

" Powerline

" Add back in a few segments...
call Pl#Theme#InsertSegment('mode_indicator', 'after', 'paste_indicator')
call Pl#Theme#InsertSegment('filetype', 'before', 'scrollpercent')
call Pl#Theme#InsertSegment('fileformat', 'before', 'filetype')

call Pl#Theme#InsertSegment('ws_marker', 'after', 'lineinfo')
