# claude-voice-notify

Spoken / sound notifications for [Claude Code](https://claude.com/claude-code) on **macOS**.
Plays a sound when Claude needs your input, finishes a turn, hits an error, or a session
starts — using built-in macOS system sounds out of the box, or your own AI-generated
**voice packs** (multiple, switchable with one command).

> Works by wiring small shell scripts into Claude Code's hook system. No bundled audio,
> no telemetry, no network at runtime.

---

## What it sounds like

| Event | Claude Code hook | Default sound |
|-------|------------------|---------------|
| Claude is waiting for your input / permission | `Notification` | Ping |
| A turn finished (smart: "done" vs "still asking you") | `Stop` | Glass / Ping |
| A turn ended in an error | `StopFailure` | Basso |
| A session started (skips auto-compaction restarts) | `SessionStart` | Hero |

With a voice pack installed, each event plays a random spoken line in your chosen voice instead.

> **Heads up on `Stop`:** Claude Code has no "task completed" event — `Stop` fires at the
> end of **every** assistant turn. So you'll hear the "done"/"waiting" sound on each reply,
> not only after big tasks. The dispatcher picks "waiting for you" when the last message ends
> in a question, otherwise "done". If that's too chatty, see *Tuning* below.

---

## Requirements

- macOS (uses `afplay` + `osascript`)
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq`
- Node.js — **only** if you want to generate spoken voice packs
- A [Fish Audio](https://fish.audio) API key — **only** for voice packs

## Install

```bash
git clone https://github.com/zhaopeng-lee/claude-voice-notify.git
cd claude-voice-notify
./install.sh
```

Then open `/hooks` once in Claude Code (or restart) so the new hooks load.

The installer copies scripts to `~/.claude/voice-notify/`, installs a `/voice` slash command,
puts a `voice` command on your `PATH`, and merges 4 hooks into `~/.claude/settings.json`
(it backs the file up first and preserves any hooks you already have).

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

`generate-sounds.mjs` is idempotent — it skips clips that already exist. Use `--force` to
regenerate everything, or pass a single voice id to do just one.

### ⚠️ Voice / copyright responsibility

This project ships **no audio** and is not affiliated with any brand, show, or character.
**Do not clone copyrighted characters, brands, or real people's voices.** You alone are
responsible for the voice models and text you choose to generate and use.

## Tuning

All behavior lives in `~/.claude/voice-notify/notify.sh` and the hook entries in
`~/.claude/settings.json` — edit freely:

- **Too chatty on every turn?** Remove the `Stop` hook (keep only `Notification` for
  "needs you"), or edit `notify.sh` to stay silent unless the turn used tools.
- **Don't want a session greeting?** Remove the `SessionStart` hook.
- **Change default system sounds:** edit the `sys_sound()` map in `notify.sh`
  (any file in `/System/Library/Sounds/`).

## Uninstall

```bash
./uninstall.sh
```

Removes the hooks (with a settings backup), the `/voice` command, the `voice` symlink, and
`~/.claude/voice-notify/`.

## How it works

- `notify.sh <state>` — invoked by each hook; reads `current-voice`, plays a random clip for
  that state (or a system sound), and shows a macOS notification.
- `set-voice.sh` (a.k.a. `voice`) — writes `current-voice` and plays a sample.
- `generate-sounds.mjs` — turns `voices.json` into mp3 clips via Fish Audio TTS.

## Roadmap

- Linux support (`paplay` / `notify-send`)

## License

[MIT](./LICENSE)
