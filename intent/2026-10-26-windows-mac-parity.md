---
status: approved
---
# Windows: parity với các tính năng macOS v1.1.x + update UI

**Problem** — Bản Windows (Tauri 0.3.5) thua bản macOS (v1.1.6) một quãng:
không có Statistics kiểu Screen Time, không có About, không có donate,
không có zodiac trên lịch, UI chỉ tiếng Anh, không có standing goal,
đổi mode thì session đang chạy bị reset (Mac giữ session từ v1.0.1).

**Outcome** — Bản Windows có, hành vi khớp Mac:
- Statistics Day/Week: tổng lớn, chart cột theo giờ/ngày (CSS, không thêm
  dependency), legend, rows từng ngày, goal progress, xóa dữ liệu hôm nay /
  xóa toàn bộ lịch sử (có confirm).
- Dash hiện Today: sitting / standing / rest, breaks line, goal progress.
- Footer: nút Stats / Settings / About + pill "Buy me a coffee".
- About: version, tác giả + link, báo lỗi, ghi chú no-tracking.
- Zodiac con giáp trên lịch, standing goal (mặc định 60 phút/ngày như Mac),
  UI song ngữ Anh/Việt (bundled, mặc định English), đổi mode giữ session.
- Tiêu chí xong: `cargo test` các module pure + `npm run build` xanh,
  independent review PASS.

**Constraints** —
- Rust giữ timer state/deadline/persistence; TS chỉ render snapshot
  (luật `AGENTS.md`; grep `Date.now|performance.now|setInterval|new Date`
  trong `src/` vẫn 0 hit cho logic elapsed).
- Không thêm dependency (không React/chart lib/HTTP crate/SQLite/telemetry).
- Không remote API: KHÔNG port update-check qua mạng (AGENTS.md cấm).
- Không đổi product defaults hiện có (45/5, 25/5/15, long break mỗi 4,
  range 1-240/1-12). Default mới duy nhất: standing goal 60 (khớp Mac).
- `state.json` cũ vẫn load được (serde default cho mọi key mới).
- Một branch một change; merge/push chỉ khi owner bảo.

**Out of scope** —
- Idle auto-pause/resume (cần platform API, không có plugin chính chủ).
- Posture picker Sit/Stand (Windows map session→phase, không thêm state).
- Update-check qua mạng, secondary calendar selector, build/installer
  Windows (làm trên máy Windows thật, owner-only).
- Đổi hành vi sleep của timer (SPEC đã chốt deadline catch-up; stats tự
  loại gap > 120 s như Mac).

**Open questions** — (trống; owner đã duyệt "làm tới khi xong, không hỏi thêm").
