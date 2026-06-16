# claude-voice-notify

[English](README.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Tiếng Việt**

Thông báo bằng giọng nói / âm thanh cho [Claude Code](https://claude.com/claude-code) trên **macOS**.
Phát âm thanh khi Claude cần bạn nhập, kết thúc một lượt, gặp lỗi, hoặc khi bắt đầu phiên — dùng âm thanh
hệ thống macOS có sẵn ngay từ đầu, hoặc các **gói giọng** do AI tạo của riêng bạn (đăng ký nhiều, đổi bằng một lệnh).

> Hoạt động bằng cách nối vài script shell nhỏ vào hệ thống hook của Claude Code. Không kèm âm thanh, không telemetry, không kết nối mạng lúc chạy.

---

## Cài đặt nhanh (dán vào Claude Code)

Mở Claude Code trên Mac và dán prompt này — nó sẽ tự clone, cài đặt và kích hoạt:

```text
Install claude-voice-notify on my Mac. Steps:
1. git clone https://github.com/zhaopeng-lee/claude-voice-notify into a temp folder.
2. cd into it and run ./install.sh (if `jq` is missing, install it first with: brew install jq).
3. After it finishes, tell me to open /hooks once (or restart) to activate the hooks.
Then summarize in one or two lines how to switch voices with !voice <id> and how to add a Fish Audio voice pack.
```

Muốn tự làm? Xem **Cài đặt thủ công** bên dưới.

---

## Nghe ra sao

| Sự kiện | Hook của Claude Code | Âm thanh hệ thống mặc định |
|---------|----------------------|----------------------------|
| Một lượt kết thúc — xong việc, hoặc Claude đang hỏi bạn (tự phán đoán) | `Stop` | Glass / Ping |
| Một lượt kết thúc do lỗi | `StopFailure` | Basso |
| Phiên bắt đầu (bỏ qua khởi động lại do nén tự động) | `SessionStart` | Hero |

Khi đã cài gói giọng, mỗi sự kiện sẽ phát ngẫu nhiên một câu thoại bằng giọng bạn chọn (thay cho âm hệ thống).

> **Cách phán đoán "xong vs đang hỏi":** khi `Stop`, bộ điều phối đọc tin nhắn assistant cuối trong transcript —
> nếu kết thúc bằng dấu hỏi (`?` / `？`) thì phát "đang hỏi bạn", ngược lại phát "xong". `Stop` kích hoạt một lần
> **mỗi khi kết thúc lượt** ("khi Claude trả lời xong"), không phải theo "tác vụ" — Claude Code không có hook
> hoàn thành tác vụ. Theo tài liệu chính thức, `Stop` **không** kích hoạt khi ngắt (ESC), `/clear`
> (→ `SessionEnd`), hay `/compact` (→ `PreCompact`/`PostCompact`), nên những trường hợp đó im lặng.
>
> Chúng tôi **cố ý không** dùng hook `Notification`: Claude Code cũng kích hoạt nó sau khoảng 60 giây nhàn rỗi,
> như vậy sẽ giục bạn ngay cả khi chẳng cần trả lời. "Claude đang hỏi bạn" đã được `Stop` ở trên (và bộ nhắc bên dưới) lo.

---

## Yêu cầu

- macOS (dùng `afplay` + `osascript`)
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq`
- Node.js **18+** — **chỉ** khi bạn muốn tạo gói giọng nói (dùng `fetch` toàn cục)
- Một API key của [Fish Audio](https://fish.audio) — **chỉ** cho gói giọng

> Lần đầu hiện thông báo, macOS có thể hỏi cấp quyền thông báo cho ứng dụng terminal của bạn
> (Terminal / iTerm / Ghostty / VS Code …). Hãy cho phép, nếu không bạn chỉ nghe âm thanh mà không thấy banner.
> Âm thanh vẫn kêu bất kể.

## Cài đặt thủ công

```bash
git clone https://github.com/zhaopeng-lee/claude-voice-notify.git
cd claude-voice-notify
./install.sh
```

Sau đó mở `/hooks` một lần trong Claude Code (hoặc khởi động lại) để nạp các hook mới.

Trình cài đặt sao chép script vào `~/.claude/voice-notify/`, cài lệnh slash `/voice`, đặt lệnh `voice`
vào `PATH`, và gộp 4 hook vào `~/.claude/settings.json` (sao lưu trước, chỉ khi thực sự có thay đổi,
và giữ nguyên các hook bạn đã có).

## Đổi giọng

```bash
voice            # liệt kê giọng khả dụng + lựa chọn hiện tại
voice system     # dùng âm thanh hệ thống macOS (mặc định)
voice myvoice    # dùng gói giọng bạn đã tạo
```

Trong Claude Code, thêm tiền tố `!` để đổi mà **không tốn lượt mô hình / token**:

```
!voice myvoice
```

Cũng có lệnh slash `/voice`, nhưng nó chạy như một lượt bình thường (tốn token) — đổi nhanh thì nên dùng `!voice`.

## Bộ nhắc (giục đến khi bạn trả lời)

**Chỉ khi Claude thực sự đang chờ bạn.** Nếu câu cuối của Claude kết thúc bằng dấu hỏi (`?` / `？`),
lượt đó được coi là "đang chờ bạn trả lời" và bộ nhắc khởi động. Nếu chỉ vừa xong một việc (không cần trả lời),
nó kêu một tiếng rồi im — không lải nhải. Trong lúc chờ, nó nhắc lại theo lịch tăng dần — **60 giây, 3 phút,
10 phút, 30 phút** — rồi thôi. Mỗi lần phát các clip `remind` của giọng theo thứ tự (1 → 2 → 3 → 4), nên lời lẽ
mạnh dần.

Nó dừng ngay khi bạn trả lời (hook `UserPromptSubmit`) hoặc khi một phiên mới bắt đầu.

**Bật mặc định.** Bật/tắt bất cứ lúc nào (không tốn token):

```bash
voice remind          # xem trạng thái
voice remind off      # tắt (cũng dừng bộ nhắc đang chạy)
voice remind on       # bật
```

Với giọng `system` (hoặc gói giọng không có clip `remind`), tiếng giục là một ping hệ thống đơn giản.
Thêm câu `remind` cho giọng trong `voices.json` (xem `voices.example.json`) để có tiếng giục bằng giọng nói.
Điều chỉnh lịch bằng `REMIND_DELAYS` (ví dụ `REMIND_DELAYS="30 60 300 900"`).

## Popup theo chủ đề (chữ + ảnh đại diện tùy chọn)

Popup được tạo chủ đề theo từng giọng: **phụ đề** hiển thị tên `name` của giọng trong `voices.json`.
Để tùy biến hoàn toàn câu chữ cho từng giọng, sửa khối `case` trong `notify.sh`.

Để hiện **ảnh đại diện nhân vật** trong banner:

1. `brew install terminal-notifier`
2. Đặt một ảnh tại `~/.claude/voice-notify/sounds/<voice>/icon.png`.

Khi có cả hai, thông báo sẽ tự dùng nó (nếu không thì quay về popup hệ thống thường). Lưu ý: không kèm sẵn ảnh —
hãy tự chuẩn bị và lưu ý bản quyền. Trên macOS mới, biểu tượng tùy chỉnh có thể chỉ hiện ở **ảnh thu nhỏ bên phải**
banner (biểu tượng chính bên trái thường bị ép thành của app gửi), và `terminal-notifier` cần quyền thông báo lần đầu.
Nếu sau khi thêm icon mà banner không hiện nữa, cấp quyền trong Cài đặt hệ thống → Thông báo, hoặc xóa `icon.png` để trở lại.

## Thêm gói giọng nói (tùy chọn)

1. Tạo cấu hình từ mẫu:
   ```bash
   cp ~/.claude/voice-notify/voices.example.json ~/.claude/voice-notify/voices.json
   ```
2. Sửa `voices.json`: đặt `reference_id` của mỗi giọng thành một model id của Fish Audio
   (phần cuối của `https://fish.audio/m/<id>`) và tùy chỉnh câu thoại.
3. Tạo và đổi:
   ```bash
   export FISH_AUDIO_API_KEY=...           # từ https://fish.audio
   node ~/.claude/voice-notify/generate-sounds.mjs
   voice <id-giọng-của-bạn>
   ```

`generate-sounds.mjs` có tính bất biến (idempotent) — nó bỏ qua các clip đã có (lệnh gọi mạng có timeout + thử lại).
Dùng `--force` để tạo lại toàn bộ, hoặc truyền một id giọng để chỉ xử lý giọng đó.

### ⚠️ Trách nhiệm về giọng nói / bản quyền

Dự án này **không kèm âm thanh nào** và không liên kết với bất kỳ thương hiệu, tác phẩm hay nhân vật nào.
**Đừng nhân bản giọng của nhân vật có bản quyền, thương hiệu, hay người thật.**
Bạn hoàn toàn chịu trách nhiệm về các model giọng và văn bản mà bạn chọn để tạo và sử dụng.

## Tinh chỉnh

Mọi hành vi nằm trong `~/.claude/voice-notify/notify.sh` và các mục hook trong `~/.claude/settings.json` — cứ tự do sửa:

- **Ồn quá?** `voice off` tắt toàn bộ; hoặc xóa hook `Stop`; hoặc sửa `notify.sh` để im lặng trừ khi lượt đó có dùng công cụ.
- **Không muốn âm chào phiên?** Xóa hook `SessionStart`.
- **Bộ nhắc phiền quá?** `voice remind off`, hoặc đổi lịch bằng biến môi trường `REMIND_DELAYS` trên hook bộ nhắc.
- **Đổi âm hệ thống mặc định?** Sửa bảng `sys_sound()` trong `notify.sh` (bất kỳ file nào trong `/System/Library/Sounds/`).

## Gỡ cài đặt

```bash
./uninstall.sh            # gỡ hook/lệnh/symlink; GIỮ voices.json + gói giọng của bạn
./uninstall.sh --purge    # xóa luôn ~/.claude/voice-notify (toàn bộ)
```

Một bản sao lưu settings.json được ghi trước khi gỡ các hook.

## Cách hoạt động

- `notify.sh <state>` — được mỗi hook gọi; đọc `current-voice`, phát ngẫu nhiên một clip cho trạng thái đó (hoặc âm hệ thống), và hiện thông báo macOS.
- `set-voice.sh` (còn gọi `voice`) — ghi `current-voice`, bật/tắt bộ nhắc, phát mẫu.
- `remind.sh` — vòng lặp bộ nhắc "vẫn đang chờ bạn" tăng dần (khởi động khi `Stop`, hủy khi có nhập liệu).
- `generate-sounds.mjs` — biến `voices.json` thành các clip mp3 qua Fish Audio TTS.

## Lộ trình

- Hỗ trợ Linux (`paplay` / `notify-send`)

## Giấy phép

[MIT](./LICENSE)
