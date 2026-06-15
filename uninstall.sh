#!/usr/bin/env bash
set -euo pipefail

# claude-voice-notify uninstaller. Reverses install.sh.

INSTALL_DIR="$HOME/.claude/voice-notify"
COMMANDS_DIR="$HOME/.claude/commands"
SETTINGS="$HOME/.claude/settings.json"

say() { printf '%s\n' "$*"; }

# 1. Strip our hooks from settings.json
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  tmp="$(mktemp)"
  jq '
    def clean($event):
      (((.hooks // {})[$event])) as $arr
      | if $arr == null then .
        else
          ($arr | map(select(
            ([ (.hooks // [])[]?.command // empty ] | map(contains("voice-notify/notify.sh")) | any) | not
          ))) as $kept
          | if ($kept | length) == 0 then del(.hooks[$event]) else .hooks[$event] = $kept end
        end;
    if (.hooks == null) then .
    else
      clean("SessionStart") | clean("Notification") | clean("Stop") | clean("StopFailure")
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

# 4. Install dir (includes any generated voice packs)
if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  say "Removed $INSTALL_DIR (including generated voice packs)"
fi

say "Done. Open /hooks in Claude Code (or restart) to unload the hooks."
