# ---------------------------------------
# 基础环境
# ---------------------------------------
export ZSH="$HOME/.zsh"
export EDITOR="nvim"
export LANG="en_US.UTF-8"

# herdr 强制 pane 使用 TERM=xterm-256color，而该 terminfo 无 smxx 能力，
# 会让 Neovim 认为终端不支持删除线，从而不再输出 SGR 9（\e[9m）。
# 覆盖 terminfo 以恢复删除线渲染（只影响 nvim，不影响其他程序）。
if [ "$TERM_PROGRAM" = "herdr" ]; then
  export NVIM_TERMDEFS='{"enter_strikethrough_mode":"\u001b[9m"}'
fi

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
# 历史记录
# ---------------------------------------
HISTFILE=~/.zsh_history
# 不启用 hist_ignore_all_dups / hist_save_no_dups：会把频率信息抹掉，
# 而 histdb 的“常用命令”排序依赖完整记录。
HISTSIZE=50000
SAVEHIST=50000
setopt appendhistory inc_append_history share_history
setopt hist_ignore_space
setopt autocd notify correct

# ---------------------------------------
# zsh-histdb（SQLite 历史库）
# ---------------------------------------
# 每条命令额外记录 工作目录 / 退出码 / 耗时 / 会话 / 主机。
# macOS 上 sqlite3 的行分隔符处理需要这个（见 upstream README）。
HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
# 等价于 hist_ignore_space：以空格开头的命令不入库（histdb 用 HISTORY_IGNORE）。
HISTORY_IGNORE=' *'
source "$HOME/.zhistdb/sqlite-history.zsh"

# ---------------------------------------
# 插件（安全 lazy-loading）
# ---------------------------------------

# fast-syntax-highlighting（延迟加载）
zinit ice depth"1" wait"0" lucid
zinit light zdharma-continuum/fast-syntax-highlighting

# autosuggestions（延迟加载）
zinit ice depth"1" wait"0" lucid
zinit light zsh-users/zsh-autosuggestions

# autosuggestions 用 histdb 的建议策略（本目录优先、按使用频率），
# 没有命中时回落到原来的 history 策略。
_zsh_autosuggest_strategy_histdb_top_here() {
    local query="select commands.argv from
history left join commands on history.command_id = commands.rowid
left join places on history.place_id = places.rowid
where places.dir LIKE '$(sql_escape $PWD)%'
and commands.argv LIKE '$(sql_escape $1)%'
group by commands.argv order by count(*) desc limit 1"
    suggestion=$(_histdb_query "$query")
}
ZSH_AUTOSUGGEST_STRATEGY=(histdb_top_here history)

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
# 用 wait 延迟加载，初始化时会重置键位；fzf 的 ^R 必须等它初始化后再绑定。
zinit ice depth"1" wait"2" lucid
zinit load jeffreytse/zsh-vi-mode

# 找 fzf 的 key bindings（Homebrew 安装，只有 key-bindings，不含 completion，
# 避免抢掉 fzf-tab 的 Tab 补全）。
_fzf_key_bindings="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh"
if [[ ! -r "$_fzf_key_bindings" ]]; then
  _fzf_key_bindings="/usr/local/opt/fzf/shell/key-bindings.zsh"
fi
if [[ ! -r "$_fzf_key_bindings" && -r "$HOME/.fzf.zsh" ]]; then
  _fzf_key_bindings="$HOME/.fzf.zsh"
fi

if [[ -r "$_fzf_key_bindings" ]]; then
  # 先绑一次，保证 zsh-vi-mode 延迟初始化前也能用。
  source "$_fzf_key_bindings"
  # zsh-vi-mode 初始化后它会重置键位，这里再绑一次，解决“过几秒 ^R 失效”。
  zvm_after_init_commands+=("source '$_fzf_key_bindings'")
fi
unset _fzf_key_bindings

# ---------------------------------------
# histdb 的 ^R 选择器（必须在 fzf key-bindings 之后绑定）
# ---------------------------------------
# Enter 只放进编辑缓冲区不执行；Alt-h 只看本机，Alt-d 只看当前目录及子目录，
# Alt-j 跳到该条目执行时所在的目录。
source "$HOME/.zhistdb/histdb-fzf.zsh"
bindkey '^R' _fzf_histdb_widget
# zsh-vi-mode 初始化会重置键位，再绑一次。
zvm_after_init_commands+=("bindkey '^R' _fzf_histdb_widget")

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

# viins 里 C-a/C-e/C-f/C-u 默认是 self-insert，这里改成 readline 风格的行为。
# zsh-vi-mode 初始化时会重置键位，所以用 after_init 再绑一次。
zvm_after_init_commands+=('bindkey -M viins "^A" beginning-of-line')
zvm_after_init_commands+=('bindkey -M viins "^E" end-of-line')
zvm_after_init_commands+=('bindkey -M viins "^F" forward-char')
zvm_after_init_commands+=('bindkey -M viins "^U" kill-whole-line')

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
    local q=${1//\'/\'\'}
    local cmd
    cmd=$(_histdb_query "select argv from commands where argv like '%${q}%' group by argv order by max(id) desc limit 1000" |
        fzf --height=40% --reverse --query="$1")
    [[ -n $cmd ]] && print -z -- "$cmd"
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
# https://github.com/starship/starship
eval "$(starship init zsh)"

# OSC 133 语义提示符：neovim 核心的 `]]`/`[[` 跳提示符用它，状态栏/wrapper
# 类工具也常读它。A = 提示符开始，B = 提示符结束、用户输入开始。
# starship 每次 precmd 都会重设 PROMPT，所以要在它之后重新加上（add-zsh-hook
# 按注册顺序执行）。
autoload -Uz add-zsh-hook
_starship_osc133_prompt() {
  PROMPT=$'\e]133;A\a'"${PROMPT}"$'\e]133;B\a'
}
add-zsh-hook precmd _starship_osc133_prompt

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export PATH="$HOME/.rustowl:$PATH"
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# >>> otty shell integration >>>
# Added by Otty — toggle in Settings > Shell > Shell Integration.
# Inert unless launched by Otty (it sets $OTTY_SHELL_INTEGRATION).
if [ -n "$OTTY_SHELL_INTEGRATION" ] && [ -r "$OTTY_SHELL_INTEGRATION/otty-integration.zsh" ]; then
  . "$OTTY_SHELL_INTEGRATION/otty-integration.zsh"
fi
# <<< otty shell integration <<<
