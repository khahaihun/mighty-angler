# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 01:08 bởi Antigravity
- **Trạng thái hiện tại:** Đã hoàn thành **Giai đoạn 0 — Chốt thiết kế & lập `PLAN.md` mới** *(CHƯA viết code gameplay, sẵn sàng chạy Chặng 1 ngay khi người dùng ra lệnh bắt đầu)*.

---

## Đã hoàn thành [x]
- [x] Khởi tạo thư mục dự án mới chuẩn Vibe Code tại `D:\Projects\mighty-angler`
- [x] Thiết lập Git, `.gitignore`, `.env.example`, cấu hình `default.project.json`, bản sao `tools/rojo.exe` (7.7.1)
- [x] Tạo sẵn công cụ chạy 1-click `run.bat`, hướng dẫn `HUONG_DAN.md` và sổ quy chuẩn `AGENTS.md`
- [x] Tổng hợp tinh hoa & 4 bài học từ bản v1 cũ vào `docs/PLANNING_BRIEF.md`
- [x] Thảo luận và chốt toàn bộ phương án sản phẩm với người dùng, viết hoàn chỉnh `PLAN.md`:
  - Core loop: Gold mở Đảo/mua đồ; Strength vừa mở Cần câu xịn vừa giúp cá cắn nhanh hơn nhẹ & thanh Minigame rộng hơn.
  - Câu cá: Cá thường tự lên nhàn tay, chỉ cá Hiếm/Boss mới bật thanh Minigame.
  - Tập Gym & Auto: Tập bằng click chuột có Animation; tách riêng **Auto-Train = Join Group miễn phí** và **Auto-Fish = Gamepass giá rẻ** (có cờ test nhanh trong Studio).
  - Đồ họa & Ngôn ngữ: Low-Poly mượt đẹp bằng code + khớp `Assets Override` cho mẫu Toolbox; UI Tiếng Anh.
  - Quy mô & Nhịp làm: **5 Đảo chất lượng cao cho bản Launch** (kèm cổng *Coming Soon* dễ update thêm đảo sau này), chia làm **3 Chặng chạy tự động** để người dùng chỉ cần mở Studio check 3 lần.

## Đang làm dở [~]
- *(Không có — vừa hoàn tất lập `PLAN.md`, chờ người dùng xem lướt lần cuối và phát lệnh chạy Chặng 1).*

## Bước tiếp theo [ ]
- [ ] Khi người dùng ra lệnh bắt đầu thi công: Chạy tự động trọn gói **Chặng 1 (M1.1 → M1.6)** trong `PLAN.md` (Đảo 1 hoàn chỉnh + Câu cá + Gym + Auto-Train/Auto-Fish + UI Tiếng Anh + DataStore + Verify tự động + xuất file `.rbxlx` để người dùng mở Studio check Lần 1).
- [ ] Tiếp tục **Chặng 2 (M2.1 → M2.4)** sau khi người dùng duyệt Chặng 1.
- [ ] Tiếp tục **Chặng 3 (M3.1 → M3.4)** hoàn thiện bản Launch 5 Đảo.

---

## Quyết định kỹ thuật & Lưu ý cho AI ca sau
- Luôn đọc `PLAN.md` làm nguồn sự thật duy nhất trước khi bắt đầu code.
- Tuân thủ nghiêm ngặt giới hạn **≤ 350 dòng / file `.luau`** và chạy script kiểm tra tự động (`tools/verify_project.ps1` + `rojo build`) sau mỗi mục con để đảm bảo 0 lỗi runtime khi người dùng mở Roblox Studio.
- Workspace bản v1 cũ (`C:\Users\PC\.zcode\workspace\c933ea4c-33e7-46ce-8e27-3c96decbe3e0\PLAN.md`) chỉ được phép ĐỌC khi cần tham khảo, tuyệt đối không sửa/xóa.
