# ---------------------------------------
# 基础环境
# ---------------------------------------
export ZSH="$HOME/.zsh"
export EDITOR="nvim"
export LANG="en_US.UTF-8"

# ---------------------------------------
# Zinit 插件管理器
# ---------------------------------------
if [[ ! -f "${HOME}/.zinit/bin/zinit.zsh" ]]; then
    echo "Installing Zinit..."
    mkdir -p "${HOME}/.zinit"
    git clone https://github.com/zdharma-continuum/zinit.git "${HOME}/.zinit/bin"
fi
source "${HOME}/.zinit/bin/zinit.zsh"

# ---------------------------------------
# Powerlevel10k（异步提示符）
# ---------------------------------------
zinit ice depth"1"
zinit light romkatv/powerlevel10k

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
POWERLEVEL9K_DISABLE_GITSTATUS=false
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ---------------------------------------
# 历史记录
# ---------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory inc_append_history share_history
setopt hist_ignore_all_dups hist_save_no_dups hist_ignore_space
setopt autocd notify correct

# ---------------------------------------
# 插件（安全 lazy-loading）
# ---------------------------------------

# fast-syntax-highlighting（延迟加载）
zinit ice depth"1" wait"0" lucid
zinit light zdharma-continuum/fast-syntax-highlighting

# autosuggestions（延迟加载）
zinit ice depth"1" wait"0" lucid
zinit light zsh-users/zsh-autosuggestions

# fzf-tab（必须在 zsh-vi-mode 之前）
zinit ice depth"1" wait"1" lucid
zinit light Aloxaf/fzf-tab

# autopair
zinit ice depth"1" wait"1" lucid pick"autopair.zsh"
zinit load hlissner/zsh-autopair

# auto-notify
zinit ice depth"1" wait"1" lucid
zinit load MichaelAquilina/zsh-auto-notify

# zsh-vi-mode（必须在 fzf-tab 之后）
zinit ice depth"1" wait"2" lucid
zinit load jeffreytse/zsh-vi-mode

# fzf（必须在 zsh-vi-mode 之后）
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ---------------------------------------
# fzf-tab 配置
# ---------------------------------------
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no

zstyle ':fzf-tab:*' fzf-flags --height=60% --reverse
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' switch-group '<' '>'

zstyle ':fzf-tab:complete:*:*' fzf-preview '
if [[ -f $realpath ]]; then
    bat --style=numbers --color=always $realpath 2>/dev/null || cat $realpath
elif [[ -d $realpath ]]; then
    lsd -la --color=always $realpath 2>/dev/null || ls -la --color=always $realpath
else
    echo $realpath
fi'

# ---------------------------------------
# zsh-vi-mode 配置
# ---------------------------------------
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

# ---------------------------------------
# auto-notify 配置
# ---------------------------------------
export AUTO_NOTIFY_THRESHOLD=30
export AUTO_NOTIFY_TITLE="命令完成"
export AUTO_NOTIFY_IGNORE=("vim" "nvim" "man" "less" "more" "top" "htop")

# ---------------------------------------
# fzf 配置
# ---------------------------------------
export FZF_DEFAULT_OPTS="\
--height 50% \
--layout=reverse \
--preview '([[ -f {} ]] && bat --style=numbers --color=always --line-range :500 {}) || ([[ -d {} ]] && lsd -t {} || echo {})' \
--preview-window=right:60%"

# ---------------------------------------
# 补全系统（无报错）
# ---------------------------------------
autoload -Uz compinit
compinit -u

autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ---------------------------------------
# 别名
# ---------------------------------------
alias la='lsd -a'
alias lt='lsd --tree'
alias ls='lsd'
alias ff='bash ~/ff.sh'
alias update-all='bash ~/update-all.sh'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gcm='git commit -m'
alias gco='git checkout'
alias gl='git log --oneline --graph'
alias gd='git diff'

# ---------------------------------------
# 自定义函数
# ---------------------------------------
reload() {
    source ~/.zshrc
    echo "Zsh configuration reloaded!"
}

fh() {
    print -z $(history | fzf --height=40% --reverse | sed 's/ *[0-9]* *//')
}

fe() {
    local file
    file=$(fzf --query="$1" --select-1 --exit-0 --height=40% --reverse)
    [ -n "$file" ] && ${EDITOR} "$file"
}

# ---------------------------------------
# 其他工具
# ---------------------------------------
eval "$(zoxide init zsh)"

source /Users/lijia/.config/broot/launcher/bash/br
