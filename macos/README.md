# SittingTime (bản macOS)

App menu bar theo dõi thời gian ngồi/đứng trong ngày: bấm giờ, tự tạm nghỉ khi bạn rời máy,
nhắc đứng dậy sau mỗi chặng ngồi liên tục, thống kê 7 ngày. Tiếng Việt, không mạng,
không tài khoản, dữ liệu chỉ nằm trên máy.

> Ghi chú nguồn gốc: bản macOS native (Swift) này được viết lúc repo gốc còn ở chế độ
> private và chưa truy cập được, nên ban đầu nó được dựng từ cái tên và mục đích của repo.
> Sau khi đọc SPEC Tauri, mô hình hai bản khác nhau: bản Tauri là timer theo phiên
> (Stand Up 45/5, Pomodoro 25/5/15), còn bản macOS này theo dõi cộng dồn ngồi/đứng/nghỉ
> trong ngày. Giữ cả hai cho tới khi chủ repo quyết định có hội tụ hay không.

## Tính năng

- **Menu bar trực tiếp**: icon trạng thái + đồng hồ đang chạy (Ngồi / Đứng / Nghỉ).
- **Popover**: đồng hồ lớn, chuyển Ngồi/Đứng/Nghỉ, nút Tạm nghỉ/Tiếp tục, tổng hôm nay,
  tiến độ mục tiêu đứng, số lần nghỉ, chặng ngồi dài nhất.
- **Tự tạm nghỉ**: sau N phút không dùng chuột/phím (mặc định 5′); tự tiếp tục khi quay lại.
- **Nhắc đứng dậy**: mỗi X phút ngồi liên tục (mặc định 45′), kèm tổng ngồi/đứng hôm nay.
- **Mục tiêu đứng**: nhắc một lần khi chạm mốc mỗi ngày (mặc định 60′).
- **Ngủ/qua ngày đúng**: khoảng máy ngủ bị loại khỏi thống kê; chặng vắt qua nửa đêm
  được tách đúng hai ngày; chặng ngồi liên tục không đứt lúc qua ngày.
- **Thống kê 7 ngày**: biểu đồ cột Ngồi/Đứng + từng ngày.
- **Cài đặt**: mọi ngưỡng, âm thanh, mở cùng máy, quyền nhắc nhở, mở/xóa dữ liệu.
- **Không dock**: app chỉ sống trên menu bar (`LSUIElement`).

## Build & chạy

Yêu cầu: macOS 14+, Xcode (Swift 6).

```bash
./scripts/build-app.sh   # test + build release 0 warning + vẽ icon + ráp .app (ad-hoc signed)
open dist/SittingTime.app
```

Chạy dev thô (`swift run`) vẫn được nhưng sẽ hiện dock icon vì thiếu bundle;
bản `.app` mới là cách chạy thật. Mục “Mở cùng máy” cũng chỉ dùng được từ file `.app`.

Dữ liệu: `~/Library/Application Support/SittingTime/` (`records.json`, `settings.json`).

## Kiểm thử

- `swift test`: 25 test (Swift Testing) cho state machine với đồng hồ giả —
  cộng dồn giờ, nhắc nhở, tự nghỉ/tiếp tục, giấc ngủ, qua nửa đêm, mục tiêu, định dạng,
  checkpoint giữ đồng hồ hiển thị chạy tiếp và không đếm trùng.
- Icon: script vẽ tự kiểm tra pixel (ghế trắng, nền teal, chấm cam, góc trong suốt)
  và kiểm tra file `.icns` đọc lại đủ 7 cỡ ảnh.
- Kiểm tra GUI trên máy thật (ảnh chụp màn hình + danh sách cửa sổ hệ thống):
  menu bar đếm từng giây và chạy tiếp qua mốc checkpoint 30 s (`0:39` ở giây 40);
  popover và cửa sổ thống kê hiển thị số liệu đồng bộ, cập nhật mỗi giây;
  checkpoint ghi `records.json` đúng (30,00 s sau `kill -9` ở giây 40);
  mở bản thứ hai thì bản đó tự thoát (một instance); không crash mới.
- Chưa kiểm tra (cần một cú click chuột thật của bạn): bấm các nút trong popover,
  hộp xin quyền gửi nhắc nhở lần đầu, banner nhắc nhở, và nút Thoát — automation
  trên máy này không nhìn/click được cửa sổ của app menu bar nên phần này chờ bạn.
  Đường lưu khi thoát đã có checkpoint đỡ: tệ nhất mất 30 s cuối nếu bị kill.

## Bố cục

```
Package.swift                    # Swift 6, macOS 14+, không dependency
Sources/SittingCore/             # logic thuần, test được (không AppKit/SwiftUI)
  SittingStore.swift             # state machine + timer + idle + nhắc + qua ngày + ngủ
  DayRecord.swift                # bản ghi một ngày (ngồi/đứng/nghỉ, lần nghỉ, ngồi lâu nhất)
  AppSettings.swift              # ngưỡng + clamp
  Persistence.swift              # JSON dưới Application Support, lỗi ghi stderr
  IdleMonitor.swift              # HIDIdleTime qua IOKit (chỉ đọc)
  ReminderCenter.swift           # bọc UserNotifications (live/silent)
  LoginItemManager.swift         # SMAppService
  SitPhase.swift / Formatting.swift
Sources/SittingTime/             # SwiftUI: menu bar, popover, thống kê (Charts), cài đặt
Tests/SittingTimeTests/          # 25 test với FakeClock/FakeIdle/SpyNotify
scripts/build-app.sh             # test → release → icon → ráp + ký .app
scripts/generate-icon.swift      # vẽ icon + tự kiểm tra + ráp .icns thủ công
Resources/Info.plist             # LSUIElement, id com.0xdonniechu.sittingtime
```

## Quyết định đã chốt

- UI tiếng Việt (app cá nhân, không thuộc bộ Ambysto nên không theo spec suite bar).
- Nhắc nhở tính theo **ngồi liên tục** (đứng dậy là reset), không phải tổng cả ngày.
- Đọc idle = `HIDIdleTime` (IOKit) vì hằng `kCGAnyInputEventType` không import được
  vào Swift ở SDK hiện tại.
- Không dùng `iconutil` (lỗi `Invalid Iconset` trong môi trường build này dù iconset
  đúng chuẩn) — ráp `.icns` trực tiếp theo đúng format Apple.
- Chỉ một instance: khóa file `.lock` bằng `flock` — bản thứ hai tự thoát để không
  đếm giờ trùng và giẫm `records.json` của nhau.
- Status item viết tay bằng AppKit (`NSStatusItem` + `refreshStatusItem` mỗi tick):
  `MenuBarExtra` chỉ render label một lần rồi đứng yên, còn `TimelineView` treo cứng
  main thread (đã bisect chứng minh). View SwiftUI trong popover/thống kê quan sát
  store qua `.environment` và đọc thêm `tickCount`, vì mọi input khác đều đứng yên
  trong lúc ngồi — thiếu nó là view render một lần rồi đông cứng (đã bắt được bằng ảnh).
- Checkpoint 30 s giữ `displayOffset` để đồng hồ hiển thị chạy tiếp qua mốc checkpoint;
  `liveToday()` cộng đúng phần segment còn mở nên không đếm trùng (có test khóa lại).
