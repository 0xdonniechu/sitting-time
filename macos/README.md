# SittingTime (bản macOS)

App menu bar giữ nhịp đứng dậy cho người ngồi làm việc nhiều: phiên làm việc đếm
ngược (mặc định 45:00), hết phiên chuông + nháy màn hình nhắc đứng dậy vận động
5:00, rồi tự vào phiên mới. Ngồi hay đứng trong phiên đều được ghi lại, thống kê
tổng phút ngồi/đứng mỗi ngày và 7 ngày qua. Mục tiêu duy nhất: không ngồi lì hàng
giờ — nguyên nhân hàng đầu của đau lưng, thoái hóa cột sống và thoát vị đĩa đệm
ở dân văn phòng và dev. Tiếng Việt, không mạng, không tài khoản, dữ liệu chỉ
nằm trên máy.

> Ghi chú nguồn gốc: bản macOS native (Swift) này khởi đầu là tracker cộng dồn
> ngồi/đứng/nghỉ, dựng từ cái tên và mục đích của repo lúc repo gốc còn private.
> Sau đó chủ repo quyết định hội tụ về mô hình của bản Tauri: timer theo phiên
> (Stand Up 45/5, Pomodoro 25/5/15), với tư thế Ngồi/Đứng trong phiên ghi vào cùng
> bộ thống kê ngồi/đứng.

## Tính năng

- **Phiên đếm ngược**: Stand Up (làm việc 45 → vận động 5, lặp lại) hoặc Pomodoro
  (tập trung 25 → nghỉ ngắn 5, nghỉ dài 15 sau mỗi 4 phiên); số phút nào cũng sửa
  được trong Cài đặt. Hết phiên tự sang phiên tiếp theo — không cần bấm gì.
- **Chuông + nháy mỗi lần hết phiên**: hết phiên làm việc nhắc đứng dậy vận động,
  hết phiên nghỉ nhắc vào phiên mới. Nháy toàn màn hình đen + 1 quote ngẫu nhiên
  (20 s, bấm/phím bất kỳ để tắt, không cướp focus); tắt nháy thì chỉ còn banner.
  Có quote thì 20 s, không thì 6 s (như bản Tauri).
- **Menu bar trực tiếp**: icon theo phiên/tư thế + đồng hồ đếm ngược (chữ số cố
  định độ rộng nên không giật).
- **Popover**: đồng hồ lớn, thanh tiến độ phiên, chuyển Ngồi/Đứng, Tạm nghỉ/Tiếp tục,
  Bỏ qua (nhảy phiên), đổi chế độ Stand Up/Pomodoro, tổng hôm nay, tiến độ mục tiêu
  đứng, số lần đứng dậy, chặng ngồi dài nhất.
- **Tự tạm nghỉ**: sau N phút không dùng chuột/phím (mặc định 5′); tự tiếp tục khi quay lại.
- **Mục tiêu đứng**: nhắc một lần khi chạm mốc mỗi ngày (mặc định 60′).
- **Ngủ/qua ngày đúng**: khoảng máy ngủ bị loại khỏi thống kê và đóng băng phiên;
  chặng vắt qua nửa đêm được tách đúng hai ngày; phiên và chặng ngồi chạy tiếp qua ngày.
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

- `swift test`: 50 test (Swift Testing) — state machine với đồng hồ giả (đếm ngược,
  tự sang phiên Stand Up/Pomodoro, bỏ qua im lặng, tạm nghỉ đóng băng phiên, tư thế
  ghi giờ ngồi/đứng, đổi chế độ, sửa số phút restart đúng phiên, tự nghỉ/tiếp tục,
  giấc ngủ, qua nửa đêm, mục tiêu, checkpoint không đếm trùng và không rung đồng hồ),
  định dạng tiếng Anh, settings đời cũ (còn key `sitReminderMinutes`) vẫn đọc được,
  lịch phụ (Tết, tháng nhuận, Yom Kippur, Adar I/II, Ramadan, Phật lịch), 365 quote
  (đủ số lượng, không trùng, không quá 160 ký tự, random nằm trong bộ) và hook flash
  (gọi đúng mỗi lần hết phiên, tôn trọng 2 công tắc, banner câm khi flash kêu).
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
  SittingStore.swift             # state machine phiên + timer + idle + qua ngày + ngủ
  Session.swift                  # SessionMode/Kind/Posture (Stand Up, Pomodoro, Ngồi/Đứng)
  DayRecord.swift                # bản ghi một ngày (ngồi/đứng/nghỉ, lần đứng dậy, ngồi lâu nhất)
  AppSettings.swift              # số phút từng phiên + ngưỡng + clamp
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
Tests/SittingTimeTests/          # 50 test với FakeClock/FakeIdle/SpyNotify
scripts/build-app.sh             # test → release → icon → ráp + ký .app
scripts/build-dmg.sh             # build-app.sh + gói .dmg kéo-thả vào Applications
scripts/generate-icon.swift      # vẽ icon + tự kiểm tra + ráp .icns thủ công
Resources/Info.plist             # LSUIElement, id com.0xdonniechu.sittingtime
```

## Quyết định đã chốt

- UI tiếng Việt (app cá nhân, không thuộc bộ Ambysto nên không theo spec suite bar).
- Timer theo **phiên đếm ngược tự chuyển** (như bản Tauri), không đếm cộng dồn mở:
  Stand Up 45/5, Pomodoro 25/5/15 sau mỗi 4 phiên tập trung; hết phiên nào cũng
  chuông + nháy. Tư thế Ngồi/Đứng trong phiên làm việc ghi vào thống kê ngồi/đứng;
  giờ nghỉ, tạm nghỉ và auto-pause đều tính là nghỉ.
- Số lần “đứng dậy” = số phiên làm việc hoàn thành (bỏ qua không tính); chặng ngồi
  liên tục chỉ đứt khi đứng/tạm nghỉ — ngồi xuyên qua phiên nghỉ vẫn tính liền.
- Sửa số phút của đúng phiên đang chạy thì phiên đó restart; sửa các ô khác không
  ảnh hưởng phiên đang chạy (luật của bản Tauri). Đổi chế độ thì về phiên làm việc mới.
- Đọc idle = `HIDIdleTime` (IOKit) vì hằng `kCGAnyInputEventType` không import được
  vào Swift ở SDK hiện tại.
- Không dùng `iconutil` (lỗi `Invalid Iconset` trong môi trường build này dù iconset
  đúng chuẩn) — ráp `.icns` trực tiếp theo đúng format Apple.
- Pixel check của icon chuẩn hóa về 8-bit sRGB trước khi đọc: khi tiến trình thấy
  được màn hình thì `lockFocus` render 16-bit khiến `getPixel` trả rác (từng bị
  nhầm là flake dưới tải — thật ra sandbox đậu / ngoài sandbox rớt, xác định).
- Chỉ một instance: khóa file `.lock` bằng `flock` — bản thứ hai tự thoát để không
  đếm giờ trùng và giẫm `records.json` của nhau.
- Status item viết tay bằng AppKit (`NSStatusItem` + `refreshStatusItem` mỗi tick):
  `MenuBarExtra` chỉ render label một lần rồi đứng yên, còn `TimelineView` treo cứng
  main thread (đã bisect chứng minh). View SwiftUI trong popover/thống kê quan sát
  store qua `.environment` và đọc thêm `tickCount`, vì mọi input khác đều đứng yên
  trong lúc ngồi — thiếu nó là view render một lần rồi đông cứng (đã bắt được bằng ảnh).
- Hai đồng hồ độc lập: đồng hồ phiên chạy đếm ngược, đồng hồ segment chạy ghi giờ;
  checkpoint 30 s chỉ restart segment nên đếm ngược không bao giờ nhảy; `liveToday()`
  cộng đúng phần segment còn mở nên không đếm trùng (có test khóa lại).
- Đồng hồ menu bar dùng `monospacedDigitSystemFont` để item khỏi co giãn (giật)
  mỗi khi chữ số đổi độ rộng.
- Nút Cài đặt mở `NSPanel` thủ công (như Thống kê): action `showSettingsWindow:`
  của scene Settings không chạy từ popover khi app chưa active.
