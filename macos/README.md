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
  Nháy toàn màn hình đen + 1 quote ngẫu nhiên (20 s, bấm/phím bất kỳ để tắt, không
  cướp focus); tắt nháy thì chỉ còn banner. Có quote thì 20 s, không thì 6 s (như bản Tauri).
- **Mục tiêu đứng**: nhắc một lần khi chạm mốc mỗi ngày (mặc định 60′).
- **Ngủ/qua ngày đúng**: khoảng máy ngủ bị loại khỏi thống kê; chặng vắt qua nửa đêm
  được tách đúng hai ngày; chặng ngồi liên tục không đứt lúc qua ngày.
- **Thống kê 7 ngày**: biểu đồ cột Ngồi/Đứng + từng ngày.
- **Cài đặt**: mọi ngưỡng, âm thanh, mở cùng máy, quyền nhắc nhở, mở/xóa dữ liệu.
- **Song ngữ Việt–Anh**: chọn trong Cài đặt, áp dụng cho popover, thống kê, cài đặt và nhắc nhở.
- **Lịch phụ**: ô lịch đỏ trong popover — Âm lịch (Việt), Lịch Trung, Do Thái, Hồi giáo,
  Phật lịch hoặc tắt; di chuột lên ô để xem ngày đầy đủ.
- **Quote sức khỏe**: 365 câu song ngữ (105 câu đầu từ bản Tauri), mỗi lần nháy hiện
  1 câu ngẫu nhiên — không phải 1 câu mỗi ngày.
- **Không dock**: app chỉ sống trên menu bar (`LSUIElement`).

## Build & chạy

Yêu cầu: macOS 14+, Xcode (Swift 6).

```bash
./scripts/build-app.sh   # test + build release 0 warning + vẽ icon + ráp .app (ad-hoc signed)
open dist/SittingTime.app
./scripts/build-dmg.sh   # build-app.sh + gói dist/SittingTime.dmg (kéo-thả vào Applications)
```

Chạy dev thô (`swift run`) vẫn được nhưng sẽ hiện dock icon vì thiếu bundle;
bản `.app` mới là cách chạy thật. Mục “Mở cùng máy” cũng chỉ dùng được từ file `.app`.

Dữ liệu: `~/Library/Application Support/SittingTime/` (`records.json`, `settings.json`).

## Kiểm thử

- `swift test`: 41 test (Swift Testing) — state machine với đồng hồ giả (cộng dồn giờ,
  nhắc nhở, tự nghỉ/tiếp tục, giấc ngủ, qua nửa đêm, mục tiêu, định dạng, checkpoint giữ
  đồng hồ hiển thị), định dạng tiếng Anh, settings cũ thiếu key vẫn đọc được, lịch phụ
  (Tết, tháng nhuận, Yom Kippur, Adar I/II, Ramadan, Phật lịch), 365 quote
  (đủ số lượng, không trùng, không quá 160 ký tự, random nằm trong bộ) và hook flash
  (gọi đúng mỗi lần nhắc, tôn trọng 2 công tắc, banner câm khi flash kêu).
- Icon: script vẽ tự kiểm tra pixel (ghế trắng, nền teal, chấm cam, góc trong suốt)
  và kiểm tra file `.icns` đọc lại đủ 7 cỡ ảnh.
- Kiểm tra GUI trên máy thật (ảnh chụp màn hình + danh sách cửa sổ hệ thống):
  menu bar đếm từng giây và chạy tiếp qua mốc checkpoint 30 s (`0:39` ở giây 40);
  popover và cửa sổ thống kê hiển thị số liệu đồng bộ, cập nhật mỗi giây;
  checkpoint ghi `records.json` đúng (30,00 s sau `kill -9` ở giây 40);
  mở bản thứ hai thì bản đó tự thoát (một instance); không crash mới.
- Nháy nhắc nhở chạy thật đầu-cuối: hẹn nhắc 1 phút, đúng phút 60 cửa sổ nháy hiện
  toàn màn hình (lớp screenSaver) với quote ngẫu nhiên, rồi tự tắt (cửa sổ biến mất);
  3 lần chạy cho 3 quote khác nhau. Cửa sổ SwiftUI tự co theo nội dung nên view nháy
  phải đặt khung đúng cỡ màn hình, và nền mờ không ăn trên cửa sổ này nên dùng đen đặc.
- Chưa kiểm tra (cần một cú click chuột thật của bạn): bấm các nút trong popover,
  hộp xin quyền gửi nhắc nhở lần đầu, banner nhắc nhở, nút Thoát, và tắt-nháy-bằng-click
  — automation trên máy này không nhìn/click được cửa sổ của app menu bar nên chờ bạn.
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
  AppLanguage.swift              # tiếng Việt / tiếng Anh + 5 loại lịch phụ (+ tắt)
  Strings.swift                  # bảng chuỗi song ngữ duy nhất cho toàn app
  SubCalendar.swift              # tính ngày lịch phụ bằng Foundation (âm = Chinese ở UTC+7)
  HealthQuotes.swift             # 365 quote song ngữ, mỗi lần nháy lấy ngẫu nhiên 1 câu
Sources/SittingTime/             # SwiftUI: menu bar, popover, thống kê (Charts), cài đặt
  FlashCenter.swift              # cửa sổ nháy đen toàn màn hình + thẻ tin nhắn/quote
Tests/SittingTimeTests/          # 41 test với FakeClock/FakeIdle/SpyNotify
scripts/build-app.sh             # test → release → icon → ráp + ký .app
scripts/build-dmg.sh             # build-app.sh + gói .dmg kéo-thả vào Applications
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
