# claude-voice-notify

Spoken / sound notifications for [Claude Code](https://claude.com/claude-code) on **macOS**.
Plays a sound when Claude needs your input, finishes a turn, hits an error, or a session
starts — using built-in macOS system sounds out of the box, or your own AI-generated
**voice packs** (multiple, switchable with one command).

> Works by wiring small shell scripts into Claude Code's hook system. No bundled audio,
> no telemetry, no network at runtime.

---

## Quick install (paste into Claude Code)

Open Claude Code on your Mac and paste this prompt — it will clone, install, and activate:

```text
Install claude-voice-notify on my Mac. Steps:
1. git clone https://github.com/zhaopeng-lee/claude-voice-notify into a temp folder.
2. cd into it and run ./install.sh (if `jq` is missing, install it first with: brew install jq).
3. After it finishes, tell me to open /hooks once (or restart) to activate the hooks.
Then summarize in one or two lines how to switch voices with !voice <id> and how to add a Fish Audio voice pack.
```

Prefer to do it yourself? See **Manual install** below.

---

## What it sounds like

| Event | Claude Code hook | Default sound |
|-------|------------------|---------------|
| A turn ended — task done, or Claude is asking you (smart) | `Stop` | Glass / Ping |
| A turn ended in an error | `StopFailure` | Basso |
| A session started (skips auto-compaction restarts) | `SessionStart` | Hero |

With a voice pack installed, each event plays a random spoken line in your chosen voice instead.

> **How "done vs asking" is decided:** on `Stop`, the dispatcher reads the transcript and only
> announces when the turn **genuinely ended** — the last assistant message's `stop_reason` must be
> `end_turn`. An interrupt (ESC), `/clear`, or `/compact` therefore stays **silent**. It plays the
> "asking you" sound when that final message ends with a question (`?` / `？`), otherwise "done".
> This still fires per turn-end, not per "task" — Claude Code has no task-completion hook.
>
> We deliberately **don't** hook `Notification`: Claude Code also fires it after ~60s idle, which
> would nag you even when nothing needs an answer. "Claude is asking you" is covered by `Stop`
> above (and the escalating reminder below).

---

## Requirements

- macOS (uses `afplay` + `osascript`)
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq`
- Node.js **18+** — **only** if you want to generate spoken voice packs (uses global `fetch`)
- A [Fish Audio](https://fish.audio) API key — **only** for voice packs

> First time a notification pops, macOS may ask to allow notifications for your terminal app
> (Terminal / iTerm / Ghostty / VS Code …). Allow it, or you'll only hear the sound with no
> banner. The sound works regardless.

## Manual install

```bash
git clone https://github.com/zhaopeng-lee/claude-voice-notify.git
cd claude-voice-notify
./install.sh
```

Then open `/hooks` once in Claude Code (or restart) so the new hooks load.

The installer copies scripts to `~/.claude/voice-notify/`, installs a `/voice` slash command,
puts a `voice` command on your `PATH`, and merges 4 hooks into `~/.claude/settings.json`
(it backs the file up first, only when something actually changes, and preserves any hooks
you already have).

## Switching voices

```bash
voice            # list available voices + current selection
voice system     # use macOS system sounds (default)
voice myvoice    # use a voice pack you generated
```

Inside Claude Code, prefix with `!` to switch **without spending a model turn / tokens**:

```
!voice myvoice
```

There's also a `/voice` slash command, but it runs as a normal turn (costs tokens) — prefer
`!voice` for quick switches.

## Reminders (nudge until you reply)

**Only when Claude is actually waiting on you.** If Claude's final message ends with a question
(`?` / `？`), the turn is treated as "awaiting your reply" and the reminder kicks in. If the turn
just finished a task (no reply needed), it chimes once and stays quiet — no nagging. While
awaiting you, it re-nudges on an escalating schedule — **60s, 3min, 10min, 30min** — then gives
up. Each nudge plays the voice's `remind` clips in order (1 → 2 → 3 → 4), so the wording escalates.

It stops the moment you reply (the `UserPromptSubmit` hook) or a new session starts.

It's **on by default**. Toggle anytime (zero tokens):

```bash
voice remind          # show status
voice remind off      # disable (also stops any running reminder)
voice remind on       # enable
```

With the `system` voice (or a pack without `remind` clips), the nudge is a plain system ping.
Add `remind` lines to a voice in `voices.json` (see `voices.example.json`) for spoken nudges.
Tune the schedule with `REMIND_DELAYS` (e.g. `REMIND_DELAYS="30 60 300 900"`).

## Themed popups (text + optional avatar)

The popup is themed per voice: its **subtitle** shows the voice's display `name` from
`voices.json`. For fully custom per-voice wording, edit the `case` block in `notify.sh`.

To show a **character avatar** in the banner:

1. `brew install terminal-notifier`
2. Drop an image at `~/.claude/voice-notify/sounds/<voice>/icon.png`.

When both are present, notifications use it automatically (else they fall back to the plain
system popup). Notes: no image is bundled — bring your own and mind copyright. On modern macOS
the custom icon may only show as the right-side thumbnail (the left app-icon is often forced to
the posting app), and `terminal-notifier` needs notification permission the first time. If
banners stop appearing after adding an icon, grant it permission in System Settings → Notifications,
or remove `icon.png` to revert.

## Add a spoken voice pack (optional)

1. Create your config from the template:
   ```bash
   cp ~/.claude/voice-notify/voices.example.json ~/.claude/voice-notify/voices.json
   ```
2. Edit `voices.json`: set each voice's `reference_id` to a Fish Audio model id
   (the last path segment of `https://fish.audio/m/<id>`) and customize the lines.
3. Generate and switch:
   ```bash
   export FISH_AUDIO_API_KEY=...           # from https://fish.audio
   node ~/.claude/voice-notify/generate-sounds.mjs
   voice <your-voice-id>
   ```

`generate-sounds.mjs` is idempotent — it skips clips that already exist (network calls have a
timeout + retry). Use `--force` to regenerate everything, or pass a single voice id to do one.

### ⚠️ Voice / copyright responsibility

This project ships **no audio** and is not affiliated with any brand, show, or character.
**Do not clone copyrighted characters, brands, or real people's voices.** You alone are
responsible for the voice models and text you choose to generate and use.

## Tuning

All behavior lives in `~/.claude/voice-notify/notify.sh` and the hook entries in
`~/.claude/settings.json` — edit freely:

- **Too chatty?** `voice off` mutes everything; or remove the `Stop` hook, or edit `notify.sh`
  to stay silent unless the turn used tools.
- **Don't want a session greeting?** Remove the `SessionStart` hook.
- **Reminders too naggy?** `voice remind off`, or change the schedule via the
  `REMIND_DELAYS` env var on the reminder hook.
- **Change default system sounds:** edit the `sys_sound()` map in `notify.sh`
  (any file in `/System/Library/Sounds/`).

## Uninstall

```bash
./uninstall.sh            # remove hooks/command/symlink; KEEP your voices.json + voice packs
./uninstall.sh --purge    # also delete ~/.claude/voice-notify (everything)
```

A settings.json backup is written before the hooks are removed.

## How it works

- `notify.sh <state>` — invoked by each hook; reads `current-voice`, plays a random clip for
  that state (or a system sound), and shows a macOS notification.
- `set-voice.sh` (a.k.a. `voice`) — writes `current-voice`, toggles reminders, plays a sample.
- `remind.sh` — the escalating "still waiting" reminder loop (started on `Stop`, cancelled on input).
- `generate-sounds.mjs` — turns `voices.json` into mp3 clips via Fish Audio TTS.

## Roadmap

- Linux support (`paplay` / `notify-send`)

## License

[MIT](./LICENSE)
