# AGENTS.md — Mighty Angler v2 (Roblox Simulator)

Hướng dẫn chuẩn cho **OpenAI Codex** (Kỹ sư trưởng) và **Antigravity** (Trợ lý thi công) khi cùng làm việc trên dự án tại `D:\Projects\mighty-angler`.

---

## 1. Phân định vai trò & Quyền hạn (Team Roles)
- **OpenAI Codex — Kỹ Sư Trưởng & Tổng Kiến Trúc Sư (Lead Engineer & Principal Architect):**
  - Nắm quyền quyết định cao nhất về kiến trúc hệ thống, logic Server-Authoritative, DataStore, bảo mật và trải nghiệm người chơi.
  - Chịu trách nhiệm duyệt code (Code Review), kiểm toán định kỳ (Audit), nghiệm thu tính năng và ra quyết định phát hành (Production Sign-off).
  - Chỉ đạo lộ trình các bản phát hành kế tiếp (Phase 3 / Update 1: Trading, Clan, World Boss,...).
- **Antigravity — Trợ Lý Thi Công & Thực Thi Cục Bộ (Local Construction & Execution Agent):**
  - Thực thi các lệnh kiểm định tự động (`tools/verify_project.ps1`), đóng gói place `.rbxlx` và chạy Rojo server trên máy Windows.
  - Thi công chi tiết mã nguồn Luau, sửa lỗi, cập nhật tài liệu và tạo atomic commit theo chỉ đạo của Kỹ sư trưởng Codex.
  - Báo cáo kết quả kiểm tra cục bộ trung thực, không bao che lỗi, đảm bảo 100% tuân thủ giới hạn file `<= 350` dòng.

---

## 2. Tổng quan dự án & Hiện trạng mã nguồn
- **Tên dự án:** Mighty Angler (v2.0 Overhaul — Bản Launch 5 Đảo chuẩn Fisch × PS99 × Arm Wrestle)
- **Thể loại:** Game Roblox Simulator (**Luau + Rojo**), giao diện Tiếng Anh chuẩn quốc tế, Nước biển `Terrain Water` sóng thật + NPC người thật R15 + Lưới 3D `ViewportFrame` + hỗ trợ `Assets Override` từ Toolbox.
- **Trạng thái hiện tại:** Đã hoàn tất trọn gói **Đại Tu 2.0 cả 4 Chặng (`Chặng A → Chặng D`) + Bản Vá Hotfix Vòng Cuối** xử lý 100% kiểm toán của cả Codex & Argon (`88` file `.luau`, mọi file `≤ 350` dòng, cả 5 file cam kết riêng `< 310` dòng, đạt `[PASS] 6/6` kiểm định tự động).
- **Commit mới nhất:** `8227545` (`fix(v2-audit): resolve 100% of P0/P1/P2 findings from Codex & Argon code audits`).

---

## 2. Cấu trúc thư mục & Lệnh kiểm tra
- `PLAN.md` — **Nguồn sự thật duy nhất** về thiết kế gameplay, thông số 5 đảo, kiến trúc file và lộ trình 3 Chặng.
- `docs/PLANNING_BRIEF.md` — Tài liệu tóm tắt bài học từ bản v1 cũ.
- `PROGRESS.md` — Sổ bàn giao tiến độ dùng chung giữa Antigravity ↔ Codex.
- `default.project.json` — Cấu hình ánh xạ Rojo (`src/shared` → `ReplicatedStorage/Shared`, `src/server` → `ServerScriptService/Server`, `src/client` → `StarterPlayerScripts/Client`).
- `tools/` — Bộ công cụ kiểm định cục bộ gồm `rojo.exe` (7.7.1), `luau-lsp.exe` (1.70.1 + `globalTypes.d.luau`), `selene.exe` (0.32.0), `install_tools.ps1` và `verify_project.ps1`.
- `build/mighty-angler-dev.rbxlx` — File place đóng gói sẵn để mở test trên Roblox Studio.
- `run.bat` — Chạy 1-click trên Windows (chạy 6 bước kiểm tra + build `.rbxlx` + bật `rojo serve`).
- `logs/app.log` — Nhật ký kiểm tra & lỗi khi build/sync.

### Lệnh verify bắt buộc sau MỖI task (exit code `0` = đạt đủ 6 chốt chặn)
```powershell
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
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
