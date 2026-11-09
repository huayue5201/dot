#!/bin/sh
# ask-agent-state.sh -- publish "Claude Code is busy" for the ask-agent.nvim picker.
#
# Claude Code calls this from its hooks; the hook payload arrives on stdin as JSON.
# Usage (in settings.json hooks):  ask-agent-state.sh busy | idle
#
# Writes $XDG_CACHE_HOME/ask-agent/claude/<slug(cwd)>.json = {"busy":true|false},
# which ask_agent.backends.generic.state_file() reads. keyed by cwd, matching
# generic.slug() in Lua: anything outside [A-Za-z0-9._-] becomes "_".

state=${1:-idle}
dir="${XDG_CACHE_HOME:-$HOME/.cache}/ask-agent/claude"
payload=$(cat)

key=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("cwd", ""))
except Exception:
    pass
')

# No cwd in the payload (unexpected version): do nothing rather than write a bad key.
[ -n "$key" ] || exit 0

name=$(printf '%s' "$key" | tr -c '[:alnum:]._-' '_')
mkdir -p "$dir" || exit 0

if [ "$state" = "busy" ]; then
	printf '{"busy":true,"detail":"turn running"}\n' >"$dir/$name.json"
else
	printf '{"busy":false}\n' >"$dir/$name.json"
fi
