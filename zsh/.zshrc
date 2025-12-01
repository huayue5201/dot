# ---------------------------------------
# 基础环境
# ---------------------------------------
export ZSH="$HOME/.zsh"
export EDITOR="nvim"
export LANG="en_US.UTF-8"

# ---------------------------------------
# Zinit 插件管理器安装
# GitHub: https://github.com/zdharma-continuum/zinit
# ---------------------------------------
if [[ ! -f "${HOME}/.zinit/bin/zinit.zsh" ]]; then
    echo "Installing Zinit..."
    mkdir -p "${HOME}/.zinit"
    git clone https://github.com/zdharma-continuum/zinit.git "${HOME}/.zinit/bin"
fi

# 加载 Zinit
source "${HOME}/.zinit/bin/zinit.zsh"

# ---------------------------------------
# Powerlevel10k 主题
# GitHub: https://github.com/romkatv/powerlevel10k
# ---------------------------------------
zinit ice depth"1"
zinit light romkatv/powerlevel10k

# 禁用配置向导
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ---------------------------------------
# 历史记录配置
# ---------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt inc_append_history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_space
setopt correct
setopt autocd
setopt notify

# ---------------------------------------
# 插件配置
# ---------------------------------------

# fast-syntax-highlighting: https://github.com/zdharma-continuum/fast-syntax-highlighting
zinit ice depth"1" wait"0" lucid
zinit light zdharma-continuum/fast-syntax-highlighting

# https://github.com/larkery/zsh-histdb
zinit ice depth"1" wait"2" lucid
zinit light larkery/zsh-histdb

# zsh-autosuggestions: https://github.com/zsh-users/zsh-autosuggestions
zinit ice depth"1" wait"0" lucid
zinit light zsh-users/zsh-autosuggestions

# 延迟加载，提升启动速度
zinit ice depth"1" wait"2" lucid
zinit light Aloxaf/fzf-tab

# zsh-vi-mode: https://github.com/jeffreytse/zsh-vi-mode
zinit ice depth"1" wait"1" lucid
zinit load jeffreytse/zsh-vi-mode

# autopair: https://github.com/hlissner/zsh-autopair
zinit ice depth"1" wait"1" lucid pick"autopair.zsh"
zinit load hlissner/zsh-autopair

# https://github.com/MichaelAquilina/zsh-auto-notify
zinit ice depth"1" wait"1" lucid
zinit load MichaelAquilina/zsh-auto-notify

# ---------------------------------------
# histdb 配置
# ---------------------------------------
# 忽略某些命令不写入数据库（同 zsh 的 HISTORY_IGNORE 机制）
export HISTORY_IGNORE="(ls|cd|top|htop|clear)"
# 如果你安装了 zsh‑autosuggestions，你可以让它用 histdb 做建议：
if type _zsh_autosuggest_strategy_histdb_top_here &>/dev/null; then
  ZSH_AUTOSUGGEST_STRATEGY=histdb_top_here
fi
# 在 macOS 上，如果你看到输出分隔怪异，可以加入：
HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')

_zsh_autosuggest_strategy_histdb_top_here() {
    local query="select commands.argv from
history left join commands on history.command_id = commands.rowid
left join places on history.place_id = places.rowid
where places.dir LIKE '$(sql_escape $PWD)%'
and commands.argv LIKE '$(sql_escape $1)%'
group by commands.argv order by count(*) desc limit 1"
    suggestion=$(_histdb_query "$query")
}

ZSH_AUTOSUGGEST_STRATEGY=histdb_top_here

# ---------------------------------------
# fzf-tab 配置
# ---------------------------------------
# 禁用 git checkout 排序
zstyle ':completion:*:git-checkout:*' sort false
# 补全描述格式
zstyle ':completion:*:descriptions' format '[%d]'
# 启用 list-colors
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# 禁用原生补全菜单
zstyle ':completion:*' menu no
# fzf-tab 核心配置
zstyle ':fzf-tab:*' fzf-flags --height=60% --reverse 
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# 切换补全组
zstyle ':fzf-tab:*' switch-group '<' '>'

# 预览配置（关键）
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -la --color=always $realpath 2>/dev/null || ls -la --color=always $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'lsd -la --color=always $realpath 2>/dev/null || ls -la --color=always $realpath'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'lsd -la --color=always $realpath 2>/dev/null || ls -la --color=always $realpath'

# 文件预览
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

# 启动时使用插入模式
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

# ---------------------------------------
# autopair 配置
# ---------------------------------------
# 如果需要额外的 autopair 配置可以在这里添加
# export AUTOPAIR_BETWEEN_WHITESPACE=1

# ---------------------------------------
# auto-notify 配置
# ---------------------------------------
export AUTO_NOTIFY_THRESHOLD=30  # 命令执行超过30秒才通知
export AUTO_NOTIFY_TITLE="命令完成"
# export AUTO_NOTIFY_BODY="命令: {command} (运行时间: {time})"
export AUTO_NOTIFY_IGNORE=("vim" "nvim" "man" "less" "more" "top" "htop")

# ---------------------------------------
# fzf 配置（无边框版本）
# ---------------------------------------
export FZF_DEFAULT_OPTS="\
--height 50% \
--layout=reverse \
--preview '([[ -f {} ]] && bat --style=numbers --color=always --line-range :500 {}) || ([[ -d {} ]] && lsd -t {} || echo {})' \
--preview-window=right:60%"

# ---------------------------------------
# 补全系统
# ---------------------------------------
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# zinit 自身命令补全
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ---------------------------------------
# 命令别名
# ---------------------------------------
alias la='lsd -a'
alias lt='lsd -t'
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
# 快速重新加载配置
reload() {
    source ~/.zshrc
    echo "Zsh configuration reloaded!"
}

# 查找历史命令
fh() {
    print -z $(history | fzf --height=40% --reverse | sed 's/ *[0-9]* *//')
}

# 查找文件并编辑
fe() {
    local file
    file=$(fzf --query="$1" --select-1 --exit-0 --height=40% --reverse)
    [ -n "$file" ] && ${EDITOR} "$file"
}

# ---------------------------------------
# 其他工具初始化
# ---------------------------------------

# zoxide: https://github.com/ajeetdsouza/zoxide
eval "$(zoxide init zsh)"

# fzf 自动补全和键绑定
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# 加载 p10k 配置（如果存在）
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# bun completions
[ -s "/Users/lijia/.bun/_bun" ] && source "/Users/lijia/.bun/_bun"
