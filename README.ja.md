# claude-voice-notify

[English](README.md) · [中文](README.zh-CN.md) · **日本語** · [한국어](README.ko.md) · [Tiếng Việt](README.vi.md)

**macOS** 上の [Claude Code](https://claude.com/claude-code) に音声／通知音を追加します。
Claude が入力を求めたとき・1ターンを終えたとき・エラーになったとき・セッション開始時に音を鳴らします。
標準では macOS 内蔵のシステム音を使い、AI 生成の**ボイスパック**（複数登録・コマンド一つで切替）も使えます。

> 仕組みは小さなシェルスクリプトを Claude Code の hook システムに繋ぐだけ。同梱音声なし・テレメトリなし・実行時の通信なし。

---

## かんたんインストール（Claude Code に貼り付け）

Mac で Claude Code を開き、このプロンプトを貼り付けてください。クローン・インストール・有効化まで自動で行います:

```text
Install claude-voice-notify on my Mac. Steps:
1. git clone https://github.com/zhaopeng-lee/claude-voice-notify into a temp folder.
2. cd into it and run ./install.sh (if `jq` is missing, install it first with: brew install jq).
3. After it finishes, tell me to open /hooks once (or restart) to activate the hooks.
Then summarize in one or two lines how to switch voices with !voice <id> and how to add a Fish Audio voice pack.
```

自分でやりたい場合は下の**手動インストール**へ。

---

## どんな音が鳴るか

| イベント | Claude Code hook | 既定のシステム音 |
|----------|------------------|-----------------|
| ターン終了 — タスク完了、または Claude が質問中（自動判定） | `Stop` | Glass / Ping |
| ターンがエラーで終了 | `StopFailure` | Basso |
| セッション開始（自動コンパクト再起動はスキップ） | `SessionStart` | Hero |

ボイスパックを入れると、各イベントで選んだ声の音声がランダムに 1 本再生されます（システム音の代わり）。

> **「完了 vs 質問」の判定方法:** `Stop` 時にディスパッチャがトランスクリプト末尾の assistant メッセージを読み、
> 疑問符（`?` / `？`）で終わっていれば「質問中」、そうでなければ「完了」を鳴らします。`Stop` は**毎ターン終了時**に
> 一度発火し（「Claude が応答を終えたとき」）、「タスク」単位ではありません — Claude Code にタスク完了の hook は
> ありません。公式ドキュメントによれば、`Stop` は中断（ESC）・`/clear`（→ `SessionEnd`）・`/compact`
> （→ `PreCompact`/`PostCompact`）では**発火しない**ので、それらは無音です。
>
> `Notification` は**あえて使いません**: Claude Code は約 60 秒のアイドルでもこれを発火させ、返事が不要でも
> 急かしてしまうためです。「Claude が質問中」は上記の `Stop`（と下記のリマインダー）でカバーします。

---

## 必要環境

- macOS（`afplay` + `osascript` を使用）
- [`jq`](https://jqlang.github.io/jq/) —— `brew install jq`
- Node.js **18+** —— 音声ボイスパックを生成する場合**のみ**（グローバル `fetch` を使用）
- [Fish Audio](https://fish.audio) の API キー —— ボイスパック**のみ**

> 初回の通知時、macOS がお使いのターミナルアプリ（Terminal / iTerm / Ghostty / VS Code …）の通知許可を
> 求めることがあります。許可しないと音だけ鳴ってバナーが出ません。音は許可に関係なく鳴ります。

## 手動インストール

```bash
git clone https://github.com/zhaopeng-lee/claude-voice-notify.git
cd claude-voice-notify
./install.sh
```

そのあと Claude Code で `/hooks` を一度開く（または再起動）と、新しい hook が読み込まれます。

インストーラはスクリプトを `~/.claude/voice-notify/` にコピーし、`/voice` スラッシュコマンドを追加し、
`PATH` 上に `voice` コマンドを置き、4 つの hook を `~/.claude/settings.json` にマージします
（マージ前にバックアップを取り、実際に変更がある時のみ作成、既存の hook は保持します）。

## 声の切り替え

```bash
voice            # 利用可能な声 + 現在の選択を一覧
voice system     # macOS システム音を使う（既定）
voice myvoice    # 生成したボイスパックを使う
```

Claude Code 内では `!` を先頭に付けると、**モデルのターン／トークンを消費せず**に切り替えられます:

```
!voice myvoice
```

`/voice` スラッシュコマンドもありますが、通常の 1 ターンとして実行されます（トークン消費）——
素早い切替には `!voice` を推奨します。

## リマインダー（返事するまで催促）

**Claude が本当にあなたを待っている時だけ。** Claude の最後の文が疑問符（`?` / `？`）で終わっていれば、
そのターンは「返事待ち」と判断されリマインダーが始動します。単にタスクを終えただけ（返事不要）なら
一度鳴って静かになります——しつこくしません。待っている間は段階的なスケジュール——**60秒・3分・10分・30分**——
で再通知し、その後あきらめます。各回はその声の `remind` クリップを順番に（1 → 2 → 3 → 4）再生するので、
言い回しが徐々に強まります。

あなたが返事した瞬間（`UserPromptSubmit` hook）、または新しいセッションが始まると停止します。

**既定で ON。** いつでも切替（トークン消費ゼロ）:

```bash
voice remind          # 状態を表示
voice remind off      # 無効化（実行中のリマインダーも停止）
voice remind on       # 有効化
```

`system` の声（または `remind` クリップのないボイスパック）の場合、催促はただのシステム音です。
`voices.json` で声に `remind` セリフを追加（`voices.example.json` 参照）すれば音声の催促になります。
スケジュールは `REMIND_DELAYS` で調整できます（例: `REMIND_DELAYS="30 60 300 900"`）。

## テーマ化された通知（テキスト + 任意でアバター）

通知は声ごとにテーマ化されます: **サブタイトル**に `voices.json` の声の表示名 `name` が出ます。
声ごとに文言を完全カスタムするには `notify.sh` の `case` ブロックを編集してください。

バナーに**キャラクターのアバター**を出すには:

1. `brew install terminal-notifier`
2. `~/.claude/voice-notify/sounds/<voice>/icon.png` に画像を置く。

両方そろっていれば通知が自動的にそれを使います（無ければ通常のシステム通知にフォールバック）。
注意: 画像は同梱していません——自分で用意し、著作権に留意してください。最近の macOS では
カスタムアイコンはバナー**右側のサムネイル**にのみ表示されることがあり（左の主アイコンは送信元アプリに
強制されがち）、`terminal-notifier` は初回に通知許可が必要です。アイコン追加後にバナーが出なくなったら、
「システム設定 → 通知」で許可するか、`icon.png` を削除して元に戻してください。

## 音声ボイスパックを追加（任意）

1. テンプレートから設定を作成:
   ```bash
   cp ~/.claude/voice-notify/voices.example.json ~/.claude/voice-notify/voices.json
   ```
2. `voices.json` を編集: 各声の `reference_id` を Fish Audio のモデル id
   （`https://fish.audio/m/<id>` の末尾部分）に設定し、セリフをカスタマイズ。
3. 生成して切替:
   ```bash
   export FISH_AUDIO_API_KEY=...           # https://fish.audio から
   node ~/.claude/voice-notify/generate-sounds.mjs
   voice <あなたの声-id>
   ```

`generate-sounds.mjs` は冪等です——既存のクリップはスキップします（ネットワーク呼び出しはタイムアウト + リトライ付き）。
全部作り直すには `--force`、特定の声だけなら声 id を渡してください。

### ⚠️ 音声 / 著作権の責任

本プロジェクトは**音声を一切同梱せず**、いかなるブランド・作品・キャラクターとも無関係です。
**著作権で保護されたキャラクター・ブランド・実在人物の声をクローンしないでください。**
生成・使用する声モデルとテキストの責任はすべて利用者にあります。

## 微調整

すべての挙動は `~/.claude/voice-notify/notify.sh` と `~/.claude/settings.json` の hook エントリにあります——自由に編集を:

- **うるさい？** `voice off` で全消音；または `Stop` hook を削除；または `notify.sh` を編集して、ツールを使わない純粋な会話では鳴らさないように。
- **セッション開始音が不要？** `SessionStart` hook を削除。
- **催促がしつこい？** `voice remind off`、またはリマインダー hook の `REMIND_DELAYS` 環境変数でスケジュール変更。
- **既定のシステム音を変える？** `notify.sh` の `sys_sound()` マップを編集（`/System/Library/Sounds/` 内の任意ファイル）。

## アンインストール

```bash
./uninstall.sh            # hook/コマンド/シンボリックリンクを削除；voices.json + ボイスパックは保持
./uninstall.sh --purge    # ~/.claude/voice-notify ごと削除（すべて）
```

hook 削除前に settings.json のバックアップが書き出されます。

## 仕組み

- `notify.sh <state>` —— 各 hook から呼ばれ、`current-voice` を読み、その状態のクリップ（またはシステム音）をランダム再生し、macOS 通知を表示。
- `set-voice.sh`（別名 `voice`）—— `current-voice` の書き込み、リマインダーの切替、サンプル再生。
- `remind.sh` —— 段階的な「まだ待っています」リマインダーのループ（`Stop` で開始、入力で取消）。
- `generate-sounds.mjs` —— Fish Audio TTS で `voices.json` を mp3 クリップに変換。

## ロードマップ

- Linux 対応（`paplay` / `notify-send`）

## ライセンス

[MIT](./LICENSE)
