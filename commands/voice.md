---
description: Switch the claude-voice-notify voice pack
argument-hint: "[voice id], leave empty to list"
allowed-tools: Bash(__SETVOICE__:*)
---
Output of the voice switcher (argument: `$ARGUMENTS`):

!`__SETVOICE__ $ARGUMENTS`

Based on the output above, reply briefly to the user:
- If it switched (output contains "Switched"): confirm the active voice in one short line. A sample already played.
- If it listed available voices (no or invalid argument): show the list and let the user choose, then run `__SETVOICE__ <id>` to switch.

Note: switching is just a local file change — for zero-token switching, the user can type `!voice <id>` directly instead of `/voice`.
