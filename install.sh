#!/usr/bin/env bash
set -euo pipefail

# claude-voice-notify installer (macOS).
# Copies scripts, installs the /voice command + a `voice` PATH command,
# and merges the notification hooks into ~/.claude/settings.json (backup first).

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude/voice-notify"
COMMANDS_DIR="$HOME/.claude/commands"
SETTINGS="$HOME/.claude/settings.json"
NOTIFY="$INSTALL_DIR/notify.sh"

say() { printf '%s\n' "$*"; }

# 1. Platform / dependencies
[ "$(uname)" = "Darwin" ] || { say "This tool currently supports macOS only (it uses afplay/osascript)."; exit 1; }
command -v jq >/dev/null 2>&1 || { say "Missing dependency: jq   (install with: brew install jq)"; exit 1; }
command -v node >/dev/null 2>&1 || say "Note: 'node' not found — only needed for generating voice packs (generate-sounds.mjs)."

# 2. Copy files
mkdir -p "$INSTALL_DIR" "$COMMANDS_DIR"
cp "$REPO_DIR/hooks/notify.sh" "$REPO_DIR/hooks/set-voice.sh" "$INSTALL_DIR/"
cp "$REPO_DIR/generate-sounds.mjs" "$REPO_DIR/voices.example.json" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/notify.sh" "$INSTALL_DIR/set-voice.sh"
cp "$REPO_DIR/commands/voice.md" "$COMMANDS_DIR/voice.md"
[ -f "$INSTALL_DIR/current-voice" ] || printf 'system\n' > "$INSTALL_DIR/current-voice"

# 3. `voice` command on PATH (first writable dir already on PATH)
link_dir=""
for d in "$HOME/bin" "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
  case ":$PATH:" in *":$d:"*) : ;; *) continue ;; esac
  if [ -d "$d" ] && [ -w "$d" ]; then link_dir="$d"; break; fi
done
if [ -z "$link_dir" ]; then
  link_dir="$HOME/.local/bin"; mkdir -p "$link_dir"
  say "Note: $link_dir is not on your PATH yet. Add it:  export PATH=\"$link_dir:\$PATH\""
fi
ln -sf "$INSTALL_DIR/set-voice.sh" "$link_dir/voice"

# 4. Merge hooks into settings.json (backup, idempotent, preserves other hooks)
[ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
tmp="$(mktemp)"
jq --arg n "$NOTIFY" '
  def ensure($event; $arg):
    .hooks[$event] = (
      ((((.hooks // {})[$event]) // [])
        | map(select(
            ([ (.hooks // [])[]?.command // empty ] | map(contains("voice-notify/notify.sh")) | any) | not
          )))
      + [ { "hooks": [ { "type": "command", "command": ($n + " " + $arg), "timeout": 15 } ] } ]
    );
  .hooks = (.hooks // {})
  | ensure("SessionStart"; "session")
  | ensure("Notification"; "question")
  | ensure("Stop"; "auto")
  | ensure("StopFailure"; "error")
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

say ""
say "claude-voice-notify installed."
say "  scripts        : $INSTALL_DIR"
say "  slash command  : $COMMANDS_DIR/voice.md   (/voice)"
say "  switch command : $link_dir/voice           (voice <id>  /  !voice <id> in Claude Code)"
say ""
say "Out of the box it plays macOS system sounds. List / switch voices:  voice"
say "Open /hooks once in Claude Code (or restart) so the new hooks load."
say ""
say "Optional — add a spoken voice pack:"
say "  1. cp $INSTALL_DIR/voices.example.json $INSTALL_DIR/voices.json   then edit it"
say "  2. export FISH_AUDIO_API_KEY=...    (from https://fish.audio)"
say "  3. node $INSTALL_DIR/generate-sounds.mjs    then:  voice <id>"
