#!/bin/sh
# Rex 外观设置（对齐 Ghostty：Iosevka 16 / cell 16x45px / 120x37）。
# Rex 不读 ~/.config/ghostty/config，外观存在 UserDefaults 域 com.superlogical.rex，
# 键名沿用 "Workspace.<property>"，因此只能用 defaults 写入。
#
#   ./settings.sh          # 应用
#   ./settings.sh show     # 查看当前值
#   ./settings.sh reset    # 清除本脚本写入的键（回到 Rex 默认）
#
# 应用后需重启 Rex.app 才生效（服务端与会话不受影响）：
#   pkill -f "Rex Beta.app/Contents/MacOS/Rex"; open -a "Rex Beta"
set -eu
D=com.superlogical.rex
K_FONT=Workspace.terminalFontName
K_SIZE=Workspace.terminalFontPointSize
K_CELLH=Workspace.terminalCellHeightPercent
K_LIG=Workspace.terminalAllowsLigatures
K_FRAME="NSWindow Frame session-AppWindow-1"

case "${1:-apply}" in
show)
  for k in "$K_FONT" "$K_SIZE" "$K_CELLH" "$K_LIG" "$K_FRAME"; do
    printf '%s = %s\n' "$k" "$(defaults read "$D" "$k" 2>/dev/null || echo '<unset>')"
  done
  ;;
reset)
  for k in "$K_FONT" "$K_SIZE" "$K_CELLH" "$K_LIG"; do defaults delete "$D" "$k" 2>/dev/null || true; done
  echo "已清除外观键（窗口 frame 保留）"
  ;;
apply)
  defaults write "$D" "$K_FONT" -string Iosevka
  defaults write "$D" "$K_SIZE" -float 16
  # Rex 的 cellHeightPercent 是「相对自然行高的增量百分比」：自然 20pt，12.5 → 22.5pt = 45px @2x
  # 对应 Ghostty 的 `adjust-cell-height = 5`
  defaults write "$D" "$K_CELLH" -float 12.5
  defaults write "$D" "$K_LIG" -bool true
  # 窗口像素尺寸无配置项，靠 AppKit 恢复 frame：x y w h screenX screenY screenW screenH
  # 996x940 @ 1512x949 屏 → 内容 120 列 x 37 行
  defaults write "$D" "$K_FRAME" -string "258 4 996 940 0 0 1512 949"
  echo "已写入。重启 Rex.app 生效："
  echo '  pkill -f "Rex Beta.app/Contents/MacOS/Rex"; open -a "Rex Beta"'
  ;;
*)
  echo "用法: $0 [apply|show|reset]" >&2
  exit 2
  ;;
esac
