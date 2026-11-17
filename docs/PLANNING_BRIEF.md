# PLANNING BRIEF — Mighty Angler v2 (Tổng kết từ bản v1 bên Codex)

Tài liệu này gom lại toàn bộ phần **ý tưởng hay cần giữ** và **4 bài học lỗi cần sửa tận gốc** từ dự án cũ (`C:\Users\PC\.zcode\workspace\c933ea4c-33e7-46ce-8e27-3c96decbe3e0\PLAN.md`), để dùng làm điểm xuất phát khi bàn bạc chốt `PLAN.md` mới.

---

## 1. Phần "hồn" của bản v1 rất đáng giữ lại

- **Core Loop 2 trục bổ trợ nhau cực chặt:**
  - **Câu cá → Bán lấy Gold:** Chi tiêu cho **Mở Đảo/Map mới**, mua **Cần câu**, **Mồi câu** (tiêu hao mỗi lần quăng), và **Đồ tập Gym**.
  - **Tập Gym → Tăng Strength:** Không dùng mở map mà làm **cổng sức mạnh để cầm nổi cần câu cấp cao**, từ đó mới câu được cá to / cá hiếm / Boss (kèm đột biến *Shiny / Golden / Cosmic*).
- **Hệ thống chiều sâu hợp lý:**
  - **Pet:** Mỗi map có 2 trứng (trứng Gold bình dân + trứng Gems cao cấp), pet bay theo sau lưng.
  - **Thuốc Buff (Potions):** Tăng Luck / Strength / Sell / Mutation / Tốc độ cắn câu, nhận từ nhiều nguồn (thành tựu, boss drop, câu hiếm, rebirth, quà event).
  - **Chuyển sinh (Rebirth):** Reset tiến độ nhẹ để nhận Gems + hệ số nhân vĩnh viễn, giữ lại Pets / Potions / Thành tựu.
  - **Event định kỳ:** Sự kiện toàn server mỗi 30 phút giúp game luôn có nhịp sôi động.
- **Điểm mạnh kiến trúc kỹ thuật từ v1 nên kế thừa:**
  - Server nắm quyền quyết định dữ liệu (**Server-authoritative**), chống hack tiền/chỉ số.
  - Gom toàn bộ công thức buff vào một module duy nhất (`BuffAggregator`) và toàn bộ kết nối mạng vào một manifest (`Net.luau`).

---

## 2. Bốn "bệnh" chí mạng của bản v1 cần khắc phục triệt để

1. **Code mù 42 task trước khi mở Roblox Studio thật:**
   - Bản cũ chạy hơn 100 test giả lập báo xanh hết, đến lúc mở Roblox Studio thật lần đầu thì **nhân vật rơi thẳng xuống vực** vì AI gọi nhầm lệnh tạo hình cầu `Instance.new("Ball")` không tồn tại trong Roblox Engine và gán vật liệu terrain lên Part.
   - Đẻ ra một tờ phiếu **45 bài test** khổng lồ bắt người dùng tự test dồn một cục.
2. **File code phình to quá giới hạn & đồ họa ghép khối thô:**
   - Bản cũ để `MapThemes.luau` phình lên **1.138 dòng**, `MapBuilder.luau` **903 dòng**, `BagUi.luau` **758 dòng** — rất khó sửa và nhanh đốt quota.
   - Toàn bộ cảnh quan, cây cối, dụng cụ gym dựng bằng code ghép khối vuông/trụ thô, **thiếu Animation nhân vật** (vung cần, gồng tạ) và hiệu ứng phản hồi (Game Feel).
3. **Ôm đồm quá sớm 20+ hệ thống phụ:**
   - Khi cảm giác câu 1 con cá và nâng 1 quả tạ ở Đảo 1 còn chưa "đã tay", giao diện còn để sơ sài ("để làm đẹp sau"), dự án đã dàn trải sang tận Offline Earnings, Compass, Day/Night, Leaderboard, 10 đảo, 70 loài cá, 70 pet.
4. **Quy trình bàn giao & mở chạy thiếu thân thiện:**
   - Chưa có `run.bat` 1-click chuẩn và chưa tổ chức test cuốn chiếu theo từng chặng ngắn trên Studio.

---

## 3. Đề xuất chiến lược làm lại v2 (Vertical Slice — Làm chặng nào sướng chặng đó)

- **Nguyên tắc vàng:** Mỗi file `.luau` **≤ 350 dòng**. Xong chặng nào là đóng gói `.rbxlx` / sync Rojo cho bạn bấm **Play (F5)** kiểm chứng tận mắt trên Roblox Studio ngay chặng đó.
- **Chặng 1 (Mục tiêu đầu tiên — "Chơi đã tay ngay tại Đảo 1"):**
  - Dựng Đảo 1 đẹp mắt (bãi biển, cầu gỗ câu cá, khu Gym, quầy bán cá, cổng sang Đảo 2).
  - Câu cá + Minigame cuốn + **Animation vung cần/giật cá** + hiệu ứng phao/nước/cá nổi + số `+Gold / +Strength` nảy đẹp.
  - Tập Gym có **Animation tập luyện** (tùy chọn thủ công hoặc Auto-Train).
  - Giao diện HUD, Túi đồ, Shop Cần câu cơ bản thiết kế đẹp ngay từ đầu (bo góc, icon rõ, responsive).
  - Lưu dữ liệu chuẩn xác.
- **Chặng 2 (Chiều sâu vòng lặp & Đảo 2):**
  - Shop Mồi câu, Đồ tập Gym, hệ thống Pet (trứng + pet bay theo), Potions, và mở khóa Đảo 2 bằng Gold để test trọn vẹn vòng lặp tăng tiến.
- **Chặng 3 (Mở rộng & Giữ chân người chơi):**
  - Nhân rộng thêm các đảo mới (chỉ sau khi Đảo 1–2 đã cực kỳ ổn định), bổ sung Rebirth, Bộ sưu tập Index, Thành tựu, Server Event 30 phút, Bảng xếp hạng và Âm thanh hoàn thiện.

---

## 4. Bốn câu hỏi cần bạn & AI bàn chốt trước khi viết `PLAN.md`

1. **Chủ đề & Vòng lặp:** Giữ nguyên chủ đề **Câu cá + Tập Gym (Mighty Angler)** như v1 hay muốn điều chỉnh/thêm bớt hệ thống nào?
2. **Cảm giác Câu cá & Tập Gym:**
   - *Câu cá:* Chọn kiểu **căn bấm vạch xanh 1–3 nhịp** (nhanh, gọn) hay kiểu **thanh kéo giữ cá chạy qua lại kiểu Fisch** (hồi hộp, giữ nhịp)?
   - *Tập Gym:* Chọn kiểu **đứng vào máy tự tăng đều** hay **bấm chuột mỗi nhịp nâng tạ + có nút Auto-Train miễn phí**?
3. **Hướng làm hình ảnh 3D (Đảo, cây cối, cần câu, cá, pet):**
   - Chọn **100% AI tự dựng bằng code** (theo phong cách Low-Poly mịn màng hơn v1), hay kết hợp **kéo thêm mô hình 3D đẹp từ Roblox Studio Toolbox** (AI hướng dẫn vị trí & đặt tên chuẩn, bạn mất vài cú click chọn mẫu ưng ý)?
4. **Phạm vi Chặng 1:** Chốt làm thật hoàn hảo **Đảo 1** để bạn chơi thử ưng bụng trên Studio rồi mới mở rộng tiếp chứ?
