# AGENTS.md — Mighty Angler v2 (Roblox Simulator)

Hướng dẫn chuẩn cho **Kỹ sư trưởng (Kiến trúc sư kỹ thuật & Review)** và **Trợ lý thi công** khi làm việc trên dự án tại `D:\Projects\mighty-angler`.

---

## 1. Phân định vai trò & Quyền hạn (Team Roles)
- **Antigravity — Kỹ Sư Trưởng, Kiến Trúc Sư Kỹ Thuật & Người Review Code (Lead Engineer & Technical Architect — cập nhật 22/11/2026 theo lệnh Chủ dự án):**
  - Nắm vai trò kiến trúc kỹ thuật, review code, kiểm soát rủi ro DataStore/Server-Authoritative, dẫn dắt hướng đại tu mỹ thuật (Art Direction & Asset Pipeline) và nghiệm thu theo bằng chứng.
  - Không tự ý sửa code, mua/đưa asset vào game, publish Roblox, xóa file hoặc đổi nhánh khi chưa có lệnh rõ ràng của Chủ dự án.
  - Khi được Chủ dự án giao thi công, tuân thủ đầy đủ kiểm định tự động (`tools/verify_project.ps1`, các suite `tools/test_*.ps1`), giới hạn file `<= 350` dòng và quy trình nghiệm thu hai tầng.
- **OpenAI Codex (lịch sử bàn giao đợt V3 ngày 18/11/2026):**
  - Đã thực hiện kiểm toán V3, ban hành blueprint và tích hợp bộ kiểm thử VM đến mốc ứng viên `dd53d3a` / `20218b8` (xem `docs/V3_BAN_GIAO_NGHIEM_THU.md`).

---

## 2. Tổng quan dự án & Hiện trạng mã nguồn
- **Tên dự án:** Mighty Angler (v2.0 Overhaul — Bản Launch 5 Đảo chuẩn Fisch × PS99 × Arm Wrestle)
- **Thể loại:** Game Roblox Simulator (**Luau + Rojo**), giao diện Tiếng Anh chuẩn quốc tế, Nước biển `Terrain Water` sóng thật + NPC người thật R15 + Lưới 3D `ViewportFrame` + hỗ trợ `Assets Override` từ model 3D.
- **Trạng thái hiện tại:** Đã có nền mã nguồn cho 4 Chặng (`A → D`) và bản ứng viên hợp nhất sau kiểm toán V3, nhưng **chưa nghiệm thu trên Roblox Engine thật và chưa duyệt phát hành**.
- **Mốc nguồn đã đối chiếu:** Nhánh `codex/studio-data-isolation`, commit mã/test sạch `dd53d3a` và commit tài liệu bàn giao `20218b8`:
  - Đã hợp nhất các bản vá mã cho 23/23 mục còn một phần của V3 (Đợt 1 dữ liệu đến hết 1.5 ở `8699970`, gameplay câu cá `3f43d35`, UI/Odds `ad013c4` + `9c93901`) và bộ hồi quy 21 mục cũ.
  - **101/101 file `.luau`** mã game trong `src/` đều ≤ 350 dòng (dài nhất `CurrencyService` 342 dòng); 5 file cam kết đều `< 310` (`HudPanel` 275, `ProgressPanel` 268, `PetsService` 299, `FishingService` 288, `BagPanel` 307).
  - **13/13** runner VM mặc định `tools/test_*.ps1` đạt `exit 0`, `tools/verify_project.ps1` đạt **PASS 6/6**, đối chiếu Source XML trong `build/mighty-angler-dev.rbxlx` khớp **101/101**.
  - **Vẫn chờ nghiệm thu thực tế:** Play Solo (F5), Server & Clients (2 client + ping 200ms), 2 server trên Universe Staging tách biệt production, điện thoại thật và đối chiếu ID Gamepass thật.
- **Hướng nâng cấp Mỹ thuật đang triển khai kế hoạch:** Làm lại **Đảo 1 (Sunny Shores)** trước theo gu B (hoạt hình đậm màu, bóng bẩy, dễ thương kiểu PS99 × Arm Wrestle), dùng Terrain tự nhiên dựng trực tiếp trong Studio + model 3D ngân sách `0đ` (duyệt trước từng món), cấu trúc mới **6 Trứng / 24 Pet** (5 Trứng Gold theo đảo + 1 Trứng Gem Exclusive duy nhất ở Đảo 1 có **Pet Exclusive scale theo Pet thường khỏe nhất**). Xem [Kế hoạch Mỹ thuật & Nâng cấp](docs/ART_DIRECTION_AND_REBUILD_PLAN.md).

---

## 3. Cấu trúc thư mục & Lệnh kiểm tra
- `PLAN.md` — **Nguồn thiết kế gameplay**: thông số 5 đảo, quy tắc, kiến trúc file và lộ trình **4 Chặng A–D**; không phải chứng nhận đã hoàn thành.
- `docs/ART_DIRECTION_AND_REBUILD_PLAN.md` — **Kế hoạch Mỹ thuật (Sunny Shores Pilot), Asset Pipeline 0đ & Cấu trúc 6 Trứng / 24 Pet (Exclusive Pet Scaling)** đã chốt cùng Chủ dự án ngày 22/11/2026.
- `docs/V3_BAN_GIAO_NGHIEM_THU.md` & `docs/V3_REGRESSION_MATRIX.md` — Bằng chứng kiểm thử VM của bản ứng viên `dd53d3a` và checklist nghiệm thu chơi thật bắt buộc trước khi phát hành.
- `docs/SPEC_CODE_MATRIX.md` — Đối chiếu từng quy tắc thiết kế với module, phép thử và trạng thái có bằng chứng (mốc kiểm toán lịch sử `45dd21a`, cần đọc cùng `V3_BAN_GIAO_NGHIEM_THU.md`).
- `docs/superpowers/plans/2026-11-18-action-blueprint-v3.md` — Chỉ thị sửa lỗi, quyết định tương thích và điều kiện ký nghiệm thu/phát hành sau V3.
- `docs/PLANNING_BRIEF.md` — Tài liệu tóm tắt bài học từ bản v1 cũ.
- `PROGRESS.md` — Sổ bàn giao tiến độ dùng chung.
- `default.project.json` — Cấu hình ánh xạ Rojo (`src/shared` → `ReplicatedStorage/Shared`, `src/server` → `ServerScriptService/Server`, `src/client` → `StarterPlayerScripts/Client`).
- `tools/` — Bộ công cụ kiểm định cục bộ gồm `rojo.exe` (7.7.1), `luau-lsp.exe` (1.70.1 + `globalTypes.d.luau`), `selene.exe` (0.32.0), `install_tools.ps1`, `verify_project.ps1` và 13 script hồi quy `test_*.ps1`.
- `build/mighty-angler-dev.rbxlx` — File place đóng gói sẵn để mở test trên Roblox Studio.
- `run.bat` — Chạy 1-click trên Windows (chạy 6 bước kiểm tra + build `.rbxlx` + bật `rojo serve`).
- `logs/app.log` — Nhật ký kiểm tra & lỗi khi build/sync.
- `tests/README.md` — Hướng dẫn bộ hồi quy Luau VM (`tools/test_studio_data_isolation.ps1` và các suite thành phần).
- `.github/workflows/ci.yml` — GitHub Actions chạy kiểm định và hồi quy trên mỗi push và pull request, lưu log và bản build làm bằng chứng review.

### Quy trình trước và sau mỗi thay đổi

- Trước mỗi task, đọc [SPEC_CODE_MATRIX.md](docs/SPEC_CODE_MATRIX.md) và [PROGRESS.md](PROGRESS.md) để nắm trạng thái thực tế. Sau mỗi thay đổi, chạy cả hai lệnh dưới đây và ghi kết quả từng lệnh.

```powershell
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
```

---

## 4. Quy tắc kỹ thuật & An toàn riêng của dự án Roblox

1. **Giới hạn kích thước file (≤ 350 dòng / file `.luau`):**
   - TUYỆT ĐỐI KHÔNG nhồi map, UI hay service thành file hàng nghìn dòng như bản v1.
   - Chủ động tách nhỏ thành từng module theo nhiệm vụ (ví dụ: `Maps/Island1.luau`, `UI/Components/...`, `Services/...`).
2. **Chuẩn Roblox Engine API thật (Cấm gọi API ảo):**
   - Luôn kiểm tra class, enum và material hợp lệ của Roblox Engine.
   - **CẤM LẶP LẠI LỖI V1:** Không bao giờ viết `Instance.new("Ball")` (phải là `Instance.new("Part")` + `Shape = Enum.PartType.Ball`), và KHÔNG gán terrain-only material (`Enum.Material.Water`, `Basalt`, `Snow`, `Glacier`, `Ground`, `LeafyGrass`, `Rock`, `Sandstone`, `CrackedLava`, `Mud`, `Salt`, `Limestone`, `Pavement`) trực tiếp lên `BasePart` vì Roblox Studio sẽ crash runtime.
3. **Làm cuốn chiếu và kiểm thử hai tầng:**
   - **Logic thuần:** chạy Luau CLI headless. Dùng mock ở biên dịch vụ như DataStore, tín hiệu và đồng hồ để kiểm logic mà không cần Roblox DataModel thật.
   - **Gameplay/UI:** sau hai lệnh tự động ở mục 3, mở bản `.rbxlx` hoặc sync Rojo để kiểm tra thủ công phần vừa thay đổi. Nghiệm thu bằng **Play Solo (F5)**, **Server & Clients** trong Roblox Studio và chạy trên **điện thoại thật**. Ghi kết quả từng chế độ trước khi đánh dấu xong. Ca chưa chạy ghi **chờ nghiệm thu**.
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
7. **Phát hành qua staging:**
   - Publish bản ứng viên lên place staging trước. Chỉ publish lên place chính sau khi đúng bản ứng viên đã qua nghiệm thu trên staging và Kỹ sư trưởng duyệt phát hành.
