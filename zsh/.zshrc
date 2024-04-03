# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# https://github.com/zdharma-continuum/zinit
# Zinit 插件管理器安装
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
  # 如果未安装 Zinit，则执行以下安装步骤
  print -P "%F{33} %F{220}正在安装 %F{33}Zinit%F{220} 插件管理器 (%F{33}zdharma-continuum/zinit%F{220})…%f"
  command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
  command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
    print -P "%F{33} %F{34}安装成功.%f%b" || \
    print -P "%F{160} 克隆失败.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### Zinit 安装结束

# 使用 zinit_update 作为 zinit update 的别名
alias zinit_update=zinit_update

# https://github.com/romkatv/powerlevel10k
# powerlevel10k
zinit ice depth"1" # git clone depth
zinit light romkatv/powerlevel10k

# Zsh-vi-mode
zinit ice depth=1
zinit light jeffreytse/zsh-vi-mode

# Zsh-autopair
zinit ice wait lucid
zinit load hlissner/zsh-autopair

# Mcfly
zinit ice lucid wait"0a" from"gh-r" as"program" atload'eval "$(mcfly init zsh)"'
zinit light cantino/mcfly

# Lsd
zinit ice as"command" from"gh-r" mv"lsd* -> lsd" pick"lsd/lsd"
zinit light lsd-rs/lsd

# Zoxide
zinit ice as"command" from"gh-r" mv"zoxide* -> zoxide" pick"zoxide/zoxide"
zinit light ajeetdsouza/zoxide

# Fast-syntax-highlighting
# Zsh-completions
# Zsh-autosuggestions
zinit wait lucid for \
 atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
 blockf \
    zsh-users/zsh-completions \
 atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

# Mcfly
# 使用 vim 按键模式
export MCFLY_KEY_SCHEME=vim
# 启用模糊搜索
export MCFLY_FUZZY=2
# 最大搜索数,防止延迟
export MCFLY_HISTORY_LIMIT=10000
# 主题设置 TOP 和 BOTTOM
export MCFLY_INTERFACE_VIEW=BOTTOM
# 禁用菜单栏
export MCFLY_DISABLE_MENU=TRUE
# 提示符
export MCFLY_PROMPT=">"

# Fzf
# 使用 fd 代替默认的 find
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}
# 使用 fd 生成目录完成的列表
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}
# 设置参数
export FZF_DEFAULT_OPTS='--height 40% --layout reverse --info inline --border --preview "bat --color=always --style=numbers --line-range=:500 {}" --color=bg+:#293739,bg:#1B1D1E,border:#808080,spinner:#E6DB74,hl:#7E8E91,fg:#F8F8F2,header:#7E8E91,info:#A6E22E,pointer:#A6E22E,marker:#F92672,fg+:#F8F8F2,prompt:#F92672,hl+:#F92672'

# bat 配置
alias cat="bat --theme=\$(defaults read -globalDomain AppleInterfaceStyle &> /dev/null && echo default || echo GitHub)"

# nnn配置
export PATH=$PATH:$HOME/nnn

# 默认编辑器
export EDITOR=nvim
export VISUAL=nvim

# 路径配置
# Cargo PATH (Rust)
export PATH=$PATH:~/.cargo/bin

# stcgal
export PATH="$PATH:/Users/lijia/Library/Application Support/pipx/venvs/stcgal/bin"

# VPS 代理
export http_proxy=http://127.0.0.1:8889
export https_proxy=$http_proxy

# 别名设置
# alias j=__zoxide_z
alias zf=__zoxide_zi
eval "$(zoxide init zsh)"
alias ls='lsd'
alias lt='ls --tree'

# 函数嵌套数
export FUNCNEST=100
# 历史记录条目数量
export HISTSIZE=10000
# 注销后保存的历史记录条目数量
export SAVEHIST=10000
# 历史记录文件
export HISTFILE=~/.histfile
# 以附加的方式写入历史记录
setopt INC_APPEND_HISTORY
# 如果连续输入的命令相同，历史记录中只保留一个
setopt HIST_IGNORE_DUPS
# 为历史记录中的命令添加时间戳
setopt EXTENDED_HISTORY
# 启用 cd 命令的历史记录，cd -[TAB]进入历史路径
setopt AUTO_PUSHD
# 相同的历史路径只保留一个
setopt PUSHD_IGNORE_DUPS
# 在命令前添加空格，不将此命令添加到纪录文件中
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

# brew
export PATH="/opt/homebrew/bin:$PATH"
# llvm
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
# gcc
export PATH="/opt/homebrew/Cellar/gcc/13.2.0/bin:$PATH"
# Created by `pipx` on 2024-03-13 09:10:48
export PATH="$PATH:/Users/lijia/.local/bin"

export STM32CubeMX_PATH=/Applications/STMicroelectronics/STM32CubeMX.app/Contents/Resources

export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
