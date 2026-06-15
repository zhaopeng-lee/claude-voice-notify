#!/bin/bash
# claude-voice-notify — switch the active voice pack, or toggle the reminder.
# Usage:
#   voice [id]             switch voice; no/invalid arg -> list available voices
#   voice remind on|off    enable/disable the escalating "still waiting" reminder
#                          (voice remind -> show status)
# Available voices = "system" + each subdirectory under ./sounds/.  ("remind" is reserved.)
#
# Tip: inside Claude Code, prefix with ! to run locally with no model turn: !voice <id>

# Resolve real directory (follow symlinks — this script is symlinked to `voice` on PATH).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  TARGET="$(readlink "$SOURCE")"
  case "$TARGET" in /*) SOURCE="$TARGET" ;; *) SOURCE="$(dirname "$SOURCE")/$TARGET" ;; esac
done
DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

SOUNDS_ROOT="$DIR/sounds"
VOICE_FILE="$DIR/current-voice"
VOICES_JSON="$DIR/voices.json"
ENABLED_FILE="$DIR/remind-enabled"

friendly() {
  [ "$1" = "system" ] && { echo "macOS system sounds"; return; }
  if [ -f "$VOICES_JSON" ] && command -v jq >/dev/null 2>&1; then
    n=$(jq -r --arg k "$1" '.[$k].name // empty' "$VOICES_JSON" 2>/dev/null)
    [ -n "$n" ] && { echo "$n"; return; }
  fi
  echo "$1"
}

remind_state() {
  e="on"; [ -f "$ENABLED_FILE" ] && e=$(tr -d '[:space:]' < "$ENABLED_FILE")
  [ "$e" = "off" ] && echo "off" || echo "on"
}

# Sub-command: reminder toggle
if [ "${1:-}" = "remind" ]; then
  case "${2:-}" in
    on)  echo "on" > "$ENABLED_FILE"; echo "Reminders: ON  (replays at 60s / 3min / 10min / 30min until you respond; cancelled when you type)" ;;
    off) echo "off" > "$ENABLED_FILE"; bash "$DIR/remind.sh" stop 2>/dev/null; echo "Reminders: OFF" ;;
    ""|status) echo "Reminders: $(remind_state)"; echo "Toggle with: voice remind on | voice remind off" ;;
    *) echo "Usage: voice remind [on|off]" ;;
  esac
  exit 0
fi

current="system"
[ -f "$VOICE_FILE" ] && current=$(tr -d '[:space:]' < "$VOICE_FILE")
[ -z "$current" ] && current="system"

want=$(printf '%s' "${1:-}" | tr -d '[:space:]')

# Defensive id charset gate.
safe=1
case "$want" in ''|*[!A-Za-z0-9_-]*) safe=0 ;; esac

valid=0
if [ "$safe" = 1 ]; then
  [ "$want" = "system" ] && valid=1
  [ -d "$SOUNDS_ROOT/$want" ] && valid=1
fi

if [ "$valid" = 0 ]; then
  [ -n "$want" ] && echo "Unknown voice: ${want}"
  echo "Current: ${current} ($(friendly "$current"))"
  echo "Available:"
  echo "  - system ($(friendly system))$([ "$current" = system ] && echo '  <- current')"
  if [ -d "$SOUNDS_ROOT" ]; then
    for d in "$SOUNDS_ROOT"/*/; do
      [ -d "$d" ] || continue
      v=$(basename "$d")
      mark=""; [ "$v" = "$current" ] && mark="  <- current"
      echo "  - ${v} ($(friendly "$v"))${mark}"
    done
  fi
  echo
  echo "Reminders: $(remind_state)   (toggle: voice remind on|off)"
  echo "Usage: voice <id>    e.g.  voice system   (in Claude Code: !voice <id>)"
  exit 0
fi

echo "$want" > "$VOICE_FILE"
echo "Switched voice -> ${want} ($(friendly "$want"))"

# Play a sample (first available state for this voice).
if [ "$want" = "system" ]; then
  afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
else
  sample=""
  for st in done session question error remind subagent; do
    c=("$SOUNDS_ROOT/$want/$st"/*.mp3)
    if [ -e "${c[0]}" ]; then sample="${c[RANDOM % ${#c[@]}]}"; break; fi
  done
  [ -n "$sample" ] && afplay "$sample" >/dev/null 2>&1 &
fi
exit 0
