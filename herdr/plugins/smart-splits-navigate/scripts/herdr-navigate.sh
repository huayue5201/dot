#!/usr/bin/env bash
#
# smart-splits.nvim — herdr side
#
# Invoked by a herdr keybind:
#   herdr-navigate.sh <left|down|up|right>          -> navigate chord ctrl+hjkl
#   herdr-navigate.sh resize <left|down|up|right>   -> resize chord ctrl+alt+hjkl
#
# Decision table (both modes):
#   1. Focused pane's foreground process matches Vim (or SMART_SPLITS_HERDR_PASSTHROUGH_RE):
#      forward the chord into the pane and let the editor/app decide.
#   2. Otherwise:
#      - navigate: `herdr pane focus --direction DIR`. If there is no neighbor,
#        send the key back so the shell/app keeps its default binding.
#      - resize:   `herdr pane resize --direction DIR --amount RATIO --current`.
#        RATIO is derived from the focused pane geometry so one keypress ≈ one cell.
#
# Requires `jq` for Vim detection and pane geometry. Without it, Vim detection is
# skipped and resize falls back to a fixed 5% step.

set -euo pipefail

mode="navigate"
if [ "${1:-}" = "resize" ]; then
	mode="resize"
	dir="${2:?usage: herdr-navigate.sh resize <left|down|up|right>}"
else
	dir="${1:?usage: herdr-navigate.sh <left|down|up|right>}"
fi

herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}"

case "$dir" in
	left)  base="h" ;;
	down)  base="j" ;;
	up)    base="k" ;;
	right) base="l" ;;
	*)
		echo "herdr-navigate.sh: unknown direction: $dir" >&2
		exit 2
		;;
esac

if [ "$mode" = "resize" ]; then
	key="ctrl+alt+$base"
else
	key="ctrl+$base"
fi

# Foreground process names that mean "Vim is in control of this pane".
# Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff, ...
vim_re='^g?(view|l?n?vim?x?)(diff)?$'

# Opt-in passthrough for other TUIs that own the chord themselves,
# e.g. SMART_SPLITS_HERDR_PASSTHROUGH_RE='^(lazygit|k9s|vi-sql)$'
passthrough_re="${SMART_SPLITS_HERDR_PASSTHROUGH_RE:-}"

has_jq=0
command -v jq >/dev/null 2>&1 && has_jq=1

forward=0
if [ -n "$pane" ] && [ "$has_jq" -eq 1 ]; then
	if "$herdr" pane process-info --current 2>/dev/null \
		| jq -e --arg vim "$vim_re" --arg pass "$passthrough_re" \
			'.result.process_info.foreground_processes[]?.name
			 | ascii_downcase
			 | select(test($vim) or ($pass != "" and (try test($pass) catch false)))' >/dev/null 2>&1; then
		forward=1
	fi
fi

if [ "$forward" -eq 1 ]; then
	exec "$herdr" pane send-keys "$pane" "$key"
fi

if [ "$mode" = "resize" ]; then
	# One keypress should move the split by roughly one cell. The pane's own
	# width/height in cells is the same reference smart-splits' herdr backend uses.
	ratio="0.05"
	if [ "$has_jq" -eq 1 ]; then
		case "$dir" in
			left | right) field="width" ;;
			*) field="height" ;;
		esac
		extent="$("$herdr" pane layout --current 2>/dev/null \
			| jq -r --arg p "$pane" --arg f "$field" \
				'.result.layout.panes[] | select(.pane_id==$p) | .rect[$f] // empty' 2>/dev/null || true)"
		case "$extent" in
			'' | *[!0-9]*) : ;;
			*)
				if [ "$extent" -gt 0 ]; then
					ratio="$(awk -v e="$extent" 'BEGIN { r = 1 / e; if (r > 0.5) r = 0.5; printf "%.4f", r }')"
				fi
				;;
		esac
	fi
	"$herdr" pane resize --direction "$dir" --amount "$ratio" --current >/dev/null 2>&1 || true
	exit 0
fi

# Non-Vim pane: move focus if there is a neighbor in that direction,
# otherwise let the key fall through to the app.
focus_output="$("$herdr" pane focus --direction "$dir" --current 2>/dev/null)" && exit_code=0 || exit_code=$?
if [ "$exit_code" -eq 0 ] && [ -n "$focus_output" ] && [ "$has_jq" -eq 1 ]; then
	reason="$(printf '%s' "$focus_output" | jq -r '.result.focus.reason // empty' 2>/dev/null)"
	changed="$(printf '%s' "$focus_output" | jq -r '.result.focus.changed // false' 2>/dev/null)"
	if [ "$changed" = "true" ]; then
		exit 0
	fi
	if [ "$reason" = "no_neighbor" ]; then
		exec "$herdr" pane send-keys "$pane" "$key"
	fi
fi
# Fallback: if we couldn't determine state, let the key through rather than eating it.
exec "$herdr" pane send-keys "$pane" "$key"
