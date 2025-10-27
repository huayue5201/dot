#!/usr/bin/env bash
# ===================================================
# ff.sh - 项目快速切换器（直接执行，刷新优化）
# ===================================================

CACHE_FILE="$HOME/.cache/ff_projects.txt"
HISTORY_FILE="$HOME/.cache/ff_history.txt"
SEARCH_DIRS=(~/MCU-Project ~/python_project)
MAX_DEPTH=3

mkdir -p "$(dirname "$CACHE_FILE")" "$(dirname "$HISTORY_FILE")"

# -------------------------------
# 1️⃣ 历史权重衰减（30天衰减一半，最小1）
# -------------------------------
if [[ -f "$HISTORY_FILE" ]]; then
  if stat --version &>/dev/null; then
    last_mod=$(stat -c %Y "$HISTORY_FILE" 2>/dev/null || echo 0)
  else
    last_mod=$(stat -f %m "$HISTORY_FILE" 2>/dev/null || echo 0)
  fi

  if [[ $(date +%s) -gt $((last_mod + 2592000)) ]]; then
    awk '{ $2=int($2*0.5); if ($2<1) $2=1; print }' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" &&
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" &&
    touch "$HISTORY_FILE"
  fi
fi

# -------------------------------
# 2️⃣ 项目缓存（每次刷新）
# -------------------------------
fd . "${SEARCH_DIRS[@]}" -t d \
  -E "*/target/*" -E "*/build/*" -E "*/.git/*" -d "$MAX_DEPTH" > "$CACHE_FILE"

# -------------------------------
# 3️⃣ 清理历史中已删除的项目
# -------------------------------
if [[ -f "$HISTORY_FILE" ]]; then
  awk '{ if (system("[ -d \"" $1 "\" ]") == 0) print $0 }' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
  mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
fi

# -------------------------------
# 4️⃣ 合并历史权重
# -------------------------------
projects_with_weight=$(
  awk -v hist="$HISTORY_FILE" '
    BEGIN {
      while ((getline < hist) > 0) { weights[$1]=$2 }
    }
    {
      w = ($0 in weights) ? weights[$0] : 0
      print w "\t" $0
    }
  ' "$CACHE_FILE" | sort -nr
)

# -------------------------------
# 5️⃣ fzf 选择
# -------------------------------
selected_repo=$(
  echo "$projects_with_weight" |
  cut -f2- |
  fzf --ansi --prompt="📁 选择项目: " \
      --header='🛠️  ↑↓选择，回车进入，Ctrl-R刷新列表' \
      --bind "ctrl-r:reload(fd . ${SEARCH_DIRS[*]} -t d -E '*/target/*' -E '*/build/*' -E '*/.git/*' -d $MAX_DEPTH)" \
      --preview '
        echo "📦 $(basename {})"
        if [ -d "{}/.git" ]; then
          echo "🌀 Branch: $(git -C {} rev-parse --abbrev-ref HEAD 2>/dev/null)"
          git -C {} --no-pager log -1 --oneline | head -n 1
        fi
        echo
        lsd -A -1 --color always --icon always --icon-theme fancy {}
      '
)

# -------------------------------
# 6️⃣ 进入项目并更新历史权重
# -------------------------------
if [[ -n "$selected_repo" ]]; then
  cd "$selected_repo" || exit
  nvim

  if grep -q "^$selected_repo " "$HISTORY_FILE" 2>/dev/null; then
    awk -v path="$selected_repo" '
      $1 == path { $2 = $2 + 1 }
      { print }
    ' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
  else
    echo "$selected_repo 1" >> "$HISTORY_FILE"
  fi
fi
