#!/bin/bash
# claude-voice-notify — escalating "still waiting on you" reminder.
# After Claude stops, if you don't respond it replays an escalating clip at
# 60s / 3min / 10min / 30min, then stops. Cancelled the moment you type
# (UserPromptSubmit hook). Toggle on/off with:  voice remind on|off
#
# Usage (called by hooks): remind.sh start | stop | __run
#   start  -> begin the schedule (kills any previous run; no-op if disabled)
#   stop   -> cancel a running schedule
#   __run  -> the detached loop body (do not call directly)
# Test with short delays:  REMIND_DELAYS="2 2 2 2" bash remind.sh start

# Resolve real directory (follow symlinks).
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  T="$(readlink "$SOURCE")"; case "$T" in /*) SOURCE="$T" ;; *) SOURCE="$(dirname "$SOURCE")/$T" ;; esac
done
DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

SOUNDS_ROOT="$DIR/sounds"
VOICE_FILE="$DIR/current-voice"
ENABLED_FILE="$DIR/remind-enabled"
PIDFILE="$DIR/.remind.pid"
FALLBACK="/System/Library/Sounds/Ping.aiff"

# Seconds to wait before each reminder (cumulative = 60s, 3min, 10min, 30min).
# Override for testing: REMIND_DELAYS="2 2 2 2"
read -ra DELAYS <<< "${REMIND_DELAYS:-60 120 420 1200}"
# Presence: if the keyboard/mouse was used within PRESENCE seconds, you're at the
# machine (you came back / glanced) -> stop nagging. Zero tokens. Tune with REMIND_PRESENCE_IDLE.
PRESENCE="${REMIND_PRESENCE_IDLE:-30}"

kill_existing() {
  [ -f "$PIDFILE" ] || return 0
  p=$(cat "$PIDFILE" 2>/dev/null)
  [ -n "$p" ] && kill "$p" 2>/dev/null
  rm -f "$PIDFILE"
}

case "${1:-}" in
  stop)
    kill_existing
    ;;
  start)
    enabled="on"; [ -f "$ENABLED_FILE" ] && enabled=$(tr -d '[:space:]' < "$ENABLED_FILE")
    [ "$enabled" = "off" ] && { kill_existing; exit 0; }   # disabled -> ensure stopped, don't start
    kill_existing
    nohup bash "$SOURCE" __run >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    ;;
  __run)
    n=0
    for d in "${DELAYS[@]}"; do
      sleep "$d" 2>/dev/null || { rm -f "$PIDFILE"; exit 0; }
      n=$((n + 1))
      # You're here -> don't nag: keyboard/mouse used within PRESENCE secs => acknowledged.
      idle=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/{print int($NF/1000000000); exit}')
      if [ -n "$idle" ] && [ "$idle" -lt "$PRESENCE" ]; then rm -f "$PIDFILE"; exit 0; fi
      voice="system"
      [ -f "$VOICE_FILE" ] && voice=$(tr -d '[:space:]' < "$VOICE_FILE")
      [ -z "$voice" ] && voice="system"
      clip="$SOUNDS_ROOT/$voice/remind/remind-$n.mp3"
      if [ -f "$clip" ]; then
        afplay "$clip" >/dev/null 2>&1
      else
        afplay "$FALLBACK" >/dev/null 2>&1
      fi
    done
    rm -f "$PIDFILE"
    ;;
esac
exit 0
