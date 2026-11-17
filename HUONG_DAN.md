# Hướng dẫn sử dụng — Mighty Angler v2 (Roblox)

## 1. Dự án này đang ở đâu?
Đây là dự án game Roblox **Mighty Angler (phiên bản làm lại từ đầu v2)** theo thể loại **Câu cá + Tập Gym Simulator**, được tổ chức theo hướng gọn nhẹ, ưu tiên trải nghiệm chơi thật trên Roblox Studio ngay từ sớm.

---

## 2. Hai cách mở xem game trong Roblox Studio

### Cách 1 — Đồng bộ sống khi đang làm việc cùng AI (Khuyên dùng)
1. Bấm đúp chuột vào file **`run.bat`** ở thư mục gốc dự án.
2. Mở **Roblox Studio** (mở một map trống hoặc file `.rbxlx` đang test).
3. Trên thanh công cụ chọn tab **Plugins → Rojo → Connect**.
4. Từ lúc này, AI sửa code trong máy bạn tới đâu là Roblox Studio tự cập nhật tới đó; bạn chỉ cần bấm **Play (F5)** để chơi thử ngay.

### Cách 2 — Mở file chạy thử ngay không cần cài Plugin Rojo
1. Nếu chưa mở Studio, cứ bấm đúp **`run.bat`** (đợi vài giây nó tự đóng gói bản mới nhất vào `build\mighty-angler-dev.rbxlx`), rồi tắt cửa sổ đen đi cũng được.
2. Mở **Roblox Studio** → **File → Open from File...** → chọn file `build\mighty-angler-dev.rbxlx`.
3. Bấm **Play (F5)** để trải nghiệm trực tiếp.

---

## 3. Các câu nhắn nhanh hàng ngày với AI
- **Khi hết Quota muốn chuyển ca (Antigravity ↔ Codex):**
  Mở công cụ còn lại tại thư mục `D:\Projects\mighty-angler` và nhắn:
  > *"Đọc AGENTS.md, PROGRESS.md và kiểm tra git status để làm tiếp phần đang dở."*
- **Khi AI sửa nhầm làm hỏng bản đang chạy ngon:**
  > *"Quay lại bản lưu (commit) chạy ổn gần nhất trước đó giúp mình."*
- **Khi `run.bat` hoặc game báo lỗi:**
  > *"Đọc file logs/app.log (hoặc mình gửi ảnh lỗi Output Roblox Studio) và sửa giúp mình."*
