# claude-voice-notify

[English](README.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · **한국어** · [Tiếng Việt](README.vi.md)

**macOS**의 [Claude Code](https://claude.com/claude-code)에 음성/알림음 알림을 추가합니다.
Claude가 입력을 요청할 때, 한 턴을 마쳤을 때, 오류가 났을 때, 세션이 시작될 때 소리를 재생합니다.
기본적으로 macOS 내장 시스템 사운드를 쓰고, AI로 생성한 **보이스 팩**(여러 개 등록·명령 한 번으로 전환)도 사용할 수 있습니다.

> 작은 셸 스크립트를 Claude Code의 hook 시스템에 연결하는 방식입니다. 번들 오디오 없음, 텔레메트리 없음, 런타임 네트워크 없음.

---

## 빠른 설치 (Claude Code에 붙여넣기)

Mac에서 Claude Code를 열고 이 프롬프트를 붙여넣으세요 — 클론·설치·활성화까지 자동으로 진행됩니다:

```text
Install claude-voice-notify on my Mac. Steps:
1. git clone https://github.com/zhaopeng-lee/claude-voice-notify into a temp folder.
2. cd into it and run ./install.sh (if `jq` is missing, install it first with: brew install jq).
3. After it finishes, tell me to open /hooks once (or restart) to activate the hooks.
Then summarize in one or two lines how to switch voices with !voice <id> and how to add a Fish Audio voice pack.
```

직접 하고 싶다면 아래의 **수동 설치**를 참고하세요.

---

## 어떤 소리가 나나요

| 이벤트 | Claude Code hook | 기본 시스템 사운드 |
|--------|------------------|-------------------|
| 턴 종료 — 작업 완료, 또는 Claude가 질문 중 (스마트 판정) | `Stop` | Glass / Ping |
| 턴이 오류로 종료 | `StopFailure` | Basso |
| 세션 시작 (자동 압축 재시작은 건너뜀) | `SessionStart` | Hero |

보이스 팩을 설치하면 각 이벤트마다 선택한 목소리의 음성 한 줄이 무작위로 재생됩니다(시스템 사운드 대신).

> **"완료 vs 질문" 판정 방식:** `Stop` 시 디스패처가 트랜스크립트의 마지막 assistant 메시지를 읽어,
> 물음표(`?` / `？`)로 끝나면 "질문 중", 아니면 "완료"를 재생합니다. `Stop`은 **매 턴 종료 시** 한 번
> 발생하며("Claude가 응답을 마쳤을 때"), "작업" 단위가 아닙니다 — Claude Code에는 작업 완료 hook이 없습니다.
> 공식 문서에 따르면 `Stop`은 중단(ESC), `/clear`(→ `SessionEnd`), `/compact`(→ `PreCompact`/`PostCompact`)
> 에서는 **발생하지 않으므로** 그 경우엔 무음입니다.
>
> `Notification`은 **의도적으로 연결하지 않습니다**: Claude Code는 약 60초 유휴 시에도 이를 발생시켜
> 답할 게 없어도 재촉하기 때문입니다. "Claude가 질문 중"은 위의 `Stop`(및 아래 리마인더)이 처리합니다.

---

## 요구 사항

- macOS (`afplay` + `osascript` 사용)
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq`
- Node.js **18+** — 음성 보이스 팩을 생성할 때**만** 필요 (전역 `fetch` 사용)
- [Fish Audio](https://fish.audio) API 키 — 보이스 팩**에만** 필요

> 처음 알림이 뜰 때 macOS가 터미널 앱(Terminal / iTerm / Ghostty / VS Code …)의 알림 허용을 물을 수 있습니다.
> 허용하지 않으면 소리만 나고 배너는 안 나옵니다. 소리는 허용 여부와 무관하게 납니다.

## 수동 설치

```bash
git clone https://github.com/zhaopeng-lee/claude-voice-notify.git
cd claude-voice-notify
./install.sh
```

그다음 Claude Code에서 `/hooks`를 한 번 열면(또는 재시작) 새 hook이 로드됩니다.

설치 스크립트는 스크립트를 `~/.claude/voice-notify/`에 복사하고, `/voice` 슬래시 명령을 설치하며,
`PATH`에 `voice` 명령을 두고, 4개의 hook을 `~/.claude/settings.json`에 병합합니다
(병합 전 백업하고, 실제 변경이 있을 때만 백업하며, 기존 hook은 보존합니다).

## 목소리 전환

```bash
voice            # 사용 가능한 목소리 + 현재 선택 목록
voice system     # macOS 시스템 사운드 사용 (기본값)
voice myvoice    # 생성한 보이스 팩 사용
```

Claude Code 안에서는 앞에 `!`를 붙이면 **모델 턴/토큰을 소비하지 않고** 전환됩니다:

```
!voice myvoice
```

`/voice` 슬래시 명령도 있지만 일반 턴으로 실행됩니다(토큰 소비) — 빠른 전환에는 `!voice`를 권장합니다.

## 리마인더 (답할 때까지 재촉)

**Claude가 실제로 당신을 기다릴 때만.** Claude의 마지막 문장이 물음표(`?` / `？`)로 끝나면 그 턴은
"답변 대기"로 간주되어 리마인더가 작동합니다. 단지 작업을 끝낸 것뿐(답변 불필요)이라면 한 번 울리고
조용해집니다 — 졸라대지 않습니다. 기다리는 동안 점증 스케줄 — **60초, 3분, 10분, 30분** — 으로
다시 알리고 그 후 포기합니다. 매번 해당 목소리의 `remind` 클립을 순서대로(1 → 2 → 3 → 4) 재생하므로
표현이 점점 강해집니다.

당신이 답하는 순간(`UserPromptSubmit` hook) 또는 새 세션이 시작되면 멈춥니다.

**기본 ON.** 언제든 전환(토큰 0):

```bash
voice remind          # 상태 표시
voice remind off      # 비활성화 (실행 중인 리마인더도 중지)
voice remind on       # 활성화
```

`system` 목소리(또는 `remind` 클립이 없는 보이스 팩)일 때 재촉은 단순 시스템 핑입니다.
`voices.json`에서 목소리에 `remind` 대사를 추가하면(`voices.example.json` 참고) 음성 재촉이 됩니다.
스케줄은 `REMIND_DELAYS`로 조정합니다(예: `REMIND_DELAYS="30 60 300 900"`).

## 테마형 팝업 (텍스트 + 선택적 아바타)

팝업은 목소리별로 테마가 적용됩니다: **부제목**에 `voices.json`의 목소리 표시 이름 `name`이 나옵니다.
목소리별 문구를 완전히 커스터마이즈하려면 `notify.sh`의 `case` 블록을 편집하세요.

배너에 **캐릭터 아바타**를 표시하려면:

1. `brew install terminal-notifier`
2. `~/.claude/voice-notify/sounds/<voice>/icon.png`에 이미지를 둡니다.

둘 다 있으면 알림이 자동으로 이를 사용합니다(없으면 일반 시스템 팝업으로 폴백). 참고: 이미지는 번들되지
않습니다 — 직접 준비하고 저작권에 유의하세요. 최신 macOS에서는 커스텀 아이콘이 배너 **오른쪽 썸네일**에만
표시될 수 있고(왼쪽 주 아이콘은 발신 앱으로 강제되는 경우가 많음), `terminal-notifier`는 처음에 알림 권한이
필요합니다. 아이콘 추가 후 배너가 안 나오면 "시스템 설정 → 알림"에서 권한을 부여하거나 `icon.png`를 삭제해
되돌리세요.

## 음성 보이스 팩 추가 (선택)

1. 템플릿에서 설정 생성:
   ```bash
   cp ~/.claude/voice-notify/voices.example.json ~/.claude/voice-notify/voices.json
   ```
2. `voices.json` 편집: 각 목소리의 `reference_id`를 Fish Audio 모델 id
   (`https://fish.audio/m/<id>`의 마지막 부분)로 설정하고 대사를 커스터마이즈.
3. 생성 후 전환:
   ```bash
   export FISH_AUDIO_API_KEY=...           # https://fish.audio 에서
   node ~/.claude/voice-notify/generate-sounds.mjs
   voice <당신의-목소리-id>
   ```

`generate-sounds.mjs`는 멱등적입니다 — 이미 있는 클립은 건너뜁니다(네트워크 호출에 타임아웃 + 재시도 포함).
전부 다시 생성하려면 `--force`, 특정 목소리만 처리하려면 목소리 id를 전달하세요.

### ⚠️ 음성 / 저작권 책임

이 프로젝트는 **오디오를 일절 포함하지 않으며**, 어떤 브랜드·작품·캐릭터와도 무관합니다.
**저작권이 있는 캐릭터·브랜드·실존 인물의 목소리를 복제하지 마세요.**
생성·사용하는 음성 모델과 텍스트에 대한 책임은 전적으로 사용자에게 있습니다.

## 튜닝

모든 동작은 `~/.claude/voice-notify/notify.sh`와 `~/.claude/settings.json`의 hook 항목에 있습니다 — 자유롭게 편집:

- **너무 시끄러워요?** `voice off`로 전체 음소거; 또는 `Stop` hook 제거; 또는 `notify.sh`를 편집해 도구를 안 쓴 순수 대화에서는 무음으로.
- **세션 시작음이 싫어요?** `SessionStart` hook 제거.
- **리마인더가 성가셔요?** `voice remind off`, 또는 리마인더 hook의 `REMIND_DELAYS` 환경 변수로 스케줄 변경.
- **기본 시스템 사운드 변경?** `notify.sh`의 `sys_sound()` 매핑 편집(`/System/Library/Sounds/` 내 임의 파일).

## 제거

```bash
./uninstall.sh            # hook/명령/심볼릭 링크 제거; voices.json + 보이스 팩은 유지
./uninstall.sh --purge    # ~/.claude/voice-notify까지 삭제 (전부)
```

hook 제거 전에 settings.json 백업이 기록됩니다.

## 동작 방식

- `notify.sh <state>` — 각 hook이 호출; `current-voice`를 읽고 해당 상태의 클립(또는 시스템 사운드)을 무작위 재생하며 macOS 알림 표시.
- `set-voice.sh`(별칭 `voice`) — `current-voice` 기록, 리마인더 토글, 샘플 재생.
- `remind.sh` — 점증형 "아직 기다리는 중" 리마인더 루프(`Stop`에서 시작, 입력 시 취소).
- `generate-sounds.mjs` — Fish Audio TTS로 `voices.json`을 mp3 클립으로 변환.

## 로드맵

- Linux 지원 (`paplay` / `notify-send`)

## 라이선스

[MIT](./LICENSE)
