#!/bin/sh
# The team's Claude Code status line: folder, git branch, model, the bug-hunt bug this session holds, and
# the context window and 5-hour / 7-day limits as bars. Claude Code runs it with the session as JSON on
# stdin, so it works the same under zsh and bash; it needs only python3, which katalist needs too.
# katalist claude install sets it as statusLine when none is set.
input=$(cat)
here=$(cd "$(dirname "$0")" && pwd -P)
workspace=${KATALIST_HOME:-$(dirname "$(dirname "$here")")}

CYAN='\033[0;36m'
BOLD_BLUE='\033[1;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BOLD_GREEN='\033[1;32m'
GREEN='\033[0;32m'
MAGENTA='\033[1;35m'
DIM='\033[0;90m'
RESET='\033[0m'

# One line per field: cwd, ctx used %, 5h %, 5h left, 7d %, 7d left, model, bug-hunt bug.
fields=$(printf '%s' "$input" | REGISTRY="$workspace/bug-hunt/registry.json" python3 -c '
import json, os, sys, time
try:
    j = json.load(sys.stdin)
except Exception:
    j = {}
def g(*keys):
    o = j
    for k in keys:
        o = o.get(k) if isinstance(o, dict) else None
    return o
def left(epoch):
    try:
        diff = int(float(epoch)) - int(time.time())
    except (TypeError, ValueError):
        return ""
    if diff <= 0:
        return ""
    d, h, m = diff // 86400, diff % 86400 // 3600, diff % 3600 // 60
    return f"{d}d{h}h" if d else f"{h}h{m}m" if h else f"{m}m"
def pct(v):
    return "" if v is None else str(round(float(v)))
session = g("session_id") or g("session", "id") or ""
bug = ""
try:
    with open(os.environ["REGISTRY"]) as f:
        bug = next((k for k, e in json.load(f).items() if isinstance(e, dict) and e.get("session") == session), "")
except Exception:
    pass
print("\n".join([
    g("workspace", "current_dir") or g("cwd") or "",
    pct(g("context_window", "used_percentage")),
    pct(g("rate_limits", "five_hour", "used_percentage")),
    left(g("rate_limits", "five_hour", "resets_at")),
    pct(g("rate_limits", "seven_day", "used_percentage")),
    left(g("rate_limits", "seven_day", "resets_at")),
    g("model", "display_name") or g("model", "id") or "",
    bug,
]))
' 2>/dev/null)

field() { printf '%s\n' "$fields" | sed -n "${1}p"; }
cwd=$(field 1); used=$(field 2); five=$(field 3); five_left=$(field 4)
week=$(field 5); week_left=$(field 6); model=$(field 7); bug=$(field 8)

# A 10-cell bar: green under 70 %, yellow under 90 %, red above.
bar() {
  filled=$((($1 * 10 + 50) / 100)); [ "$filled" -gt 10 ] && filled=10
  if [ "$1" -lt 70 ]; then color=$GREEN; elif [ "$1" -lt 90 ]; then color=$YELLOW; else color=$RED; fi
  full=""; rest=""; i=0
  while [ "$i" -lt "$filled" ]; do full="${full}█"; i=$((i + 1)); done
  while [ "$i" -lt 10 ]; do rest="${rest}░"; i=$((i + 1)); done
  printf "${color}%s${DIM}%s${RESET}" "$full" "$rest"
}

line=$(printf "${BOLD_GREEN}➜${RESET}  ${CYAN}%s${RESET}" "$(basename "$cwd" 2>/dev/null)")
branch=$([ -n "$cwd" ] && git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    line="$line  $(printf "${BOLD_BLUE}git:(${RED}%s${BOLD_BLUE}) ${YELLOW}✗${RESET}" "$branch")"
  else
    line="$line  $(printf "${BOLD_BLUE}git:(${RED}%s${BOLD_BLUE})${RESET}" "$branch")"
  fi
fi
[ -n "$bug" ] && line="$(printf "${MAGENTA}🐛 bug/%s${RESET}" "$bug")  $line"
[ -n "$model" ] && line="$line  $(printf "${MAGENTA}⚡ %s${RESET}" "$model")"

limits=""
add() { # label, percent, time left
  [ -n "$2" ] || return 0
  [ -n "$limits" ] && limits="$limits  |  "
  limits="$limits$1 $(bar "$2") $2%"
  [ -n "$3" ] && limits="$limits$(printf " ${DIM}· %s left${RESET}" "$3")"
}
add ctx "$used" ""
add 5h "$five" "$five_left"
add 7d "$week" "$week_left"

if [ -n "$limits" ]; then printf "%s  |  %s\n" "$line" "$limits"; else printf "%s\n" "$line"; fi
