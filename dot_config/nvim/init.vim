call plug#begin('~/.local/share/nvim/site/plugged')
" Aesthetics
Plug 'projekt0n/github-nvim-theme'
Plug 'https://github.com/ryanoasis/vim-devicons'
Plug 'junegunn/rainbow_parentheses.vim'
Plug 'junegunn/vim-journal'
Plug 'ryanoasis/vim-devicons'

" Status Bar
Plug 'vim-airline/vim-airline'

" Supporting
Plug 'nvim-lua/plenary.nvim'

" File browsing
Plug 'https://github.com/preservim/nerdtree'

set encoding=UTF-8

call plug#end()

nnoremap <C-f> :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>

:set number
:set relativenumber
:set autoindent
:set tabstop=2
:set shiftwidth=2
:set smarttab
:set softtabstop=2
:set mouse=a

:colorscheme github_dark_high_contrast

