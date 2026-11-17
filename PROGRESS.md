# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 01:44 bởi Antigravity
- **Trạng thái hiện tại:** Đang thi công tự động xuyên đêm — Đã xong **M1.1 – M1.3**, đang chuyển sang **M1.4 (Hệ thống Câu cá Server + Visual Cần/Phao/Cá + Animation + Minigame)**.

---

## Đã hoàn thành [x]
- [x] Khởi tạo thư mục dự án chuẩn Vibe Code tại `D:\Projects\mighty-angler`
- [x] Thảo luận và chốt toàn bộ phương án sản phẩm với người dùng trong `PLAN.md` (5 Đảo Launch dễ update, tách `Auto-Train = Join Group` & `Auto-Fish = Gamepass`, cá thường tự lên / cá Hiếm-Boss Minigame, Low-Poly + `Assets Override`, UI Tiếng Anh, 3 Chặng chạy tự động).
- [x] Thiết lập trọn bộ vũ khí kiểm định tự động Ngày 0 cho dân Vibe Code:
  - Cài đặt cục bộ `tools/luau-lsp.exe` (1.70.1) + từ điển API chính chủ Roblox `tools/globalTypes.d.luau` + `tools/selene.exe` (0.32.0) + script tự phục hồi `tools/install_tools.ps1`.
  - Tạo cấu hình `.luaurc`, `selene.toml` (`std = "roblox"`).
  - Xây dựng và chạy thử xanh 6/6 bước với `tools/verify_project.ps1` (quét `≤ 350 dòng/file`, chặn class/material cấm của Roblox, sinh sourcemap, chạy `luau-lsp analyze`, chạy `selene`, xuất `build/mighty-angler-dev.rbxlx`).
  - Nâng cấp `run.bat`, `AGENTS.md`, `HUONG_DAN.md` và bổ sung quy chuẩn Design System + `DevTestPanel` (`[DEV]` chỉ hiện trong Studio) + `StudioErrorReporter` vào Chặng 1 của `PLAN.md`.
- [x] **M1.1** — Hoàn thiện `Types.luau`, `Net.luau`, `Util.luau`, `AssetRegistry.luau`, `GameConfig.luau`, `RodsConfig.luau`, `Islands/Island1_SunnyShores.luau` & `Islands/init.luau` (PASS 6/6).
- [x] **M1.2** — Dựng hoàn chỉnh `PartFactory.luau`, `PropsBuilder.luau`, `IslandScenery1_2.luau`, `WorldBuilder.luau` và `init.server.luau` (PASS 6/6).
- [x] **M1.3** — Hoàn thiện `GamepassesConfig.luau`, `DataService.luau` (có Studio memory fallback), `PerkService.luau` (tách Group Auto-Train & Gamepass Auto-Fish), `BuffAggregator.luau`, `CurrencyService.luau`, `ShopAndItemsService.luau` (PASS 6/6).

## Đang làm dở [~]
- [~] **M1.4** — Hệ thống Câu cá Server + Visual Cần/Phao/Cá + Animation + Minigame.

## Bước tiếp theo [ ]
- [ ] Chạy tự động trọn gói **Chặng 1 (M1.1 → M1.6)** trong `PLAN.md` ngay khi người dùng phát lệnh bắt đầu (bao gồm Đảo 1 Low-Poly, Câu cá, Gym, Auto-Train/Auto-Fish, UI Tiếng Anh, bảng `[DEV]` Studio, `StudioErrorReporter` và DataStore).
- [ ] Tiếp tục **Chặng 2 (M2.1 → M2.4)** (Đảo 2–5, Mồi, Đồ Gym, Thuốc, Pet bay theo).
- [ ] Tiếp tục **Chặng 3 (M3.1 → M3.4)** (Rebirth, Index, Thành tựu, Event 30 phút, Leaderboard, Âm thanh, Gamepass).

---

## Quyết định kỹ thuật & Lưu ý cho AI ca sau
- Sau **MỖI** bước viết/sửa code `.luau`, bắt buộc chạy lệnh kiểm định duy nhất:
  `powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1`
  Chỉ khi đạt `[PASS] Hoan tat 6/6 chot chan kiem dinh!` mới được đánh dấu hoàn thành mục đó.
- Bảng `DevTestService` / `DevTestPanel` bắt buộc khóa cứng bằng `RunService:IsStudio()` trên cả Server lẫn Client để tuyệt đối an toàn khi Publish.
- Workspace bản v1 cũ (`C:\Users\PC\.zcode\workspace\c933ea4c-33e7-46ce-8e27-3c96decbe3e0\PLAN.md`) chỉ được ĐỌC tham khảo khi cần, nghiêm cấm sửa/xóa.
