# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 02:12 bởi Antigravity
- **Trạng thái hiện tại:** Đang thi công tự động xuyên đêm — Đã xong **Chặng 1 + M2.1 – M2.2**, đang chuyển sang **M2.3 (Hệ thống 10 Trứng Pet Gold/Gems & Pet bay theo sau lưng)** và **M2.4 (Cân bằng Kinh tế 5 Đảo)**.

---

## Đã hoàn thành [x]
- [x] Khởi tạo thư mục dự án chuẩn Vibe Code tại `D:\Projects\mighty-angler`
- [x] Thảo luận và chốt toàn bộ phương án sản phẩm với người dùng trong `PLAN.md` (5 Đảo Launch dễ update, tách `Auto-Train = Join Group` & `Auto-Fish = Gamepass`, cá thường tự lên / cá Hiếm-Boss Minigame, Low-Poly + `Assets Override`, UI Tiếng Anh, 3 Chặng chạy tự động).
- [x] Thiết lập trọn bộ vũ khí kiểm định tự động Ngày 0 cho dân Vibe Code (`luau-lsp 1.70.1`, `globalTypes.d.luau`, `selene 0.32.0`, `verify_project.ps1`).
- [x] **M1.1** — Hoàn thiện `Types.luau`, `Net.luau`, `Util.luau`, `AssetRegistry.luau`, `GameConfig.luau`, `RodsConfig.luau`, `Islands/Island1_SunnyShores.luau` & `Islands/init.luau` (PASS 6/6).
- [x] **M1.2** — Dựng hoàn chỉnh `PartFactory.luau`, `PropsBuilder.luau`, `IslandScenery1_2.luau`, `WorldBuilder.luau` và `init.server.luau` (PASS 6/6).
- [x] **M1.3** — Hoàn thiện `GamepassesConfig.luau`, `DataService.luau`, `PerkService.luau`, `BuffAggregator.luau`, `CurrencyService.luau`, `ShopAndItemsService.luau` (PASS 6/6).
- [x] **M1.4** — Hoàn thiện `RodVisuals.luau`, `PetAndFishVisuals.luau`, `FishingRoller.luau`, `FishingService.luau`, `AnimationController.luau`, `MinigameBar.luau`, `FishingController.luau` (PASS 6/6).
- [x] **M1.5** — Hoàn thiện `GymService.luau` & `GymController.luau` (Click chuột tập tạ + Auto-Train Group Perk + Animation + tia sáng — PASS 6/6).
- [x] **M1.6** — Hoàn thiện `Theme.luau`, `WindowFrame.luau`, `HudPanel.luau`, `BagPanel.luau`, `ShopPanel.luau`, `DevTestPanel.luau`, `DevTestService.luau`, `StudioErrorReporter.luau`, `SoundConfig.luau`, `SoundAndFxController.luau`, `PromptController.luau`, `init.client.luau` (PASS 6/6).
- [x] **M2.1** — Hoàn thiện `Island2_CoralDepths` → `Island5_CelestialDeep`, `IslandScenery3_5.luau`, cổng *Coming Soon* tại Đảo 5 và `IslandService.luau` mở khóa/dịch chuyển liên đảo (PASS 6/6).
- [x] **M2.2** — Hoàn thiện `BaitConfig.luau`, `GymGearConfig.luau`, `PotionsConfig.luau`, `PotionAndBaitHelper.luau`, nâng cấp `ShopAndItemsService.luau` + hiển thị active buffs trên HUD (PASS 6/6).

## Đang làm dở [~]
- [~] **M2.3 & M2.4** — Hệ thống 10 Trứng Pet (Gold & Gems) + `PetsService.luau` + `PetsPanel.luau` + Kiểm toán cân bằng kinh tế 5 Đảo.

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
