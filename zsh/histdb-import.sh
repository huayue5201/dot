#!/usr/bin/env zsh
# 把 zsh 的纯文本历史导入 zsh-histdb（支持 extended 与 plain 两种格式）。
#
#   用法: histdb-import.sh [~/.zsh_history]
#
# 纯文本历史没有目录/退出码/耗时信息，这些字段留空：
#   places.dir = ''，history.exit_status = null，duration = 0。
set -euo pipefail

histfile=${1:-$HOME/.zsh_history}
db=${HISTDB_FILE:-$HOME/.histdb/zsh-history.db}
host=${HOST:-$(hostname -s)}

[[ -r $histfile ]] || { print -u2 "读不到 $histfile"; exit 1; }
[[ -f $db ]] || { print -u2 "没有 $db，先在 zsh 里 source sqlite-history.zsh 跑一条命令"; exit 1; }

esc() { print -r -- ${${1//\'/\'\'}//$'\x00'} }

sql=$(mktemp "${TMPDIR:-/tmp}/histdb-import.XXXXXX")
trap 'rm -f -- $sql' EXIT

print -r -- "BEGIN;" > $sql
print -r -- "INSERT OR IGNORE INTO places(host, dir) VALUES('$(esc $host)', '');" >> $sql

main() {
typeset -a records   # 每条: "<ts>\t<cmd>"
ts=0
cmd=""
extended=0
first=1

flush() {
    [[ -z $cmd ]] && return
    records+=("${ts}"$'\t'"${cmd}")
    cmd=""
}

while IFS= read -r line || [[ -n $line ]]; do
    if (( first )); then
        [[ $line == :\ [0-9]* ]] && extended=1
        first=0
    fi
    if (( extended )); then
        if [[ $line == (:\ [0-9]##:[0-9]##\;*|:\ [0-9]##\;*) ]]; then
            flush
            local rest=${line#: }
            ts=${rest%%:*}
            [[ $rest == *\;* ]] && cmd=${rest#*;}
        elif [[ $cmd == *\\ ]]; then
            cmd=${cmd%\\}$'\n'$line
        else
            cmd="$cmd"$'\n'"$line"
        fi
    else
        if [[ -z $cmd ]]; then
            cmd=$line
        elif [[ $cmd == *\\ ]]; then
            cmd=${cmd%\\}$'\n'$line
        else
            flush
            cmd=$line
        fi
    fi
done < "$histfile"
flush

# plain 格式没有时间戳：按文件顺序倒推，保证相对顺序正确。
if (( ! extended )); then
    local base=$(( $(date -r "$histfile" +%s 2>/dev/null || date +%s) - ${#records} )) i=1
    local -a fixed
    for r in "${records[@]}"; do
        fixed+=("$(( base + i ))"$'\t'"${r#*$'\t'}")
        (( i++ ))
    done
    records=("${fixed[@]}")
fi

for r in "${records[@]}"; do
    local t=${r%%$'\t'*}
    local c=${r#*$'\t'}
    local e=$(esc "$c")
    print -r -- "INSERT OR IGNORE INTO commands(argv) VALUES('${e}');" >> $sql
    print -r -- "INSERT INTO history(session, command_id, place_id, exit_status, start_time, duration)
        SELECT 0, (SELECT id FROM commands WHERE argv='${e}'),
               (SELECT id FROM places WHERE host='$(esc $host)' AND dir=''), NULL, ${t}, 0;" >> $sql
done

print -r -- "COMMIT;" >> $sql

before=$(sqlite3 "$db" 'select count(*) from history;')
sqlite3 "$db" < $sql
after=$(sqlite3 "$db" 'select count(*) from history;')
print "导入完成: history ${before} -> ${after} (+$((after - before)))"
}

main "$@"
