#!/bin/sh
# ask-agent-state.sh -- publish "Claude Code is busy" for the ask-agent.nvim picker.
#
# Claude Code calls this from its hooks; the hook payload arrives on stdin as JSON.
# Usage (in settings.json hooks):  ask-agent-state.sh busy | idle | done
#
# busy/idle: writes $XDG_CACHE_HOME/ask-agent/claude/<slug(cwd)>.json = {"busy":true|false},
# which ask_agent.backends.generic.state_file() reads. keyed by cwd, matching
# generic.slug() in Lua: anything outside [A-Za-z0-9._-] becomes "_".
#
# done (optional, Stop hook): also drops the last assistant message into
# $XDG_CACHE_HOME/ask-agent/results/<ts>-<pid>.json, the mailbox ask_agent.results
# imports, and still marks the agent idle. Only useful with
# `setup({ results = true })`; without it the file just sits there. Nothing is
# parsed out of the transcript on the nvim side — this script hands over the
# answer text it already has.

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

if [ "$state" = "done" ]; then
	# the payload was already read into $payload for the key above
	printf '%s' "$payload" | RESULTS_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ask-agent/results" python3 -c '
import json, os, sys, time

payload = json.load(sys.stdin)
cwd = payload.get("cwd") or ""

def last_assistant(path):
    text = ""
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except Exception:
                    continue
                if entry.get("type") != "assistant":
                    continue
                content = (entry.get("message") or {}).get("content")
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    part = "".join(
                        p.get("text", "") for p in content
                        if isinstance(p, dict) and p.get("type") == "text"
                    )
                    if part:
                        text = part
    except OSError:
        pass
    return text

text = payload.get("last_assistant_message")
if not isinstance(text, str) or text == "":
    path = payload.get("transcript_path")
    text = last_assistant(path) if isinstance(path, str) and path else ""
if text == "":
    sys.exit(0)

out = os.environ["RESULTS_DIR"]
os.makedirs(out, exist_ok=True)
name = "%d-%d.json" % (int(time.time() * 1000), os.getpid())
tmp = os.path.join(out, name + ".tmp")
with open(tmp, "w", encoding="utf-8") as f:
    json.dump({"cwd": cwd, "text": text, "ts": int(time.time() * 1000)}, f)
os.replace(tmp, os.path.join(out, name))
'
fi

if [ "$state" = "busy" ]; then
	printf '{"busy":true,"detail":"turn running"}\n' >"$dir/$name.json"
else
	printf '{"busy":false}\n' >"$dir/$name.json"
fi
