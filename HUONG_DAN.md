# Hướng dẫn sử dụng — Mighty Angler v2 (Roblox)

## 1. Dự án này có gì đặc biệt?
**Mighty Angler v2** là game Roblox Simulator (**Câu cá + Tập Gym**, bản Launch 5 Đảo) đã được trang bị sẵn **6 chốt chặn tự động** (`rojo`, `luau-lsp` kèm từ điển API chính chủ của Roblox, `selene` và trình quét an toàn) để bạn chỉ cần giao từng Chặng lớn cho AI tự chạy rồi vào kiểm tra nhanh.

---

## 2. Hai cách mở xem game trong Roblox Studio

### Cách 1 — Mở nhanh nhất (Không cần cài Plugin Rojo)
1. Bấm đúp chuột vào **`run.bat`** (đợi vài giây nó tự chạy 6 bước kiểm tra và đóng gói ra `build\mighty-angler-dev.rbxlx`).
2. Mở **Roblox Studio** → **File → Open from File...** → chọn `build\mighty-angler-dev.rbxlx`.
3. Bấm **Play (F5)** để vào chơi thử.

### Cách 2 — Đồng bộ sống khi muốn vừa mở Studio vừa xem AI sửa
1. Bấm đúp **`run.bat`** và giữ nguyên cửa sổ chạy nền.
2. Trong **Roblox Studio**, chọn tab **Plugins → Rojo → Connect**.
3. Bấm **Play (F5)** để trải nghiệm ngay mọi cập nhật mới.

---

## 3. Mẹo kiểm tra cả chặng chỉ trong 3–5 phút (Nút `[DEV]` trong Studio)
Khi chạy thử trong Roblox Studio (bắt đầu từ Chặng 1), góc màn hình sẽ có nút **`[DEV]`** dành riêng cho chủ dự án (người chơi bình thường khi Publish sẽ không bao giờ thấy):
- Bấm **`+Gold` / `+Strength` / `+Gems`** để mua thử Cần câu, mở Đảo, ấp Trứng ngay lập tức không cần ngồi cày.
- Bấm **`Force Boss`** để lần quăng cần tiếp theo chắc chắn gặp cá Boss kiểm tra thanh Minigame.
- Bấm **`Reset Save`** để xóa dữ liệu thử lại cảm giác người chơi mới tinh.
- Nếu chẳng may có lỗi phát sinh trong Studio, góc trên màn hình sẽ hiện băng báo đỏ rõ ràng — bạn chỉ cần chụp ảnh màn hình gửi vào khung chat là AI sửa đúng chỗ ngay!

---

## 4. Các câu nhắn nhanh hàng ngày với AI
- **Bắt đầu chạy tự động một chặng:**
  > *"Đọc PLAN.md và chạy trọn gói Chặng 1 giúp mình."* *(hoặc gõ `/goal Chạy trọn gói Chặng 1 theo PLAN.md`)*
- **Khi hết Quota muốn chuyển ca (Antigravity ↔ Codex):**
  Mở công cụ còn lại tại `D:\Projects\mighty-angler` và nhắn:
  > *"Đọc AGENTS.md, PROGRESS.md, PLAN.md và kiểm tra git status để làm tiếp phần đang dở."*
- **Khi muốn quay về bản chạy ổn trước đó:**
  > *"Quay lại bản lưu (commit) chạy ổn gần nhất trước đó giúp mình."*
