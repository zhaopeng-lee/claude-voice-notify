#!/usr/bin/env bash
set -euo pipefail

# claude-voice-notify uninstaller. Reverses install.sh.
# By default it KEEPS your generated voice packs and voices.json.
# Pass --purge to delete everything, including ~/.claude/voice-notify.

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

INSTALL_DIR="$HOME/.claude/voice-notify"
COMMANDS_DIR="$HOME/.claude/commands"
SETTINGS="$HOME/.claude/settings.json"

say() { printf '%s\n' "$*"; }

# 1. Strip our hooks from settings.json (backup first)
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  tmp="$(mktemp)"
  jq '
    def clean($event):
      (((.hooks // {})[$event])) as $arr
      | if $arr == null then .
        else
          ($arr | map(select(
            ([ (.hooks // [])[]?.command // empty ]
              | map(contains("voice-notify/notify.sh") or contains("voice-notify/remind.sh"))
              | any) | not
          ))) as $kept
          | if ($kept | length) == 0 then del(.hooks[$event]) else .hooks[$event] = $kept end
        end;
    if (.hooks == null) then .
    else
      clean("SessionStart") | clean("Notification") | clean("Stop")
      | clean("StopFailure") | clean("UserPromptSubmit")
      | if ((.hooks // {}) | length) == 0 then del(.hooks) else . end
    end
  ' "$SETTINGS" > "$tmp"
  mv "$tmp" "$SETTINGS"
  say "Removed hooks from $SETTINGS"
fi

# 2. Slash command
rm -f "$COMMANDS_DIR/voice.md" && say "Removed $COMMANDS_DIR/voice.md"

# 3. `voice` symlinks pointing at our script
for d in "$HOME/bin" "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
  l="$d/voice"
  if [ -L "$l" ] && [ "$(readlink "$l")" = "$INSTALL_DIR/set-voice.sh" ]; then
    rm -f "$l" && say "Removed symlink $l"
  fi
done

# 4. Stop any running reminder
[ -x "$INSTALL_DIR/remind.sh" ] && bash "$INSTALL_DIR/remind.sh" stop 2>/dev/null || true

# 5. Program files (keep user data unless --purge)
if [ -d "$INSTALL_DIR" ]; then
  if [ "$PURGE" = 1 ]; then
    rm -rf "$INSTALL_DIR"
    say "Removed $INSTALL_DIR (including voices.json and generated voice packs)"
  else
    rm -f "$INSTALL_DIR/notify.sh" "$INSTALL_DIR/set-voice.sh" "$INSTALL_DIR/remind.sh" \
          "$INSTALL_DIR/generate-sounds.mjs" "$INSTALL_DIR/voices.example.json" \
          "$INSTALL_DIR/current-voice" "$INSTALL_DIR/remind-enabled" "$INSTALL_DIR/.remind.pid"
    if rmdir "$INSTALL_DIR" 2>/dev/null; then
      say "Removed $INSTALL_DIR"
    else
      say "Kept your data in $INSTALL_DIR (voices.json / sounds/). Run ./uninstall.sh --purge to delete it too."
    fi
  fi
fi

say "Done. Open /hooks in Claude Code (or restart) to unload the hooks."
