---
description: Switch the claude-voice-notify voice pack
argument-hint: "[voice id], leave empty to list"
allowed-tools: Bash(voice:*)
---
Output of the voice switcher (argument: `$ARGUMENTS`):

!`voice $ARGUMENTS`

Based on the output above, reply briefly to the user:
- If it switched (output contains "Switched"): confirm the active voice in one short line. A sample already played.
- If it listed available voices (no or invalid argument): show the list and let the user choose, then run `voice <id>` to switch.

Note: switching is a local file change — for zero-token switching, the user can type `!voice <id>` directly instead of `/voice`.
