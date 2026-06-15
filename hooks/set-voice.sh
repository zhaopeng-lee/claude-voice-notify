#!/bin/bash
# claude-voice-notify — switch the active voice pack.
# Usage: voice [id]
#   valid id  -> write ./current-voice, play a sample
#   no/invalid -> list available voices + current selection
# Available voices = "system" + each subdirectory under ./sounds/.
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

friendly() {
  [ "$1" = "system" ] && { echo "macOS system sounds"; return; }
  if [ -f "$VOICES_JSON" ] && command -v jq >/dev/null 2>&1; then
    n=$(jq -r --arg k "$1" '.[$k].name // empty' "$VOICES_JSON" 2>/dev/null)
    [ -n "$n" ] && { echo "$n"; return; }
  fi
  echo "$1"
}

current="system"
[ -f "$VOICE_FILE" ] && current=$(tr -d '[:space:]' < "$VOICE_FILE")

want=$(printf '%s' "${1:-}" | tr -d '[:space:]')

valid=0
[ "$want" = "system" ] && valid=1
[ -n "$want" ] && [ -d "$SOUNDS_ROOT/$want" ] && valid=1

if [ -z "$want" ] || [ "$valid" = 0 ]; then
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
  echo "Usage: voice <id>    e.g.  voice system   (in Claude Code: !voice <id>)"
  exit 0
fi

echo "$want" > "$VOICE_FILE"
echo "Switched voice -> ${want} ($(friendly "$want"))"

# Play a sample.
if [ "$want" = "system" ]; then
  afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
else
  clips=("$SOUNDS_ROOT/$want/done"/*.mp3)
  [ -e "${clips[0]}" ] && afplay "${clips[RANDOM % ${#clips[@]}]}" >/dev/null 2>&1 &
fi
exit 0
