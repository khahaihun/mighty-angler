# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 11:42 bởi Antigravity & OpenAI Codex (`gpt-6.2-astra`)
- **Trạng thái hiện tại:** **HAI AI ĐÃ ĐẠT 100% ĐỒNG THUẬN CHỐT `PLAN.md` ĐẠI TU 2.0** *(Biên bản đóng dấu tại `docs/CODEX_CONSENSUS_STAMP.md` — sẵn sàng bắt đầu thi công `Chặng A → Chặng D` ngay khi chủ dự án phát lệnh)*.

---

## Hội Nghị Phản Biện & Chốt Thiết Kế Giữa Antigravity ↔ Codex [x]
- [x] **Vòng 1 (`docs/REVIEW_DAI_TU_2.0.md`):** Codex đối chiếu kế hoạch với 62 file `.luau` thật trong `src/`, chỉ ra 3 điểm nghẽn lớn (giữ câu cá xuyên suốt cả 5 đảo ngay khi thay `Terrain Water` ở A1, tương quan `Max Weight` vs `minRodPower` 5 đảo, và số phận cá khóa + Exclusive Rod khi Rebirth).
- [x] **Vòng 2 & 3 (`docs/DEBATE_ROUND_2.md`, `docs/CODEX_ROUND_2_REPLY.md`, `docs/CODEX_FINAL_VERDICT.md`):** Hai AI tranh luận và chốt hạ giải pháp cho:
  1. **P0 DataStore Session Lock:** Chỉ cho phép ghi khi `activeSessionId == SERVER_JOB_ID`, gia hạn khóa mỗi `60s`, chờ `saveInFlight` trước khi nhả khóa lúc đổi server, khóa giao dịch nếu thử 3 lần không lấy được khóa.
  2. **P1 A (`Soulbound Trophy` qua Rebirth):** Giữ tối đa 12 cá khóa xếp theo `originalValue` (không mất ở các lần Rebirth sau), chặn ở mọi luồng bán Gold ngay trước khi xóa khỏi túi, vẫn cầm khoe trên Hotbar & nộp *Fish Bounty* bình thường; màn hình Rebirth hiện rõ danh sách 12 Trophy & ô ghim.
  3. **P1 B (Minigame chống gian lận không sợ ping cao):** Chấm từng vòng `FishingMinigameStrike` bằng sóng tam giác tất định đối chiếu đồng hồ Server + tách hạn bấm (`7.5s / 9.5s / 11.5s`) khỏi hạn nhận gói (`+0.40s` ân hạn mạng).
  4. **Hiệu năng Mobile & Trần 350 dòng:** `ClientPetRenderer` diễn hoạt Pet trên Client, `ViewportPool` tái sử dụng thẻ 3D không dựng lại toàn lưới khi nhảy tiền, và tách trước 5 file đang sát trần (`331–336` dòng) xuống `< 310` dòng.
- [x] **Vòng 4 (`docs/CODEX_CONSENSUS_STAMP.md`):** Codex xác nhận **`ĐỒNG THUẬN CHỐT PLAN.md`** (0 lỗi P0/P1/P2 tồn đọng).

## Bước tiếp theo [ ]
- [ ] Chờ chủ dự án phát lệnh bắt đầu thi công **Chặng A → Chặng B → Chặng C → Chặng D** theo đúng `PLAN.md`.

---

## Nhật ký Hotfix sau lần test Studio đầu tiên [x]
- [x] **Fix lỗi treo đơ màn hình khi bấm Câu cá / Train (`BuffAggregator ↔ PetsService` mutual recursion):**
  - *Nguyên nhân gốc:* Provider của `PetsService` gọi `sanitizeEquippedList`, hàm này lại gọi ngược `BuffAggregator.GetMultipliers(player).maxEquippedPets` gây vòng lặp đệ quy vô tận (`C stack overflow`) làm Studio đơ 1–2 giây rồi hủy luồng Server.
  - *Cách khắc phục:* Tách riêng hàm trực tiếp `BuffAggregator.GetMaxEquippedPets(player)` (không đi qua danh sách provider) + khóa chống gọi lồng `evaluatingPlayers` trong `BuffAggregator.luau`.
- [x] **Nâng cấp trải nghiệm bấm 1 chạm:**
  - Nếu đứng xa biển mà bấm **`🎣 CAST ROD`** hoặc bật **`Auto-Fish`**, nhân vật tự động dịch chuyển ra ngay mũi Cầu gỗ câu cá của đảo đang đứng và quăng cần luôn.
  - Khi bật **`Auto-Train`** mà chưa đứng trên máy tập, nhân vật tự động bước vào máy tập mạnh nhất đủ điều kiện trên đảo và tập ngay lập tức.
  - Bỏ qua gọi mạng DataStore khi mở file `.rbxlx` cục bộ chưa publish (`game.PlaceId == 0`) giúp tốc độ phản hồi tức thì `0ms`, đồng thời chuyển tiếp mọi lỗi Server lên Toast trong Studio.

## Đã hoàn thành [x]

### Giai đoạn 0 — Thiết kế & Vũ khí kiểm định tự động
- [x] Chốt `PLAN.md` cho bản Launch 5 Đảo (mở rộng nhanh cho các bản Update sau).
- [x] Trang bị cục bộ `luau-lsp 1.70.1`, `globalTypes.d.luau`, `selene 0.32.0`, `rojo 7.7.1`, `tools/install_tools.ps1` và `tools/verify_project.ps1` (6 chốt chặn tự động).

### Chặng 1 — Đảo 1 Hoàn chỉnh & Cảm giác Chơi Cốt lõi (`M1.1 → M1.6`)
- [x] **M1.1:** `Types.luau`, `Net.luau` (tập trung toàn bộ Remote + rate-limit chống spam), `Util.luau`, `AssetRegistry.luau`, `GameConfig.luau`, `RodsConfig.luau`, `Island1_SunnyShores.luau`, `Islands/init.luau`.
- [x] **M1.2:** `PartFactory.luau`, `PropsBuilder.luau`, `IslandScenery1_2.luau`, `WorldBuilder.luau` — dựng Đảo 1 *Sunny Shores* Low-Poly, cầu gỗ, bãi biển đáy nông chống rơi vực, 3 máy Gym, quầy Sell/Shop, trụ Trứng, cổng Đảo và `Lighting` tươi sáng.
- [x] **M1.3:** `GamepassesConfig.luau`, `DataService.luau` (có Studio memory fallback mượt khi chưa bật API Services), `PerkService.luau` (tách rõ `Auto-Train = Join Group` & `Auto-Fish = Gamepass`), `BuffAggregator.luau`, `CurrencyService.luau`, `ShopAndItemsService.luau`.
- [x] **M1.4:** `RodVisuals.luau` (cần câu gắn tay + dây Beam + phao nổi tránh khuất gầm cầu), `PetAndFishVisuals.luau` (cá 3D văng lên đổi màu theo đột biến), `FishingRoller.luau`, `FishingService.luau`, `AnimationController.luau` (tương thích cả R15 & R6), `MinigameBar.luau`, `FishingController.luau`.
- [x] **M1.5:** `GymService.luau` & `GymController.luau` — tập Gym bằng click chuột có Animation + tia sáng + nút `Auto-Train`.
- [x] **M1.6:** `Theme.luau`, `WindowFrame.luau`, `HudPanel.luau`, `BagPanel.luau`, `ShopPanel.luau`, `DevTestPanel.luau` + `DevTestService.luau` (bảng nút `[DEV]` chỉ hiện trong Studio), `StudioErrorReporter.luau`, `SoundConfig.luau`, `SoundAndFxController.luau`, `PromptController.luau`.

### Chặng 2 — Mở rộng 5 Đảo, Vật phẩm & Hệ thống Pet (`M2.1 → M2.4`)
- [x] **M2.1:** Hoàn thiện `Island2_CoralDepths`, `Island3_MysticSwamp`, `Island4_EmberIsle`, `Island5_CelestialDeep` (kèm cổng *COMING SOON* cuối Đảo 5), `IslandScenery3_5.luau` và `IslandService.luau`.
- [x] **M2.2:** Hoàn thiện `BaitConfig.luau` (4 gói mồi), `GymGearConfig.luau` (4 cấp đồ tập), `PotionsConfig.luau` (10 loại thuốc), `PotionAndBaitHelper.luau` và đồng bộ đếm ngược từng giây trên HUD.
- [x] **M2.3:** Hoàn thiện `PetsConfig.luau` (10 Trứng Gold/Gems, 30 loài Pet), `PetsService.luau` (ấp trứng, Boss drop 3%, trang bị 2–4 Pet bay lượn sau lưng, `Equip Best`), `PetsPanel.luau`.
- [x] **M2.4:** Cân bằng kinh tế mượt mà xuyên suốt 5 Đảo & 6 Cần câu, tách gọn `ClientStateController.luau`.

### Chặng 3 — Endgame, Sự kiện, Bảng xếp hạng & Sẵn sàng Phát hành (`M3.1 → M3.4`)
- [x] **M3.1:** `RebirthConfig.luau` + chức năng Chuyển sinh cuối Đảo 5 & Sổ sưu tập Index (35 Cá + 30 Pet, tự động thưởng `+15 Gems` mỗi loài mở mới).
- [x] **M3.2:** `AchievementsConfig.luau`, `ProgressionService.luau`, `ProgressPanel.luau` & `IslandsModal.luau` (15 mốc Thành tựu, Quà đăng nhập theo chuỗi ngày, 3 Nhiệm vụ đổi mới mỗi ngày).
- [x] **M3.3:** `EventsConfig.luau`, `LiveOpsService.luau` (5 Sự kiện toàn Server mỗi 30 phút tặng kèm Potion + 2 Bảng xếp hạng `SurfaceGui` Top Strength & Top Gold tại Đảo 1), `TutorialController.luau` (hướng dẫn 4 bước tân thủ & báo hiệu đủ tiền mở Đảo mới).
- [x] **M3.4:** Hoàn thiện hiệu ứng âm thanh, tab mua 4 gói Gamepass, bộ chắn chống spam RemoteEvent tại `Net.luau` và kiểm định tổng thể PASS 6/6.

---

## Đang làm dở [~]
- *(Không có — đã hoàn thành trọn gói M1.1 → M3.4 trong ca chạy đêm).*

## Bước tiếp theo dành cho Chủ dự án khi thức dậy [ ]
- [ ] Mở Roblox Studio → **File → Open from File...** → chọn `D:\Projects\mighty-angler\build\mighty-angler-dev.rbxlx` (hoặc chạy `run.bat`) → bấm **Play (F5)** để trải nghiệm & dùng nút **`🛠️ [DEV]`** góc phải trên màn hình test nhanh toàn bộ 5 Đảo, Boss, Pet, Rebirth và Server Event.
- [ ] Trước khi Publish chính thức lên Roblox: điền `ROBLOX_GROUP_ID` thật vào `src/shared/Config/GameConfig.luau` và 4 mã `id` Gamepass thật vào `src/shared/Config/GamepassesConfig.luau`.
