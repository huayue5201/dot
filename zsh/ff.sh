#!/usr/bin/env bash
# ===================================================
# ff.sh - 项目快速切换器（优化版）
# ===================================================

CACHE_FILE="$HOME/.cache/ff_projects.txt"
HISTORY_FILE="$HOME/.cache/ff_history.txt"
SEARCH_DIRS=(~/MCU-Project ~/python_project ~/golang_project)
MAX_DEPTH=3
PREVIEW_LIMIT=50

mkdir -p "$(dirname "$CACHE_FILE")" "$(dirname "$HISTORY_FILE")"

# -------------------------------
# 检查依赖
# -------------------------------
for cmd in fd fzf lsd; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "❌ 请安装 $cmd"
    exit 1
  }
done

# -------------------------------
# 历史权重衰减（30天衰减一半，最小1）
# -------------------------------
decay_history() {
  [[ ! -f "$HISTORY_FILE" ]] && return
  local last_mod
  if stat --version &>/dev/null; then
    last_mod=$(stat -c %Y "$HISTORY_FILE" 2>/dev/null || echo 0)
  else
    last_mod=$(stat -f %m "$HISTORY_FILE" 2>/dev/null || echo 0)
  fi
  local now=$(date +%s)
  local decay_sec=2592000 # 30天
  while [[ $now -gt $((last_mod + decay_sec)) ]]; do
    awk '{ $2=int($2*0.5); if($2<1) $2=1; print }' "$HISTORY_FILE" >"${HISTORY_FILE}.tmp"
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    last_mod=$((last_mod + decay_sec))
  done
}

decay_history

# -------------------------------
# 刷新项目缓存函数
# -------------------------------
refresh_cache() {
  fd . "${SEARCH_DIRS[@]}" -t d \
    -E "*/target/*" -E "*/build/*" -E "*/.git/*" -d "$MAX_DEPTH"
}

# -------------------------------
# 清理历史中已删除的项目
# -------------------------------
cleanup_history() {
  [[ ! -f "$HISTORY_FILE" ]] && return
  awk '{ if (system("[ -d \"" $1 "\" ]") == 0) print $0 }' "$HISTORY_FILE" >"${HISTORY_FILE}.tmp"
  mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
}

cleanup_history

# -------------------------------
# 合并历史权重
# -------------------------------
merge_history() {
  local cache_file="$1"
  awk -v hist="$HISTORY_FILE" '
    BEGIN {
      while ((getline < hist) > 0) { weights[$1]=$2 }
    }
    {
      w = ($0 in weights) ? weights[$0] : 0
      print w "\t" $0
    }
  ' "$cache_file" | sort -nr
}

# -------------------------------
# 主逻辑
# -------------------------------
projects_with_weight=$(merge_history <(refresh_cache))

selected_repo=$(
  echo "$projects_with_weight" |
    cut -f2- |
    fzf --ansi --prompt="📁 选择项目: " \
      --header='🛠️  ↑↓选择，回车进入，Ctrl-R刷新列表' \
      --bind "ctrl-r:reload($(merge_history <(refresh_cache)))" \
      --preview "
        echo '📦 ' \$(basename {})
        if [ -d '{}/.git' ]; then
          echo '🌀 Branch: ' \$(git -C {} rev-parse --abbrev-ref HEAD 2>/dev/null)
          git -C {} --no-pager log -1 --oneline | head -n 1
        fi
        echo
        lsd -A -1 --color always --icon always --icon-theme fancy {} | head -n $PREVIEW_LIMIT
      "
)

# -------------------------------
# 进入项目并更新历史权重
# -------------------------------
if [[ -n "$selected_repo" ]]; then
  cd "$selected_repo" || exit
  nvim

  if grep -q "^$selected_repo " "$HISTORY_FILE" 2>/dev/null; then
    awk -v path="$selected_repo" '
      $1 == path { $2 = $2 + 1 }
      { print }
    ' "$HISTORY_FILE" >"${HISTORY_FILE}.tmp"
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
  else
    echo "$selected_repo 1" >>"$HISTORY_FILE"
  fi
fi
