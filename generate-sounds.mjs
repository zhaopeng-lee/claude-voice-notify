#!/usr/bin/env node
/**
 * claude-voice-notify — voice pack generator (Fish Audio TTS).
 *
 * Reads voice definitions from ./voices.json (next to this file) and pre-generates
 * mp3 clips into ./sounds/<voice>/<state>/<state>-<n>.mp3. The notify hook then plays
 * a random clip per event locally — no API calls at runtime.
 *
 * Requires Node.js >= 18 (global fetch).
 *
 * Setup:
 *   1. Copy voices.example.json -> voices.json and edit it (your Fish Audio model ids + texts).
 *   2. Provide your key: export FISH_AUDIO_API_KEY=...   (or put it in a .env file here)
 *   3. Run:  node generate-sounds.mjs           # fill in missing clips (skips existing)
 *            node generate-sounds.mjs <voice>   # only one voice
 *            node generate-sounds.mjs --force   # regenerate everything
 *
 * IMPORTANT: Do not clone copyrighted, branded, or real people's voices. You are
 * responsible for the voice models and text you generate.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = dirname(fileURLToPath(import.meta.url));
const VOICES_PATH = join(DIR, "voices.json");
const OUT_ROOT = join(DIR, "sounds");

function getApiKey() {
  if (process.env.FISH_AUDIO_API_KEY) return process.env.FISH_AUDIO_API_KEY.trim();
  const envFile = join(DIR, ".env");
  if (existsSync(envFile)) {
    // tolerate an optional `export ` prefix and quotes
    const m = readFileSync(envFile, "utf8").match(/^\s*(?:export\s+)?FISH_AUDIO_API_KEY\s*=\s*(.*)$/m);
    if (m) return m[1].trim().replace(/^["']|["']$/g, "");
  }
  throw new Error("FISH_AUDIO_API_KEY not set (use an env var or a .env file next to this script).");
}

async function tts(text, referenceId, apiKey, { retries = 2, timeoutMs = 30000 } = {}) {
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetch("https://api.fish.audio/v1/tts", {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "s2-pro",
          text,
          reference_id: referenceId,
          format: "mp3",
          mp3_bitrate: 128,
          latency: "normal",
        }),
        signal: ctrl.signal,
      });
      if (!res.ok) {
        const body = await res.text().catch(() => "");
        throw new Error(`HTTP ${res.status}: ${body.slice(0, 200)}`);
      }
      return Buffer.from(await res.arrayBuffer());
    } catch (e) {
      lastErr = e && e.name === "AbortError" ? new Error(`timeout after ${timeoutMs}ms`) : e;
      if (attempt < retries) await new Promise((r) => setTimeout(r, (attempt + 1) * 1000));
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastErr;
}

if (!existsSync(VOICES_PATH)) {
  console.error(`No voices.json at ${VOICES_PATH}\nCopy voices.example.json -> voices.json and edit it first.`);
  process.exit(1);
}

const VOICES = JSON.parse(readFileSync(VOICES_PATH, "utf8"));
const argv = process.argv.slice(2);
const force = argv.includes("--force");
const only = argv.find((a) => !a.startsWith("--"));
const apiKey = getApiKey();
console.log(`[gen] key loaded${only ? `, only "${only}"` : ", all voices"}${force ? ", FORCE" : ", skip existing"}`);

let ok = 0, skip = 0, fail = 0, placeholders = 0;
for (const [voice, def] of Object.entries(VOICES)) {
  if (voice.startsWith("_")) continue;            // _help and other meta keys
  if (only && voice !== only) continue;
  if (!def || !def.reference_id || !def.clips) {
    console.error(`  ! "${voice}" missing reference_id/clips — skipped`);
    continue;
  }
  if (/REPLACE_WITH/.test(def.reference_id)) {
    console.error(`  ! "${voice}" still has a placeholder reference_id — set a real Fish Audio model id in voices.json`);
    placeholders++;
    continue;
  }
  console.log(`\n[${voice}] ${def.name || voice} (${def.reference_id})`);
  for (const [state, texts] of Object.entries(def.clips)) {
    const dir = join(OUT_ROOT, voice, state);
    mkdirSync(dir, { recursive: true });
    for (let i = 0; i < texts.length; i++) {
      const file = join(dir, `${state}-${i + 1}.mp3`);
      if (!force && existsSync(file)) { skip++; continue; }
      try {
        const buf = await tts(texts[i], def.reference_id, apiKey);
        writeFileSync(file, buf);
        console.log(`  ok ${state}-${i + 1}  ${(buf.length / 1024).toFixed(1)}KB  "${texts[i]}"`);
        ok++;
      } catch (e) {
        console.error(`  XX ${state}-${i + 1}  "${texts[i]}"  ${e.message}`);
        fail++;
      }
    }
  }
}

const tail = placeholders ? `  (${placeholders} voice(s) still have a placeholder reference_id — edit voices.json)` : "";
console.log(`\n[gen] done. ${ok} ok, ${skip} skipped, ${fail} failed.${tail}  -> ${OUT_ROOT}`);
if (ok === 0 && skip === 0 && fail === 0) {
  console.error(placeholders
    ? "Nothing generated — set real Fish Audio model ids in voices.json (https://fish.audio/m/<id>)."
    : "Nothing to do — voices.json has no usable voice definitions.");
  process.exit(1);
}
process.exit(fail > 0 ? 1 : 0);
