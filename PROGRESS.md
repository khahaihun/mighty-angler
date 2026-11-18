# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 16:31 bởi Codex
- **Trạng thái hiện tại:** Codex đã tiếp nhận vai trò Kỹ sư trưởng và ban hành kế hoạch cho Antigravity. **Chưa duyệt phát hành.** Có 23 mục chờ sửa, 21 mục đã đạt theo mã cần kiểm lại trên bản ứng viên. [Kế hoạch chỉ đạo V3](docs/superpowers/plans/2026-11-18-action-blueprint-v3.md) · [Biên bản V3](docs/CODEX_CODE_AUDIT_V3.md)

## Bàn giao chỉ đạo thi công sau V3

- [x] Đối chiếu mốc bổ nhiệm `76916a6` với mã game đã kiểm toán ở `8227545`. Ban hành bảng giao việc cho 6 mã Argon và 17 mã Codex, kèm phép thử và người ký. Tài liệu của ca gồm kế hoạch chỉ đạo V3 và `PROGRESS.md`.
- [x] Chốt tách kho hồ sơ và cả hai bảng điểm trước khi thử ghi. Với cân nặng, giao khôi phục cách tính trước hotfix cho lượt không có Titan Line và giữ trần theo `PLAN.md` cho lượt có Titan.
- [x] Đối chiếu bằng danh sách mã trong biên bản V3, đủ 23/23 mã và mỗi mã có một đầu việc chính. Kiểm các liên kết bàn giao. Chạy lại `tools/verify_project.ps1` trên bản sao của nguồn và cấu hình hiện tại, **PASS 6/6, exit 0**. Đếm độc lập 88 file mã game, dài nhất 342 dòng, cả năm file cam kết đều < 310 dòng.
- [ ] Antigravity bắt đầu Đợt 1 (7 mã) với kho thử riêng. Nộp kết quả hai server và bằng chứng vào lại đúng tiến độ sau Bounty. Đợt 2 (10 mã) kiểm vòng câu và Index. Đợt 3 (6 mã) kiểm quyền mua, xác suất và hiển thị.
- [ ] Chờ kết quả chạy thực tế của bản vá trong Studio, trên hai server và trên điện thoại. Codex duyệt từng đợt và ký đúng bản place có đủ bằng chứng.

## Bàn giao tái kiểm toán V3

- [x] Chạy độc lập `tools/verify_project.ps1` đạt 6/6. Đếm 88/88 file nguồn ≤ 350 dòng, năm file cam kết đều < 310. Đối chiếu 88/88 script trong place đã build với nội dung `src/`.
- [x] Đối chiếu đủ 18 mục Argon và 26 mục Codex với mã tại `8227545`, ghi kết quả và bằng chứng vào `docs/CODEX_CODE_AUDIT_V3.md`. Hai tài liệu của ca này là biên bản V3 và `PROGRESS.md`.
- [ ] Ưu tiên bảo vệ lần lưu cuối, thống nhất thời hạn khóa và cách ly hồ sơ sai kiểu. Kiểm tiếp Auto bị kẹt, Index của người mới, xác suất hiển thị và quyền lợi gói Pet theo danh sách V3.
- [ ] Sau bản sửa, thử hai server trên kho dữ liệu riêng, rồi kiểm Roblox Studio với hai client, ping 200 ms và thiết bị cảm ứng. Kết quả chạy thực tế các trường hợp này còn chờ nghiệm thu.

## Bàn giao Hotfix Vòng Cuối (Xử lý 100% Audit Codex + Argon) [x]

- [x] **Nhóm P0 — Toàn vẹn dữ liệu DataStore, Bảo vệ Trophy, PolicyService & Chống Exploit Tọa độ:**
  - `DataStoreLockHelper.luau` + `DataService.luau` (`Codex P0-01, P0-02, P1-01, P1-04, P2-06` + `Argon P0-3`): Hàng chờ tuần tự theo `UserId` (`WithUserLock`), mã phiên độc nhất từng lượt vào (`SERVER_JOB_ID .. "_" .. uid`), đối chiếu `lastWriteNonce` từ giá trị trả về của `UpdateAsync` (tuyệt đối không gán cờ ngoài trong callback), kiểm tra chặt `type(oldData) == "table" and oldData.activeSessionId == myToken and saveSeq <= expectedSeq`, tự động nhả khóa nếu người chơi thoát giữa lúc tải, chuyển sang `readOnlyPlayers` ngay khi `LostLock` hoặc quá hạn khóa, khóa giao dịch trước `BindToClose` song song (có gộp chung `closingPlayers` với `PlayerRemoving` + retry lỗi tạm), gửi bù `PushFullSnapshot` khi tải trễ `> 8s` (`clientRequestedInit`), giữ nguyên `saveSeq` khi `[DEV] Reset Save` và tách kho `_StudioDev` khi test Studio.
  - `LiveOpsService.luau` (`Codex P1-02` + `Argon P0-1`): Chặn tuyệt đối ghi điểm lên `OrderedDataStore` khi `!DataService.CanWritePersistent(p)`, đồng thời dùng `UpdateAsync` với `math.max` để không bao giờ ghi đè `0` điểm lên kỷ lục Bảng Xếp Hạng Toàn Cầu.
  - `PerkService.luau` + `PetsService.luau` (`Codex P1-13` + `Argon P0-2`): Chuyển `PolicyService` sang 3 trạng thái fail-closed (`"Loading" | "Allowed" | "Restricted"`), chặn quay ngẫu nhiên trả phí cả khi đang tải lẫn khi bị hạn chế ở **cả 2 luồng** `RollEnchant` (Gems) và `HatchEgg` (Trứng Gems), phản ánh rõ trạng thái lên nút UI.
  - `EnchantAndBountyService.luau` + `EnchantAndBountyModal.luau` (`Codex P0-03, P1-06` + `Argon P1-3, P1-7`): Bắt buộc chọn đích danh `bossFishUid` khi đổi `RelicTrident` và từ chối tuyệt đối cá `locked` hoặc `soulbound`; kiểm tra khoảng cách thực tế (`<= 28` studs) tới đúng tọa độ NPC *Old Man Finn*, *Master Kaito* hoặc Bệ *Enchant Altar*; bảng Bounty ưu tiên cá thường mở khóa giá thấp nhất trước, có nút xoay chọn từng `uid` và cảnh báo cam `⚠️ CONSUMES TROPHY`.
  - `FishingRoller.luau` + `FishingService.luau` + `WorldBuilder.luau` (`Codex P1-08, P1-09` + `Argon P0-4, P1-4`): Đặt `CanQuery = false` cho 3 tường vô hình `OceanBoundS/W/E`; kiểm tra `IsFiniteVector3` + cự ly hợp lệ khi nảy đất; Raycast 3D đường quăng + tia thẳng đứng trên Server chặn xuyên mặt cầu gỗ; bỏ hoàn toàn tự động `PivotTo` dịch chuyển nhân vật khi quăng hụt; xác thực thời gian giữ chuột (`FishingChargeStart` >= `0.55s`) và hồi chiêu quăng lại phía Server (`nextAllowedAutoCastAt` + `autoFishActive`).

- [x] **Nhóm P1 & P2 — Minh bạch Xác suất, Virtualized `ViewportPool`, R15 NPC/Rig, `Appraise` & Polish:**
  - `ProfileMigrator.luau` (`Codex P1-03`): Kiểm tra cấu trúc dữ liệu & cách ly an toàn bản lưu hỏng hoặc `dataVersion > 2` (nhả khóa mà không ghi đè), tách riêng hàm sang ngày UTC `RefreshUtcPlaytimeIfNewDay`.
  - `TrophyHelper.luau` + `ProgressPanel.luau` + `CurrencyService.luau` (`Codex P1-05` + `Argon P2-1`): Dùng chung một thuật toán chọn 12 cá `Soulbound Trophy` (`soulbound` ưu tiên trước -> `originalValue DESC -> weight DESC -> uid ASC`) cho cả Server và UI Rebirth, khóa cứng cá `soulbound` không bị bỏ khóa nhầm, khung xem trước `AutomaticSize.Y` kèm dòng cảnh báo rõ các cá khóa vượt mốc 12 sẽ bị xóa.
  - `EnchantAndBountyService.luau` + `ClientStateController.luau` + `FishingRoller.luau` + `RodsConfig.luau` (`Argon P1-2, P2-2` + `Codex P1-07, P2-01, P2-02, P2-03`): Giữ nguyên không bao giờ hạ bậc `sizeTier` khi `Appraise`, tính sàn `85%` làm tròn lên (`math.ceil`), đồng bộ ngay `indexFish` qua `AppraiseResult`; kẹp đúng trần cân `effMaxWeight * 1.25` làm tròn xuống `0.1 kg` cho `titan_line`; công thức `RelicTrident` trên nền `Twig` ra đúng `17 kg`; chụp cứng `strengthMult` tại thời điểm quăng cần.
  - `FishingSessionManager.luau` + `MinigameBar.luau` + `FishingController.luau` (`Codex P1-10, P1-11` + `Argon P1-5`): Kẹp tâm vạch xanh `[0.30, 0.82]`, khớp hằng số `PLAN.md` (`0.08s / 0.45s` & biên `0.05`), kiểm hạn tuyệt đối `serverDeadlineClock` ngay trong `HandleStrike`, Client chờ xác nhận vòng/kết quả từ Server thay vì tự đóng sớm, ẩn nút `✖ REEL IN` khi đang mở Minigame, và tự động tiếp nối nhịp `Auto-Fish` sau khi Đổi đảo / Rebirth / Hồi sinh (tắt sạch khi cất cần hoặc bấm hủy tay).
  - `OddsCalculator.luau` + `HudPanel.luau` + `ShopPanel.luau` + `PetsPanel.luau` + `PromptController.luau` (`Codex P1-12` + `Argon P1-6`): Hiển thị trực tiếp dòng `Base % → Live %` (Rare+, Boss, Xoáy nước `2x`, Đột biến & độ rộng thanh Bar `Rare 28% / Boss 22%`) trên HUD; hiển thị `Base % → Effective %` sau khi loại dòng đang có trên Bệ Enchant; hiển thị đầy đủ tên/bậc/chỉ số/`%` từng Pet trên `PetsPanel` và mở bảng xem trước khi bấm `[E]` ở trụ Trứng ngoài đảo; hộp xem trước đầy đủ 5 chỉ số Cần & `Before vs After` cho cả 5 Gamepass trong `ShopPanel`.
  - `ViewportPool.luau` + `IndexGridSection.luau` (`Codex P1-14` + `Argon P1-1`): Giữ cố định khung `PersistentIndexContainer` xuyên suốt các lần `ProgressionUpdated` và bổ sung **Scroll-Window Virtualization (`+1` hàng đệm)** vào `ViewportPool` để các túi lớn (60 cá, 80 pet, 65 mục Index) luôn chỉ dựng các ô nằm trong khung nhìn.
  - `NpcBuilder.luau` + `WhirlpoolManager.luau` + `ClientPetRenderer.luau` + `PlayerVisuals.luau` + `AnimationController.luau` + `SoundAndFxController.luau` + `NpcDialogueModal.luau` + `HotbarAndCastController.luau` + `TutorialController.luau` (`Codex P1-15, P1-16, P1-17, P2-04, P2-05` + `Argon P1-8, P1-9, P1-10, P2-3, P2-4`): Dựng NPC bằng rig R15 chuẩn (`Humanoid + Animator + Motor6D + WeldConstraint`), bỏ hoàn toàn vòng lặp `Heartbeat` trên Server và chuyển diễn hoạt thở/vẫy tay NPC + bóng cá Whirlpool sang Client theo khoảng cách; chống rò rỉ Pet bằng `charGenByPlayer` + dịch chuyển bằng `PivotTo`; gắn ngang đòn tạ `BenchPress` vào thân & chuẩn hóa tay R6 `-0.95`; hỗ trợ cả `Motor6D`, `AnimationConstraint` và `Animator` track; theo dõi riêng đối tượng `InputObject` khi cảm ứng đa điểm; cân bằng góc `PunchCamera` về `0°`, giữ FOV Minigame khi đóng thoại NPC, tắt hạt ở xa/khi bật `Low GFX`, và cập nhật lời nhắc tân thủ + biển báo cầu cảng khớp cơ chế 2.0.

- [ ] **Chờ tái kiểm toán từ Argon (`docs/ARGON_CODE_AUDIT_V3.md`):** Sau khi Argon ghi biên bản kiểm tra lại bản vá, lịch hẹn tự động sẽ thức dậy kiểm tra và xử lý dứt điểm mọi ghi chú còn lại (nếu có).

---

## Tiến Độ Đại Tu 2.0 (Phase 2 Overhaul) [x]
- [x] **Chặng A (`A1–A3`) — Nước Biển Sóng Thật, Xoáy Nước & Dàn 4 NPC R15 Hội Thoại:**
  - `TerrainWaterBuilder.luau`: Đổ `Terrain:FillBlock` cục bộ từng đảo (không xóa địa hình chung), giữ hộp neo `FishingWater` vô hình (`CanQuery = false`), bổ sung đồi vách đa tầng, ngọn hải đăng Đảo 1, lửa trại, hàng rào dây thừng và Bệ `Enchant Altar`.
  - `WhirlpoolManager.luau`: Xoáy nước sủi bọt + cột sáng + bóng cá bơi vòng, nhân `×2` tổng Luck và `×2` trọng số rớt Boss khi quăng trúng vùng xoáy.
  - `NpcBuilder.luau` & `NpcDialogueModal.luau`: 4 NPC R15 cử động thở/vẫy tay (*Captain Barnaby*, *Master Kaito*, *Old Man Finn*, *Coach Atlas*) + hộp thoại đa lựa chọn an toàn (mở rồi đóng thoại Merchant giữ nguyên 100% túi cá).
- [x] **Chặng B (`B1–B3`) — Session Lock `v2`, Hotbar Cầm Đồ/Khoe Cá, Vật Lý Nảy Đất, 5 Chỉ Số Cần & Exclusive Rod:**
  - `DataService.luau` + `ProfileMigrator.luau`: Khóa độc quyền `activeSessionId == SERVER_JOB_ID`, gia hạn khóa mỗi `60s`, tuần tự `saveInFlight`, chặn giao dịch khi `loadFailedPlayers` + `MigrateProfileToV2` & giữ tối đa 12 `Soulbound Trophies` + Exclusive Rods qua Rebirth (hiện danh sách xem trước trên `ProgressPanel`).
  - `HotbarAndBaitUi.luau` + `HotbarAndCastController.luau` + `FishingSessionManager.luau`: Ẩn Backpack mặc định, Hotbar `1..5` rút cần / cầm cá khoe, chọn mồi nhanh góc dưới phải, nút Auto ngay trên Hotbar, nạp thanh `Cast Power` (4 chế độ Manual / Perfect / Auto Free / Auto Pro), Raycast nảy đất/cầu gỗ, dấu `❗` + Camera zoom nhẹ & chấm điểm Minigame `FishingMinigameStrike` đối chiếu đồng hồ Server (`+0.40s` ân hạn mạng).
  - `RodsConfig.luau` + `EnchantsConfig.luau` + `BountiesConfig.luau` + `EnchantAndBountyService.luau` + `EnchantAndBountyModal.luau`: 5 chỉ số Cần câu, cân bằng lại Kg 5 đảo theo cổng kép (`Power` + `Max Weight`), 3 Cần Exclusive (`115% / 122% / 130%`) & xoay 6 dòng Enchant công khai `%` + `PolicyService`.
- [x] **Chặng C (`C1–C3`) — Lưới Thẻ 3D `ViewportPool`, Khóa Cá, Bán Chọn Lọc, Appraise & Fish Bounty:**
  - `ViewportPool.luau` + `ViewportCard.luau`: Tái sử dụng ô lưới thẻ vuông 3D mượt trên mobile cho toàn bộ `BagPanel`, `ShopPanel`, `PetsPanel` và `IndexGridSection` (bóng đen Silhouette cho loài chưa mở, chỉ xoay 1 thẻ đang chọn, dừng 100% khi đóng cửa sổ).
  - `BagPanel.luau` + `CurrencyService.luau`: Hỗ trợ `🔒 Lock/Unlock`, thanh ghim nhanh Hotbar `Slot 2..5`, chế độ `☑️ Multi-Select` bán nhiều cá một lúc, `Sell Held Fish`, và bảo vệ tuyệt đối cá `Soulbound Trophy` ở cả 4 luồng bán Gold.
  - `PlaytimeAndSettingsModal.luau` + `EnchantAndBountyService.luau`: Quà Online 9 mốc cộng dồn theo ngày UTC, `Appraise` nâng bậc kích thước/đột biến (sàn cân `0.85x`), `Fish Bounty` tiêu `uid` nguyên tử và bảng `Settings` (`Auto-Lock`, `Low GFX`, `Mute SFX`).
- [x] **Chặng D (`D1–D3`) — Mô Hình 3D Chi Tiết Cao, `ClientPetRenderer`, Đập Trứng, Rank Aura & Âm Thanh:**
  - `FishModelBuilder.luau`, `PetModelBuilder.luau`, `RodAndWeightBuilder.luau`: 5 họ cá 3D giải phẫu riêng (*Sleek, Billfish, Manta, Shark, Leviathan*), 6 dòng Pet Chibi mắt long lanh má hồng, 3 Cần Exclusive phát sáng đặc trưng (*Đinh ba 3 mũi, Lưỡi hái Hư không, Đôi cánh Rồng Seraphim*) và quả tạ đôi / đòn tạ 3D.
  - `ClientPetRenderer.luau`: Chuyển toàn bộ diễn hoạt bay của Pet sang Client (`EquippedPetIds` Attribute), tự động giảm nhịp với người chơi ở xa hoặc khi bật `Low GFX`.
  - `PlayerVisuals.luau`, `RanksConfig.luau` & `EggHatchCutscene.luau`: 10 Danh hiệu Overhead Rank Title + vòng hào quang `Aura` theo mốc Strength/Rebirth, cầm tạ 3D thật trên tay khi tập Gym, và diễn hoạt Đập Trứng nứt vỏ nổ sáng có nút `SKIP`.
  - `AnimationController.luau`, `SoundConfig.luau` & `SoundAndFxController.luau`: Tư thế toàn thân (nghiêng hông lấy đà quăng cần, giật cần, giơ 2 tay bế cá khoe hàng, cuốn tạ/đẩy tạ) + nhạc nền sóng biển nhẹ nhàng & SFX nảy đất/câu cá.
  - Kỷ luật dung lượng file: Cả 5 file từng sát trần đều đã hạ xuống `< 310` dòng (`HudPanel: 260`, `ProgressPanel: 274`, `PetsService: 289`, `FishingService: 301`, `BagPanel: 307`).

---

## Hội Nghị Phản Biện & Chốt Thiết Kế Giữa Antigravity ↔ Codex [x]
- [x] **Vòng 1 (`docs/REVIEW_DAI_TU_2.0.md`):** Codex đối chiếu kế hoạch với 62 file `.luau` thật trong `src/`, chỉ ra 3 điểm nghẽn lớn (giữ câu cá xuyên suốt cả 5 đảo ngay khi thay `Terrain Water` ở A1, tương quan `Max Weight` vs `minRodPower` 5 đảo, và số phận cá khóa + Exclusive Rod khi Rebirth).
- [x] **Vòng 2 & 3 (`docs/DEBATE_ROUND_2.md`, `docs/CODEX_ROUND_2_REPLY.md`, `docs/CODEX_FINAL_VERDICT.md`):** Hai AI tranh luận và chốt hạ giải pháp cho:
  1. **P0 DataStore Session Lock:** Chỉ cho phép ghi khi `activeSessionId == SERVER_JOB_ID`, gia hạn khóa mỗi `60s`, chờ `saveInFlight` trước khi nhả khóa lúc đổi server, khóa giao dịch nếu thử 3 lần không lấy được khóa.
  2. **P1 A (`Soulbound Trophy` qua Rebirth):** Giữ tối đa 12 cá khóa xếp theo `originalValue` (không mất ở các lần Rebirth sau), chặn ở mọi luồng bán Gold ngay trước khi xóa khỏi túi, vẫn cầm khoe trên Hotbar & nộp *Fish Bounty* bình thường; màn hình Rebirth hiện rõ danh sách 12 Trophy & ô ghim.
  3. **P1 B (Minigame chống gian lận không sợ ping cao):** Chấm từng vòng `FishingMinigameStrike` bằng sóng tam giác tất định đối chiếu đồng hồ Server + tách hạn bấm (`7.5s / 9.5s / 11.5s`) khỏi hạn nhận gói (`+0.40s` ân hạn mạng).
  4. **Hiệu năng Mobile & Trần 350 dòng:** `ClientPetRenderer` diễn hoạt Pet trên Client, `ViewportPool` tái sử dụng thẻ 3D không dựng lại toàn lưới khi nhảy tiền, và tách trước 5 file đang sát trần (`331–336` dòng) xuống `< 310` dòng.
- [x] **Vòng 4 (`docs/CODEX_CONSENSUS_STAMP.md`):** Codex xác nhận **`ĐỒNG THUẬN CHỐT PLAN.md`** (0 lỗi P0/P1/P2 tồn đọng).

## Bước đã thực hiện sau hội nghị [x]
- [x] Antigravity đã triển khai **Chặng A → Chặng B → Chặng C → Chặng D**. Công việc tiếp theo được ghi ở phần bàn giao kiểm toán đầu file.

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
