# AGENTS.md — Mighty Angler v2 (Roblox Simulator)

Hướng dẫn chuẩn cho **Antigravity** và **OpenAI Codex** khi cùng làm việc trên dự án tại `D:\Projects\mighty-angler`.

---

## 1. Tổng quan dự án
- **Tên dự án:** Mighty Angler (v2 Rebuild)
- **Thể loại:** Game Roblox Simulator (**Luau + Rojo**) làm lại từ đầu theo hướng **Vertical Slice (làm cuốn chiếu từng phần chơi thật)**, kiểm thử trực tiếp trên Roblox Studio từng chặng nhỏ.
- **Trạng thái nguồn code:** Giai đoạn 0 (Chuẩn bị lập `PLAN.md` — CHƯA viết code gameplay cho đến khi người dùng chốt Plan).

---

## 2. Cấu trúc thư mục & Lệnh kiểm tra
- `docs/PLANNING_BRIEF.md` — Tóm tắt phần tinh hoa & bài học từ bản v1 để bàn lập `PLAN.md` mới.
- `PROGRESS.md` — Sổ bàn giao tiến độ dùng chung giữa Antigravity ↔ Codex.
- `default.project.json` — Cấu hình ánh xạ Rojo (`src/shared` → `ReplicatedStorage/Shared`, `src/server` → `ServerScriptService/Server`, `src/client` → `StarterPlayerScripts/Client`).
- `tools/rojo.exe` — Công cụ build/sync Rojo cục bộ (7.7.1).
- `build/mighty-angler-dev.rbxlx` — File place đóng gói sẵn để mở test trên Roblox Studio.
- `run.bat` — Chạy 1-click trên Windows (build `.rbxlx` + bật `rojo serve`).
- `logs/app.log` — Nhật ký lỗi khi build/sync.

### Lệnh verify bắt buộc (exit code `0` = đạt)
```powershell
tools\rojo.exe build default.project.json -o build\mighty-angler-dev.rbxlx
```

---

## 3. Quy tắc kỹ thuật & An toàn riêng của dự án Roblox

1. **Giới hạn kích thước file (≤ 350 dòng / file `.luau`):**
   - TUYỆT ĐỐI KHÔNG nhồi map, UI hay service thành file hàng nghìn dòng như bản v1.
   - Chủ động tách nhỏ thành từng module theo nhiệm vụ (ví dụ: `Maps/Island1.luau`, `UI/Components/...`, `Services/...`).
2. **Chuẩn Roblox Engine API thật (Cấm gọi API ảo):**
   - Luôn kiểm tra class, enum và material hợp lệ của Roblox Engine.
   - **CẤM LẶP LẠI LỖI V1:** Không bao giờ viết `Instance.new("Ball")` (phải là `Instance.new("Part")` + `Shape = Enum.PartType.Ball`), và KHÔNG gán terrain-only material (`Enum.Material.Water`, `Basalt`, `Snow`, `Glacier`, `Ground`, `LeafyGrass`, `Rock`, `Sandstone`, `CrackedLava`, `Mud`, `Salt`, `Limestone`, `Pavement`) trực tiếp lên `BasePart` vì Roblox Studio sẽ crash runtime.
3. **Làm cuốn chiếu & Test Studio sớm:**
   - Không code mù hàng chục task một lèo. Mỗi chặng nhỏ xong phải build ra `.rbxlx` hoặc sync Rojo để người dùng bấm **Play (F5)** xem tận mắt trên Roblox Studio ngay.
4. **Kiến trúc Server-Authoritative:**
   - Mọi tính toán Gold, Gems, Strength, túi đồ, mồi, thuốc, giao dịch mua bán phải do Server quyết định và kiểm tra; Client chỉ gửi yêu cầu hành động và hiển thị phản hồi.
   - Tập trung toàn bộ RemoteEvent vào một manifest duy nhất (`Net.luau`) và gộp toàn bộ hệ số buff vào một nơi duy nhất (`BuffAggregator`).
5. **Tham chiếu bản v1 cũ (CHỈ ĐỌC — KHÔNG ĐƯỢC SỬA/XÓA):**
   - Nếu cần tra cứu thông số cân bằng hoặc ý tưởng cũ, CHỈ ĐƯỢC ĐỌC tại:
     `C:\Users\PC\.zcode\workspace\c933ea4c-33e7-46ce-8e27-3c96decbe3e0\PLAN.md`
   - NGHIÊM CẤM chỉnh sửa, di chuyển hoặc xóa bất kỳ file nào trong workspace cũ đó.
6. **Giao tiếp & Bàn giao ca:**
   - Trao đổi với người dùng bằng **tiếng Việt đời thường, ngôn ngữ sản phẩm** (trải nghiệm người chơi, hình ảnh, cảm giác bấm nút).
   - Sau mỗi bước ổn định, cập nhật `PROGRESS.md` và tạo atomic `git commit` làm điểm lưu an toàn.
   - Nếu sửa cùng một lỗi quá 2 lần chưa xong → dừng lại ghi rõ vào `PROGRESS.md` để đổi model hoặc chuyển công cụ.
