# claude-voice-notify

[English](README.md) · **中文** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Tiếng Việt](README.vi.md)

为 **macOS** 上的 [Claude Code](https://claude.com/claude-code) 提供语音／提示音通知。
当 Claude 需要你输入、答完一轮、出错、或开启会话时播放声音——开箱即用 macOS 自带系统音，
也可以用你自己 AI 生成的**声优包**（可配多个，一条命令切换）。

> 原理是把几个小 shell 脚本接进 Claude Code 的 hook 系统。不捆绑任何音频、无遥测、运行时不联网。

---

## 一键安装（粘贴进 Claude Code）

在你 Mac 上打开 Claude Code，粘贴这段提示——它会自动克隆、安装、激活：

```text
Install claude-voice-notify on my Mac. Steps:
1. git clone https://github.com/zhaopeng-lee/claude-voice-notify into a temp folder.
2. cd into it and run ./install.sh (if `jq` is missing, install it first with: brew install jq).
3. After it finishes, tell me to open /hooks once (or restart) to activate the hooks.
Then summarize in one or two lines how to switch voices with !voice <id> and how to add a Fish Audio voice pack.
```

想自己动手？见下方**手动安装**。

---

## 会响什么

| 事件 | Claude Code hook | 默认系统音 |
|------|------------------|-----------|
| 一轮结束——任务完成、或 Claude 在问你（智能判定） | `Stop` | Glass / Ping |
| 一轮以出错结束 | `StopFailure` | Basso |
| 会话开启（跳过自动压缩重启） | `SessionStart` | Hero |

装了声优包后，每个事件会随机播一条你所选声优的语音，替代系统音。

> **"完成 vs 提问"怎么判定：** `Stop` 时，派发器读 transcript 里最后一条 assistant 消息——
> 若以问号（`?` / `？`）结尾就播"在问你"，否则播"完成"。`Stop` 在**每轮结束**时触发一次
> （"当 Claude 答完时"），不是按"任务"——Claude Code 没有"任务完成"这个 hook。据官方文档，
> `Stop` **不会**在中断（ESC）、`/clear`（→ `SessionEnd`）、`/compact`（→ `PreCompact`/`PostCompact`）
> 时触发，所以那些情况是静默的。
>
> 我们**特意不挂** `Notification`：Claude Code 也会在约 60 秒空闲时发它，那样即使没东西要回也会催你。
> "Claude 在问你"已由上面的 `Stop` 覆盖（外加下面的递进催促）。

---

## 环境要求

- macOS（用到 `afplay` + `osascript`）
- [`jq`](https://jqlang.github.io/jq/) —— `brew install jq`
- Node.js **18+** —— **仅**在你想生成语音声优包时需要（用到全局 `fetch`）
- 一个 [Fish Audio](https://fish.audio) API key —— **仅**声优包需要

> 首次弹通知时，macOS 可能会请求允许你的终端 App（Terminal / iTerm / Ghostty / VS Code …）发通知。
> 允许它，否则你只会听到声音、没有横幅。声音本身不受影响。

## 手动安装

```bash
git clone https://github.com/zhaopeng-lee/claude-voice-notify.git
cd claude-voice-notify
./install.sh
```

然后在 Claude Code 里打开一次 `/hooks`（或重启），让新 hook 生效。

安装脚本会把脚本拷到 `~/.claude/voice-notify/`、安装一个 `/voice` slash 命令、在 `PATH` 上放一个
`voice` 命令，并把 4 个 hook 合并进 `~/.claude/settings.json`（合并前先备份，且仅在确有变更时备份，
并保留你已有的 hook）。

## 切换声优

```bash
voice            # 列出可用声优 + 当前选择
voice system     # 用 macOS 系统音（默认）
voice myvoice    # 用你生成的某个声优包
```

在 Claude Code 里加 `!` 前缀，可**不消耗模型轮次／token** 切换：

```
!voice myvoice
```

也有一个 `/voice` slash 命令，但它会按一轮正常对话执行（消耗 token）——快速切换请优先用 `!voice`。

## 递进催促（催到你回复为止）

**仅当 Claude 真的在等你时。** 若 Claude 的末句以问号（`?` / `？`）结尾，这一轮视为"等你回复"，
催促启动。若只是干完了某件事（无需回复），它响一声就安静——不纠缠。在等你期间，它按递进节奏
重复提醒——**60秒、3分钟、10分钟、30分钟**——之后放弃。每次播该声优 `remind` 里按序的一条
（1 → 2 → 3 → 4），所以语气逐步升级。

你一回复（`UserPromptSubmit` hook）或开启新会话，它立即停止。

**默认开启。** 随时切换（零 token）：

```bash
voice remind          # 查看状态
voice remind off      # 关闭（同时停掉正在跑的催促）
voice remind on       # 开启
```

用 `system` 声优（或没有 `remind` 片段的声优包）时，催促是一声普通系统音。
在 `voices.json` 里给声优加 `remind` 台词（见 `voices.example.json`）即可换成语音催促。
用 `REMIND_DELAYS` 调节节奏（如 `REMIND_DELAYS="30 60 300 900"`）。

## 主题化弹窗（文字 + 可选头像）

弹窗按声优做主题化：**副标题**显示 `voices.json` 里该声优的 `name`。想完全自定义每个声优的措辞，
编辑 `notify.sh` 里的 `case` 块。

要在横幅里显示**角色头像**：

1. `brew install terminal-notifier`
2. 把一张图片放到 `~/.claude/voice-notify/sounds/<voice>/icon.png`。

两者都具备时通知会自动用它（否则回退到普通系统弹窗）。注意：本项目不捆绑任何图片——自备、并注意版权。
在较新的 macOS 上，自定义图标可能只显示为横幅**右侧缩略图**（左侧主图标常被系统强制为发通知的 App），
且 `terminal-notifier` 首次需要通知权限。若加了图标后横幅不再出现，去"系统设置 → 通知"给它授权，
或删掉 `icon.png` 还原。

## 添加语音声优包（可选）

1. 从模板创建你的配置：
   ```bash
   cp ~/.claude/voice-notify/voices.example.json ~/.claude/voice-notify/voices.json
   ```
2. 编辑 `voices.json`：把每个声优的 `reference_id` 设为一个 Fish Audio 模型 id
   （`https://fish.audio/m/<id>` 末段那串），并自定义台词。
3. 生成并切换：
   ```bash
   export FISH_AUDIO_API_KEY=...           # 来自 https://fish.audio
   node ~/.claude/voice-notify/generate-sounds.mjs
   voice <你的声优-id>
   ```

`generate-sounds.mjs` 是幂等的——已存在的片段会跳过（网络请求带超时 + 重试）。用 `--force` 全量重生成，
或传一个声优 id 只处理那一个。

### ⚠️ 声音 / 版权责任

本项目**不附带任何音频**，与任何品牌、作品或角色均无关联。
**请勿克隆受版权保护的角色、品牌或真人声音。** 你自行对所选用的声音模型与文本负全部责任。

## 调校

所有行为都在 `~/.claude/voice-notify/notify.sh` 和 `~/.claude/settings.json` 的 hook 条目里——随意改：

- **太吵？** `voice off` 全部静音；或移除 `Stop` hook；或改 `notify.sh`，让纯对话（未用工具）不出声。
- **不想要会话开场音？** 移除 `SessionStart` hook。
- **催促太烦？** `voice remind off`，或用催促 hook 上的 `REMIND_DELAYS` 环境变量改节奏。
- **改默认系统音？** 编辑 `notify.sh` 里的 `sys_sound()` 映射（`/System/Library/Sounds/` 下任意文件）。

## 卸载

```bash
./uninstall.sh            # 移除 hook/命令/软链；保留你的 voices.json + 声优包
./uninstall.sh --purge    # 连 ~/.claude/voice-notify 一并删除（全部）
```

移除 hook 前会先写一份 settings.json 备份。

## 工作原理

- `notify.sh <state>` —— 由各 hook 调用；读 `current-voice`，随机播该状态的一条片段（或系统音），并弹 macOS 通知。
- `set-voice.sh`（即 `voice`）—— 写 `current-voice`、切换催促开关、播一条样例。
- `remind.sh` —— 递进"还在等你"催促循环（`Stop` 时启动，你一输入即取消）。
- `generate-sounds.mjs` —— 经 Fish Audio TTS 把 `voices.json` 变成 mp3 片段。

## 路线图

- Linux 支持（`paplay` / `notify-send`）

## 许可证

[MIT](./LICENSE)
