# https://github.com/zdharma-continuum/zinit
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
   print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
   command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
   command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
      print -P "%F{33} %F{34}Installation successful.%f%b" || \
      print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of zinit installer's chunk

# https://github.com/starship/starship
# starship主题
zinit ice as"command" from"gh-r" \
   atclone"./starship init zsh > init.zsh; ./starship completions zsh > _starship" \
   atpull"%atclone" src"init.zsh"
   zinit light starship/starship

# fzf
zinit ice from"gh-r" as"program"
zinit light junegunn/fzf-bin

# BurntSushi/ripgrep
zinit ice as"command" from"gh-r" mv"ripgrep* -> rg" pick"rg/rg"
zinit light BurntSushi/ripgrep

# sharkdp/fd
zinit ice as"command" from"gh-r" mv"fd* -> fd" pick"fd/fd"
zinit light sharkdp/fd

# https://github.com/zdharma/fast-syntax-highlighting
# Autosuggestions & fast-syntax-highlighting
zinit ice wait"1" lucid atinit"zpcompinit; zpcdreplay" atload"FAST_HIGHLIGHT[chroma-git]=\"chroma/-ogit.ch\""
zinit light zdharma/fast-syntax-highlighting
# https://github.com/zsh-users/zsh-autosuggestions
zinit ice wait"1" lucid atload"!_zsh_autosuggest_start"
zinit load zsh-users/zsh-autosuggestions

# https://github.com/zsh-users/zsh-completions
zinit ice wait lucid
zinit light zsh-users/zsh-completions

# https://github.com/jeffreytse/zsh-vi-mode
zinit ice depth=1
zinit light jeffreytse/zsh-vi-mode

# https://github.com/hlissner/zsh-autopair
zinit ice wait lucid
zinit load hlissner/zsh-autopair

# https://github.com/cantino/mcfly
zinit ice lucid wait"0a" from"gh-r" as"program" atload'eval "$(mcfly init zsh)"'
zinit light cantino/mcfly

# https://github.com/lsd-rs/lsd
zinit ice as"command" from"gh-r" mv"lsd* -> lsd" pick"lsd/lsd"
zinit light lsd-rs/lsd

# https://github.com/ajeetdsouza/zoxide
zinit ice as"command" from"gh-r" mv"zoxide* -> zoxide" pick"zoxide/zoxide"
zinit light ajeetdsouza/zoxide

# sharkdp/bat
zinit ice as"command" from"gh-r" mv"bat* -> bat" pick"bat/bat"
zinit light sharkdp/bat

# mcfly
# 使用vim按键模式
export MCFLY_KEY_SCHEME=vim
# 启用模糊搜索
export MCFLY_FUZZY=2
# 主题设置 TOP和BOTTOM
export MCFLY_INTERFACE_VIEW=BOTTOM
# 提示符
export MCFLY_PROMPT="❯"
# mcfly配色,macos根据系统更改配色
if [[ "$(defaults read -g AppleInterfaceStyle 2&>/dev/null)" != "Dark" ]]; then
   export MCFLY_LIGHT=TRUE
fi

# fzf
# 使用 fd ( https://github.com/sharkdp/fd )代替默认的 find
_fzf_compgen_path() {
   fd --hidden --follow --exclude ".git" . "$1"
}
# 使用 fd 生成目录完成的列表
_fzf_compgen_dir() {
   fd --type d --hidden --follow --exclude ".git" . "$1"
}
# 设置参数
export FZF_DEFAULT_OPTS='--height 40% --layout reverse --info inline --border --preview "bat --style=numbers --color=always --line-range :500 {}" --color=bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672'

# yazi
function ya() {
   tmp="$(mktemp -t "yazi-cwd.XXXXX")"
   yazi --cwd-file="$tmp"
   if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      cd -- "$cwd"
   fi
   rm -f -- "$tmp"
}

# PATH配置
export DELTA_FEATURES=+side-by-side # activate
export DELTA_FEATURES=+             # deactivate
# python
export PATH=$PATH:~/.local/bin
# cargo PATH (rust)
export PATH=$PATH:~/.cargo/bin
# npm PATH
PATH=$PATH:/usr/local/bin/
export NODE_PATH="/usr/local/lib/node_modules"

# vps代理
export http_proxy=http://127.0.0.1:8889
export https_proxy=$http_proxy

# 别名
# alias j=__zoxide_z
alias zf=__zoxide_zi
eval "$(zoxide init zsh)"
alias ls='lsd'
alias lt='ls --tree'

#历史纪录条目数量
export HISTSIZE=10000
#注销后保存的历史纪录条目数量
export SAVEHIST=10000
#历史纪录文件
export HISTFILE=~/.histfile
#以附加的方式写入历史纪录
setopt INC_APPEND_HISTORY
#如果连续输入的命令相同，历史纪录中只保留一个
setopt HIST_IGNORE_DUPS
#为历史纪录中的命令添加时间戳
setopt EXTENDED_HISTORY
#启用 cd 命令的历史纪录，cd -[TAB]进入历史路径
setopt AUTO_PUSHD
#相同的历史路径只保留一个
setopt PUSHD_IGNORE_DUPS
#在命令前添加空格，不将此命令添加到纪录文件中
setopt HIST_IGNORE_SPACE
# 不保留重复的历史记录项
setopt hist_ignore_all_dups
# 在命令前添加空格，不将此命令添加到记录文件中
setopt hist_ignore_space
# zsh 4.3.6 doesn't have this option
setopt hist_fcntl_lock 2>/dev/null
setopt hist_reduce_blanks
# 共享历史记录
setopt SHARE_HISTORY

