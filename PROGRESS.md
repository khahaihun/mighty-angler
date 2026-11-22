# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-22 bởi Devin (Bước 1 của kế hoạch sửa sau review toàn dự án)
- **Trạng thái hiện tại:** Trên nền Chặng 1 + 2A (`975ab86`), đã sửa **Bước 1: an toàn Gamepass và vòng tự lưu** ở nhánh riêng tách từ `codex/studio-data-isolation`. **103/103** file `.luau` trong `src/` đều `≤ 350` dòng (dài nhất `ViewportCard.luau` 345; `PerkService` 343). **16/16** runner `tools/test_*.ps1` đạt `exit 0`; Luau LSP, Selene, Rojo build đạt; Source XML khớp **103/103** (SHA-256 `A46691181ABDE7BA16E7E2C73493126A1DB9EC60BF2754C8EF7FFF5B21441C4A`). **Vẫn CHƯA duyệt phát hành; Play Solo (F5), 2 Client ping 200ms, 2 Server Staging, điện thoại thật và ID Gamepass/Group thật đang chờ Chủ dự án.**

## Bước 1 sau review — Gamepass chỉ cấp khi Roblox xác nhận, vòng tự lưu không chết vì một lỗi (Devin, 22/11/2026)

- [x] **Tín hiệu "mua xong" không còn được tin thẳng.** `PerkService` chỉ cấp pass sau khi `UserOwnsGamePassAsync` trả `true`. Pass có `id = 0` không bao giờ khớp, kể cả khi tín hiệu mang ID 0 (trước đây một tín hiệu ID 0 mở cả 5 pass). Tín hiệu lặp lại không nhân số lần hỏi Roblox và chỉ báo "Unlocked" một lần.
- [x] **Roblox lỗi mạng không còn làm người mua mất quyền cả phiên.** Module mới `GamepassOwnership.luau` phân biệt `Owned / NotOwned / Unknown`: thử 3 lần liền, nếu vẫn lỗi thì hỏi lại ở nền theo lịch 15/30/60/60/120/120 giây cho tới khi có câu trả lời hoặc người chơi rời. Lỗi API không bao giờ được hiểu là "đã mua". Kiểm tra thành viên Group cũng không nhớ kết quả lỗi, hỏi lại sau 30 giây; khi Roblox hồi phục và xác nhận là thành viên, server gửi lại quyền để nút Auto-Train trên máy người chơi khớp server (sửa theo Devin Review).
- [x] **Vòng tự lưu:** `Persistence.Tick()` trong `DataService` được bọc `pcall` và ghi cảnh báo; một lỗi trong nhịp lưu không còn dừng tự lưu/gia hạn khoá của cả server.
- [x] **Test mới:** `tools/test_gamepass_ownership.ps1` **8/8** (tín hiệu giả ID 0, tín hiệu giả cho pass thật, huỷ prompt, mua thật, mua lúc Roblox lỗi, chủ pass vào game lúc Roblox lỗi, rời giữa chừng, Group lỗi rồi hồi phục); trên mã cũ bộ này đỏ 6/8. `profile_schema` thêm 1 ca tick lỗi 3 lần vẫn lưu và giữ khoá (**30/30**; đỏ trên mã cũ).
- [x] **Kiểm định (Linux, lệnh tương đương `verify_project.ps1`):** Rojo sourcemap, Luau LSP `exit 0`, Selene 0 lỗi/0 cảnh báo, Rojo build, 16/16 runner `exit 0`, `git diff --check` đạt.
- [ ] **Chờ nghiệm thu:** mua pass thật/mô phỏng trong Studio và trên server thật. Bộ test giả lập `MarketplaceService`; hành vi cache của `UserOwnsGamePassAsync` sau khi mua lấy theo tài liệu Roblox, chưa kiểm trên Engine. CI vẫn chưa chạy runner mới (thuộc Bước 4).

## Ca đêm 22/11/2026 — Hoàn tất Chặng 1 & Chặng 2A (Sunny Shores Pilot Prep)

- [x] **Mốc nền tài liệu (`ee3ded5`):** Ghi chốt [Kế hoạch Mỹ thuật & Nâng cấp](docs/ART_DIRECTION_AND_REBUILD_PLAN.md) và đồng bộ mốc hiện trạng thực tế trong `AGENTS.md` + `PLAN.md`.
- [x] **Chặng 1 — Catalog đề xuất Asset 0 đồng cho Sunny Shores (`73837ce`):** Lập xong [SUNNY_SHORES_ASSET_CATALOG.md](docs/SUNNY_SHORES_ASSET_CATALOG.md) phủ đủ 7 nhóm (cây cối/đạo cụ, cầu tàu/quầy/hải đăng/bệ Enchant/cổng đảo, 4 NPC R15, 7 loài cá, 2 mẫu trứng + 8 pet, 3 máy Gym, cần câu đầu) từ nguồn miễn phí `0đ` an toàn (`Quaternius CC0`, `Kenney.nl CC0`, `KayKit CC0`, `Poly Pizza`, `Roblox × Synty Official ID 6933438443` + `R15 Rig Builder`), có hộp tích duyệt từng món, gợi ý Combo 3 gói nhanh nhất và quy tắc lọc sạch 100% Script ẩn. Chưa đưa bất kỳ asset nào vào `ReplicatedStorage.Assets`.
- [x] **Chặng 2A-1 — Nâng cấp Ổ cắm 3D & Chế độ Terrain dựng tay (`c6b76a2`):**
  - `AssetRegistry.luau`: mở rộng đủ 9 thư mục (thêm `Eggs`, `Npcs`, `Buildings`), tự động lọc bỏ 100% `LuaSourceContainer` ẩn trong model clone, hỗ trợ `RootOnly` cho NPC R15, thêm `ApplyModelVisuals` (giữ `Silhouette` tối màu & `Highlight` + `ParticleEmitter` gắn `ClientBudgetManaged = true` cho đột biến `Shiny/Golden/Cosmic` trên MeshPart), `ScaleModelUniform` (`Model:ScaleTo()` + fallback) và `NormalizeForViewport`.
  - `NpcBuilder.luau`, `FishModelBuilder.luau`, `PetModelBuilder.luau`, `RodAndWeightBuilder.luau`, `EggHatchCutscene.luau`, `ViewportCard.luau`, `PropsBuilder.luau`, `TerrainWaterBuilder.luau`: sửa lỗi khóa cứng khớp NPC 3D (`RootOnly`), nối 3D override cho Trứng (bệ ngoài đảo + thẻ UI + cutscene đập trứng xoay `PivotTo`), nối 3D override cho Shop Rod Preview, thêm vòng hào quang/vương miện mặc định cho Pet & Trứng Exclusive.
  - `ManualIslandAdapter.luau` + `WorldBuilder.luau` + `tools/generate_sunny_shores_terrain_draft.luau`: nhận diện đảo Terrain dựng tay tại `Workspace/MightyWorldManual/Island_<id>` cùng 16 điểm neo `IslandMarkers` (tự ẩn marker khi chạy thật, giữ nguyên địa hình Terrain + tạo hộp `FishingWater` vô hình đúng kích thước), kèm script Command Bar 1-click tạo phôi đảo Sunny Shores Terrain trong Studio.
  - Bộ test VM mới `tools/test_art_pipeline_and_terrain.ps1`: **24/24 PASS (`exit 0`)**.
- [x] **Chặng 2A-2 — Cơ cấu 6 Trứng / 24 Pet & Exclusive Pet Scaling (`7f526ea`):**
  - `PetsConfig.luau` + `Types.luau` + `Island2..5` + `init.server.luau` + `WorldBuilder.luau`: chuyển sang **5 Trứng Gold theo đảo × 4 pet thường (`55% / 28% / 13% / 4%`) + 1 Trụ Trứng Gem Exclusive duy nhất đặt ở Hub Đảo 1 × 4 Pet Exclusive (`60% / 27% / 10% / 3%`, scale `100% / 115% / 130% / 150%` theo con Pet thường khỏe nhất đang sở hữu + sàn tối thiểu cho người mới + chống scale vòng tròn)**. Giữ nguyên `pet_tiki_spirit` (+10% Mutation), bảng ánh xạ ngược `LEGACY_PET_ALIASES` cho hồ sơ cũ và `PetsConfig.GetBossDropPool(islandId)` an toàn cho cả 5 đảo.
  - `PetsService.luau` (`301 < 310` dòng), `OddsCalculator.luau`, `PetsPanel.luau`, `EggHatchCutscene.luau`: dùng chung `PetsConfig.GetEffectivePetStats` & `GetEffectivePowerScore` để Server `BuffAggregator`, `EquipBest`, `Live Odds` và thẻ UI khớp nhau 100%, giữ chặt `PolicyService` cho Trứng Gem Exclusive.
  - Bộ test VM mới `tools/test_exclusive_pet_scaling.ps1`: **47/47 PASS (`exit 0`)**.
- [x] **Kiểm định tổng thể sau cả 2 đợt:** `tools/verify_project.ps1` **PASS 6/6**, **15/15** runner `tools/test_*.ps1` đạt **`exit 0`** (gồm `test_live_odds` 19.200 rổ, `test_paid_random_transactions`, `test_v3_regression`, `test_studio_data_isolation`, `test_place_sources` 102/102 Source XML parity).
- [ ] **Việc sáng mai Chủ dự án quyết & chạy thật:**
  1. Mở [SUNNY_SHORES_ASSET_CATALOG.md](docs/SUNNY_SHORES_ASSET_CATALOG.md) tích duyệt những gói Asset `0đ` bạn ưng (gợi ý Combo 3 gói: Quaternius + Kenney + Roblox Official).
  2. Mở `build/mighty-angler-dev.rbxlx` trong Roblox Studio — có thể dán chạy thử `tools/generate_sunny_shores_terrain_draft.luau` trong Command Bar để xem phôi đảo Terrain cong tự nhiên + bấm **Play (F5)** trải nghiệm bệ Trứng Exclusive Đảo 1 & checklist V3.
  3. Hoàn thành 4 cột mốc nghiệm thu thật còn treo của V3: Play Solo (F5), 2 Client ping 200ms, 2 Server Staging tách Production và điện thoại thật.

---

## Mốc lịch sử trước đó (Bàn giao ứng viên V3 ngày 18/11/2026 bởi Codex)

- **Trạng thái lịch sử mốc `dd53d3a` / `20218b8`:** Bản ứng viên hợp nhất đến hết 1.5 (`8699970`) cùng gameplay/UI/odds; 13/13 runner mặc định exit 0, verify 6/6, Source 101/101. Xem [bàn giao cuối](docs/V3_BAN_GIAO_NGHIEM_THU.md) và [matrix21](docs/V3_REGRESSION_MATRIX.md).

## Mục 1.5 — Một snapshot mỗi yêu cầu và cảnh báo quyền ghi

- [x] Nền `99216b5` sạch, giữ các commit trước. Thực hiện riêng mục cuối Đợt 1 theo chỉ đạo; không sửa nguồn copy trong build hay chuyển sang Đợt 2. Bộ init trước sửa tái hiện 7/8 ca đỏ (`logs/phase15-red.log`).
- [x] Bỏ hai nơi cạnh tranh chờ 8 giây/gửi snapshot. DataService giữ số yêu cầu khởi tạo đang chờ; một đường flush khi profile sẵn sàng, lấy/xóa pending trước khi gửi. Mỗi yêu cầu nhận đúng một snapshot đầy đủ; nhiều yêu cầu vẫn một phản hồi mỗi yêu cầu, người đã rời bị loại. Không dùng snapshot mặc định giữa chừng để thay tiến độ chưa tải.
- [x] Thêm `ProfileAccessChanged` vào manifest Net chung, mang safeReadOnly/loading/accessVersion. Profile/lease/status đều do server quyết định; thông báo trạng thái nhỏ tách khỏi snapshot đầy đủ nên mất quyền không gửi lại init. Phiên có số phiên bản trạng thái tăng dần, chỉ phát khi state đổi; cache sau khi gửi thành công để lỗi gửi không mất cơ hội thử lại.
- [x] **Ba ca review scheduler đều đạt qua điểm vào thật, không cần click/Save thủ công:** hết TTL khi đứng yên; background Persistence.Tick mất chủ; RuntimeTick lỗi rồi bị cách ly. Publish ở ngoài nhánh skip s.readOnly, có pcall riêng theo người; trạng thái không đổi không bị phát mỗi giây. Thêm ca lần gửi access lỗi rồi kỳ sau thử lại thành công.
- [x] ClientStateController nhận cờ từ snapshot và remote trạng thái. HUD dùng component `ProfileAccessBanner` riêng: thông báo tiếng Anh Loading/READ-ONLY, không bị dòng buff/sự kiện ghi đè; phiên bản cũ không xóa cảnh báo mới hoặc đảo kết quả phục hồi. Ready tới trước snapshot đầu tiên vẫn giữ Loading tới khi nhận đủ profile. Component tự tăng chiều cao khi wrap; bố cục/đọc trên thiết bị thật còn chờ nghiệm thu.
- [x] `initial_state` **13/13**: trước/sát/sau 8s (7,9/8/8,1), hai yêu cầu đang chờ, vào muộn bị read-only, đủ Gold/Gems/rod/bag/pin/quyền ghi, mất chủ, chặn SpendGold và ghi bảng điểm bằng DataService/LiveOps thật, rời lúc chờ, ba ca idle scheduler, thứ tự UI/phiên bản và lỗi gửi access. Toàn bộ bộ chung **exit 0**, các bộ cũ đều giữ xanh (`logs/phase15-final.log`).
- [x] TDD bổ sung có log đỏ riêng cho idle TTL, ready trước dữ liệu và gửi access lỗi: `phase15-passive-red.log`, `phase15-ready-red.log`, `phase15-delivery-red.log`. Mỗi lỗi được sửa một vòng; không có lỗi chưa giải quyết quá hai vòng. Fixture giữ bản sao payload qua biên, hỗ trợ nhiều listener như RemoteEvent và ghi trace key/UserId/version/cảnh báo để review không suy từ PASS đơn thuần.
- [x] `powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1` **PASS 6/6, exit 0** (`logs/phase15-verify.log`). Đây chỉ là kiểm định tự động, không thay quyết định nghiệm thu hay phát hành.
- [x] **92/92** file mã game ≤350. HudPanel **274**, PetsService **298**, ProgressPanel **268**, BagPanel **307**, FishingService **282** đều <310; DataService **223**, Persistence **247**, banner **40**. `git diff --check` đạt.
- [x] Dùng sourcemap và full instance path đối chiếu **92/92** Source trong `build/mighty-angler-dev.rbxlx` với nguồn, chuẩn hóa xuống dòng (`logs/phase15-place-source.log`). SHA-256 **`1364691FDB4B8FD30E00C09691BE48977BDE916D4AFE9BAD1A2C38A9A622EDA2`**. Không sửa Source trong place; chỉ build từ nguồn và đọc để đối chiếu.

**Lệnh tái chạy cuối Đợt 1:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# all suites PASS, exit 0
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1 -Suite initial_state
# INITIAL_SUITE passed=13 failed=0
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# PASS 6/6, exit 0
```

- [~] Dừng tại cuối 1.5 để Kỹ sư trưởng tích hợp/review. Chuỗi đã lưu: **bbce374 (1.3)** → **d139bbf (vá slot 0)** → **aba687a (1.4)** → **99216b5 (vá lease Reset)** → commit chứa mục 1.5 này. Không có thay đổi gameplay Đợt 2/3 trong ca này.
- [ ] Play Solo (F5), Server & Clients, hai server Roblox trên experience thử có sẵn, điện thoại và staging: **chờ nghiệm thu**. Không có phiên Studio/experience thử kết nối trong ca này, không bật API sản xuất hoặc publish. Cả Codex P1-03/P2-06/P1-04 và Argon P0-3 cần Kỹ sư trưởng review và bằng chứng Engine trước ký cuối.

## Mục 1.4 — Reset cùng hàng đợi, kết quả RAM và lưu bền

- [x] **Vá review lease Reset:** không dùng riêng cờ readOnly để suy ra quyền ghi. Dùng cùng phép kiểm lease từ confirmedAt+TTL tại lúc nhận, sau khi vào hàng đợi và ngay trước đổi candidate; bỏ qua cờ resetting của chính thao tác, RAM-only vẫn hợp lệ. Bốn ca mới (hết hạn trước/trong hàng đợi, có/không chủ B) đỏ trước sửa, nay Reset **12/12**; giữ nguyên RAM/số dư/kho/seq/chủ B, không thêm ghi. Bộ chung exit 0 và verify 6/6 exit 0 (`logs/reset-lease-red.log`, `logs/reset-lease-final.log`, `logs/reset-lease-verify.log`).

- [x] Nền gồm `bbce374` và vá review `d139bbf`; tiếp tục không dừng theo giao việc. Tái hiện 6 ca Reset đỏ trước sửa (`logs/phase14-red.log`).
- [x] Persistence.Reset khóa giao dịch và chặn Reset đồng thời; trong hàng đợi UserId, xác nhận pending write trước khi đổi đối tượng, lấy seq mới nhất rồi chụp bản mặc định thành một thao tác ghi cố định. Không xác nhận được thao tác trước thì không đổi RAM. Đóng phiên trong lúc đợi thì hủy Reset, không cài lại người đã rời.
- [x] Mỗi bước xác nhận/ghi Reset thử tối đa ba lần; giữ pending thao tác chưa chắc chắn để tự lưu tiếp khi API hồi phục. RAM-only không mở kho; phản hồi Saved/RAMOnly/Unconfirmed/Busy/NotApplied tách khỏi cờ ramApplied, không báo Success nếu chỉ đổi RAM hoặc chưa xác nhận ghi.
- [x] DataService trả cả profile và trạng thái; DevTestService bỏ lần SaveProfile dư, phát kết quả riêng qua payload Toast hiện có. Bảng DEV thêm hai dòng RAM/Persistent, không tạo Remote ngoài manifest. Hình thức/bố trí thật trong Studio vẫn chờ nghiệm thu; test client kiểm handler và thuộc tính Text của module thật ở biên UI giả lập.
- [x] `dev_reset` **8/8**: autosave chờ trước thay đối tượng, lỗi ghi sau thay RAM, RAM-only, pending cũ chưa rõ thì không thay, Reset đồng thời, trạng thái bảng DEV, rời lúc chờ và mất phản hồi. `data_persistence` **7/7**, ca Reset chuyển xanh; 19/19 acquisition, 12/12 lifecycle, 29/29 schema và cách ly đều đạt. Bộ chung **exit 0** (`logs/phase14-final.log`).
- [x] Verify **6/6, exit 0** (`logs/phase14-verify.log`). Một lỗi nullable candidate được LSP phát hiện và sửa một lần bằng biến candidate không optional; log đầu `logs/phase14-verify-first.log`. Không có lỗi quá hai vòng. Mọi file mã game ≤350; năm file cam kết không đổi, <310.
- [x] Sửa Persistence/DataService/DevTestService/DevTestPanel, thêm fixture client/test Reset và runner. Không sửa bản copy nguồn trong build, không API thật/publish. Studio/hai server/điện thoại/staging **chờ nghiệm thu**.
- [x] 91/91 file mã game ≤350; build SHA-256 `44E6116E651E1A5DCADCA1EB7FD5090EEFB837D5B8D733360F28FC8559A1AFD8` sinh bằng verify, chưa Play Studio.
- [~] Commit riêng mục này chứa bàn giao; tiếp ngay 1.5. Phần code Reset của Argon P0-3 nay có bằng chứng mô phỏng cùng mục 1.2; vẫn cần review và Engine trước ký nghiệm thu.

## Mục 1.3 — Xác thực hồ sơ và cô lập scheduler

- [x] **Vá review sentinel slot 0:** ShopAndItemsService.SetHotbarSlot thực tế dùng 0 để cất cần. Đã tái hiện validator từ chối lưu hồ sơ hợp lệ, sửa miền 0..5; ca nguồn thật SetHotbarSlot → SpendGold → Save/Close → server B giữ slot 0, Gold 75 và UID túi. V1 slot 0 cũng giữ nguyên; -1/6 vẫn bị cách ly. Schema **29/29**, verify **6/6 exit 0** (`logs/schema-slot0-final.log`, `logs/schema-slot0-verify.log`). Đối chiếu các giá trị ghi thực cho activeBait=nil, gymGear=0, sellValue≥1/Trophy=0, midas≥1 và cấu trúc v1 tại 118e101; không phát hiện sentinel cần sửa thêm. Commit vá chỉ chứa Validator/test schema/PROGRESS. Phép thử Reset 1.4 đang đỏ được giữ ngoài commit vá, tiếp tục ngay theo chỉ đạo.

- [x] Tiếp nhận chỉ đạo Kỹ sư trưởng đã chấp nhận code `0ded6d4` và cho thi công liên tục 1.3–1.5. Nền sạch tại `0ded6d4`; không sửa bản copy trong build. Mỗi mục vẫn commit riêng, nghiệm thu Engine chưa thực hiện.
- [x] Lỗi gốc: reconcile/migration giữ giá trị sai kiểu, dùng ipairs bỏ mục sau lỗ hoặc làm rỗng túi hỏng rồi cho ghi; lỗi một profile dừng vòng scheduler. Đã tái hiện 21 ca đỏ trong `logs/phase13-red.log` trước bản sửa.
- [x] Thêm `ProfileValidator`: kiểm root/version, scalar hữu hạn/không âm, trường hiện diện sai kiểu kể cả v1, map string đúng kiểu, stats/potions/quests/receipt lồng, UID và mảng đặc qua pairs (không bỏ dữ liệu sau lỗ). v1 được thiếu trường mới có mặc định hợp lệ; v2 phải đủ trường; version tương lai cách ly. Không sửa input, không loại vật phẩm lỗi.
- [x] Validate trước reconcile, trước claim chỉnh metadata và trước snapshot ghi. Hồ sơ lỗi/future bị từ chối mà kho nguyên trạng cả nghiệp vụ; rejected callback chỉ dùng báo cách ly khi kho hủy ghi, không làm bằng chứng cấp quyền. Receipt nhả của 1.2 được bảo toàn.
- [x] Scheduler xử lý từng profile bằng pcall và chuyển riêng người lỗi sang chỉ đọc, có cảnh báo. Test lỗi dữ liệu và lỗi biên gửi thông báo của một người vẫn cho người khác gia hạn/lưu/vào lại đúng Gold 81.
- [x] `profile_schema`: **26/26**, gồm v1 di trú hai lần giữ UID/cân/ghim/mở khóa, v2 tốt giữ receipt, v2 sai kiểu/cá thiếu trường, map lồng, mảng thưa/trộn, version tương lai, UTC cùng/ngày mới và scheduler độc lập. **19/19 acquisition**, **12/12 lifecycle** còn đạt. Persistence **6/7**; ca hỏng schema đã xanh, chỉ `dev_reset_during_autosave` (1.4) còn đỏ.
- [x] Lệnh `powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1`: **PASS 6/6, exit 0** (`logs/phase13-verify.log`). Lệnh `powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1`: **exit 1** do duy nhất Reset 1.4 (`logs/phase13-final.log`), không bỏ assertion hoặc che lỗi CI. Mục 1.3 được sửa trong một vòng chức năng, không có lỗi quá hai vòng.
- [x] Sửa DataService/LockHelper/Migrator/Persistence, thêm Validator và test schema; cập nhật fixture/runner. Fixture Bounty nay có đủ cấu trúc CaughtFish như dữ liệu game thật; ca quarantine-yield của 1.1 dùng v1 hợp lệ rồi gây lỗi tạo UID để tiếp tục kiểm đường nhả bất đồng bộ, thay vì nhận khóa một v2 hỏng.
- [x] **91/91** file mã game ≤350, lớn nhất CurrencyService 342; năm file cam kết không đổi, đều <310. Build SHA-256 `2E504438F62DA840172FA1C0F06BD3F71DE4E502A3F569DC5DCD746FFA933355`. Không mở API thật; Studio/Server & Clients/hai server/điện thoại/staging **chờ nghiệm thu**.
- [~] Commit của mục này là commit chứa bàn giao; Kỹ sư trưởng sẽ review sau chuỗi 1.3–1.5. Tiếp ngay 1.4 theo chỉ đạo, rồi 1.5. Không coi mô phỏng là quyết định phát hành.

## Bản ứng viên hợp nhất sơ bộ — Codex, 18/11/2026

- [x] Trong clone `build/v3-regression-sol`, nhánh `codex/v3-combined` từ dữ liệu `0ded6d4`; merge lịch sử `3132629`, fishing `db2387a`, UI `a7bcfc7`. Không sửa checkout gốc, không push. Giữ toàn bộ bàn giao các nhóm; trạng thái đầu file tiếp tục thuộc công nhân dữ liệu tới hết 1.5.
- [x] Chỉnh duy nhất fixture regression thêm `WorldPromptAccess.IsNear` làm biên vị trí hợp lệ thay kiểm tọa độ thiết kế cũ; assertion tiền/UID/Trophy/Appraise/Rebirth/Strength không nới. Logic prompt thật do `test_fishing_wave.ps1` kiểm riêng.
- [x] Chạy sơ bộ cả chín `tools/test*.ps1`: tám runner exit 0; runner dữ liệu chung exit 1, persistence 5/7 với đúng `malformed_profile_is_quarantined` (1.3) và `dev_reset_during_autosave` (1.4). Acquisition 19/19, lifecycle 12/12, regression 23/23. Verify PASS 6/6 exit 0.
- [~] **1.3/1.4 còn đỏ trên `0ded6d4`; 1.5 chưa xong**. Chờ tip cuối Đợt 1, fishing và UI để hợp nhất và chạy lại từ checkout sạch; chưa gọi hoàn thành.
- [ ] Kiểm Source toàn bộ place trên SHA cuối; F5/hai server/hai client/ping/điện thoại còn chờ. Đây chỉ là ứng viên để Kỹ sư trưởng review, chưa duyệt phát hành.
## Bàn giao kiểm thử hồi quy V3 — clone riêng ngày 18/11/2026, Codex

- **Trạng thái:** bản kiểm thử nền `9282aa6` trong `build/v3-regression-sol`, nhánh `codex/v3-regression`; không sửa mã game hoặc checkout chính; chưa ký nghiệm thu 21/21 Engine/phát hành.
- [x] Tạo `tests/v3_regression.luau`, `tests/v3_regression_fixture.luau`, `tools/test_v3_regression.ps1`: **23/23 VM PASS, exit 0**; bốn probe âm trong bộ nhớ đều bắt đúng hồi quy và exit 1; chạy sạch lại 23/23.
- [x] `verify_project.ps1`: **PASS 6/6, exit 0**. Lần đầu thiếu cache Selene, đã copy `roblox.yml` sẵn có từ nguồn rồi chạy lại; không đổi lint/mã game.
- [x] Runner dữ liệu chung: isolation PASS, acquisition 19/19; persistence **3 PASS/4 FAIL**, exit 1, đúng baseline Đợt 1 (`late_save_response_cannot_extend_ownership`, `both_close_paths_wait_for_final_save`, `malformed_profile_is_quarantined`, `dev_reset_during_autosave`). Không nới assertion hoặc sửa suite đó.
- [x] `docs/V3_REGRESSION_MATRIX.md` đủ 21 ID (12 Argon +9 Codex), tách VM/đọc mã/Studio, cách tái chạy bản tích hợp; cập nhật `tests/README.md`.
- [~] Chờ kỹ sư trưởng review/cherry-pick; kiểm lại trên SHA tích hợp khi được giao.
- [ ] Toàn bộ F5, hai client, ping 200ms, hai server thật và điện thoại còn **chờ nghiệm thu**. Trạng thái bàn giao lịch sử phía dưới thuộc checkout nguồn trước ca clone.
- **Lưu ý:** lỗi fixture thiếu tên hook Gym đúng đã sửa một lần và suite đạt; không có lỗi game được sửa quá hai vòng. Không đổi kiến trúc hay quy tắc gameplay.


## Bản vá mục 1.2 — Hạn quyền ghi, gia hạn và lần lưu cuối

### Đã hoàn thành [x]

- [x] Nhận ca trên `codex/studio-data-isolation` tại `0a90644`, cây làm việc sạch. Đọc AGENTS/PLAN/PROGRESS/matrix/blueprint và hai commit `916e5d9` (bộ persistence), `0a90644` (CI). Trong lúc thi công xuất hiện commit tài liệu **`9282aa6`** của ca khác, chỉ sửa AGENTS; đã đọc quy trình kiểm hai tầng/staging mới và giữ nguyên, không đưa vào bản vá này.
- [x] **Lỗi gốc — đọc mã và mô phỏng nền:** thời điểm nhận phản hồi được dùng để kéo dài quyền ghi thay cho dấu giờ lưu trong kho; đóng trùng trả sớm, bỏ kết quả retry và giữ `closingPlayers`; chưa có mã thao tác cố định cho kết quả mơ hồ; autosave dồn cả server cùng nhịp. Bộ nền có 4 ca persistence lỗi: hai lỗi 1.2 và hai lỗi còn lại thuộc 1.3/1.4.
- [x] **Tách module nội bộ, giữ điểm vào gameplay:** `DataService` tiếp tục cung cấp Get/Wait/Save/MarkDirty/Reset/snapshot; `ProfilePersistenceService` giữ trạng thái theo phiên, lease, hàng chờ ghi và đóng; `ProfileWriteHelper` giữ snapshot/nonce bất biến và xác nhận từ kho. Chuyển phần `WriteSnapshotVerified` cũ khỏi LockHelper sang helper mới, không còn caller dùng hàm cũ. Không đổi Remote, gamepass, luật thưởng hay schemaVersion.
- [x] **Hạn quyền ghi:** lấy `lockTimestamp` từ tài liệu claim/ghi được kho xác nhận, không lấy thời điểm trả phản hồi. Giao dịch bị khóa khi tới hạn 120 giây theo dấu giờ đó, kể cả phản hồi chậm. Ghi vẫn kiểm đúng token và saveSeq hiện hành tại UpdateAsync; queued writer kiểm lại trạng thái chỉ đọc sau khi đợi UserId.
- [x] **Kết quả mơ hồ:** mỗi thao tác giữ nguyên snapshot, token, nonce và nextSeq qua các lần retry. UpdateAsync không ghi lại thao tác đã áp dụng. GetAsync với `UseCache=false` đối chiếu token/seq/nonce; không đủ bằng chứng thì TransientError hoặc LostLock, không báo Saved giả. Receipt nhả cuối được giữ để xác nhận A kể cả B đã claim/lưu; không ghi đè B để xác nhận A.
- [x] **Lần lưu cuối:** đặt cờ đóng trước khi chụp snapshot; PlayerRemoving và BindToClose cùng chờ tác vụ theo phiên, kể cả người đã rời Players. Kết quả Saved/Skipped/RAMOnly/Unconfirmed là chung và bất biến; báo cáo shutdown theo token chứa cùng kết quả, không chứa Player. Hạn 25 giây dùng chung, retry lỗi tạm trong hạn; hết hạn ghi cảnh báo gồm UserId/token/seq/nonce/lý do. API trả muộn không cài lại RAM.
- [x] **Đóng nhiều hồ sơ và dọn tham chiếu:** shutdown khóa mọi giao dịch trước khi khởi chạy các tác vụ song song. Một hồ sơ treo không chặn hồ sơ khác. Hoàn tất/hết hạn xóa phiên khỏi registry và nhả player/profile/pending; 30 lượt rời/vào đưa Count về 0 sau mỗi lượt. BindToClose chờ các phiên đang đóng thay vì chỉ đếm người hiện diện.
- [x] **Gia hạn:** chia pha theo UserId trên chu kỳ 60 giây, kể cả hồ sơ không có giao dịch; không tạo nhiều lượt chờ tự lưu cho cùng phiên. Lỗi tạm lên lịch đối chiếu/thử lại sớm, quyền giao dịch vẫn chịu dấu giờ đã xác nhận. Giữ RAM-only chưa publish và `_StudioDev` của mục trước.

| Ca nghiệm thu | Loại bằng chứng | Kết quả thực tế |
|---|---|---|
| Claim/lưu đã ghi, phản hồi chậm 100 giây; kiểm sau giây 120 | Mô phỏng nguồn thật | Không được kéo dài lease từ lúc nhận phản hồi; A không còn quyền ghi sau hạn lưu trong kho. |
| PlayerRemoving đang lưu thì BindToClose chạy | Mô phỏng điểm vào thật | Cả hai chờ; cùng nhận Saved theo token; đúng một snapshot cuối và một lần tăng seq. |
| Lưu cuối lỗi tạm trước ghi rồi thành công | Mô phỏng persistence | Retry snapshot cố định, lưu Gold 731, nhả chủ và seq=2. |
| Đã ghi nhưng mất phản hồi, lần đọc xác nhận đầu cũng lỗi | Mô phỏng lifecycle | Retry cùng thao tác; chỉ đọc để chứng minh, không ghi snapshot lần hai; seq=2, tổng commit=2 kể cả claim. |
| A mất phản hồi nhả, B vào và lưu trước khi A đối chiếu | Hai máy chủ mô phỏng, chung kho RAM | Receipt xác nhận A đã lưu, Gold/owner B giữ nguyên; A không ghi đè B. |
| Autosave trước Bounty đang đợi; tiêu UID, rồi chồng cả hai đường đóng/mất phản hồi cuối | Handler Bounty + DataService thật trong mô phỏng | Autosave rồi đúng một snapshot cuối (seq=3); vào B thấy Gems 45, Relic từ 3→4, một Lucky Elixir; UID tiêu biến mất, UID khác giữ, ô ghim dọn; nộp lại không nhận thêm thưởng. |
| Lỗi đến hết hạn đóng / API treo | Mô phỏng | Trong 25 giây trả Unconfirmed chung cho các đường chờ; có cảnh báo, không báo đã lưu số dư chưa ghi; registry về 0. |
| Hai hồ sơ đóng, một API treo; sau hạn API trả | Mô phỏng nhiều khóa RAM | Hồ sơ kia vẫn lưu song song; hết hạn dọn registry, phản hồi muộn không cài lại profile. |
| Hồ sơ đứng yên / ba UserId vào cùng lúc | Mô phỏng lịch coroutine thật tại biên Engine | Cả ba gia hạn ở pha khác nhau, sau 125 giây vẫn giữ quyền và đã tăng seq ít nhất hai lần. |
| Save cũ chờ API, B nhận khóa; queued writer chạy sau | Mô phỏng | A nhận LostLock, queued writer không gọi kho thêm; B giữ token và quyền ghi. |
| Studio chưa publish / ba đích dữ liệu Studio đã publish | Mô phỏng hồi quy | RAM-only giữ hành vi cũ, 0 lần mở/ghi kho; Studio đã publish không yêu cầu tên sản xuất. |
| Play Solo / Server & Clients / hai server Roblox / điện thoại / staging | Chưa chạy | **Chờ nghiệm thu**, không có phiên experience thử kết nối để thực thi và ghi bằng chứng; không bật API sản xuất, không publish. |

**Lệnh và kết quả cuối:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1 -Suite session_lifecycle
# LIFECYCLE_SUITE passed=12 failed=0; exit 0
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# Studio PASS; session_acquisition 19/19; session_lifecycle 12/12;
# data_persistence 5/7; exit 1 do hai ca 1.3/1.4 ben duoi
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# PASS 6/6, exit 0; chi xac nhan bo kiem dinh tu dong
```

- [x] **Hai ca vẫn FAIL, không bỏ qua:** `malformed_profile_is_quarantined` (1.3: hồ sơ sai kiểu vẫn mở ghi, túi sai kiểu bị thay bảng); `dev_reset_during_autosave` (1.4: Gold vẫn 505 thay vì 0). Các assertion giữ nguyên. CI gọi bộ chung mặc định nên hiện vẫn đỏ vì hai ca này; không coi kết quả chọn riêng lifecycle là toàn bộ CI xanh. Argon P0-3 còn cần ca Reset 1.4 trước khi ký toàn mã.
- [x] **Bằng chứng RED→GREEN:** `logs/phase12-baseline.log`, `logs/phase12-red.log`; mở rộng kiểm hàng đợi và kết quả hai đường đóng có red riêng `logs/phase12-queued-red.log`, `logs/phase12-outcome-red.log`, sau sửa đều đạt. Lỗi khai báo kiểu đã lưu ở `logs/phase12-verify-first.log`/`phase12-verify-second.log`: weak table sửa một lần; arity của pcall worker cần hai lượt chỉnh, lượt hai đạt bằng return boolean ở mọi nhánh. Không còn lỗi cùng loại chưa giải quyết sau hai vòng.
- [x] Log cuối: `logs/phase12-lifecycle-final.log`, `logs/phase12-regressions-final.log`, `logs/phase12-verify-final.log`, `logs/app.log`. Fixture mở rộng lịch coroutine/đa khóa/GetAsync, không thay kết quả của các dịch vụ gameplay cần kiểm.
- [x] **90/90 file mã game ≤350 dòng**, lớn nhất CurrencyService 342. DataService 191, LockHelper 143, Persistence 186, WriteHelper 62. HudPanel 268 / PetsService 298 / ProgressPanel 268 / BagPanel 307 / FishingService 282, đều <310. `git diff --check` đạt.
- [x] Build `build/mighty-angler-dev.rbxlx`, SHA-256 **`563AE53ABDB1181330E7324453DE604537AA2C865088B2D64E849FD8CA91D9B1`**. Đối chiếu Source bốn module dữ liệu **4/4 khớp** sau chuẩn hóa xuống dòng; chưa Play build này trong Studio.

### Đang làm dở [~]

- [~] Chờ Kỹ sư trưởng review commit riêng chứa mục bàn giao này. Chưa đóng nghiệm thu Engine của Codex P0-02; Argon P0-3 còn phụ thuộc mục 1.4. Không tự chuyển sang 1.3 trước review theo giao việc hiện hành.

### Bước tiếp theo [ ]

- [ ] Review bản vá và tái chạy lệnh; nghiệm thu Studio/Server & Clients/hai server trên experience thử có sẵn và staging theo AGENTS. Không mở API sản xuất để kiểm.
- [ ] Sau giao việc tiếp: sửa schema/cách ly ở 1.3 và Reset theo hàng chờ ở 1.4 để đóng hai test còn đỏ; xử lý HUD/snapshot 1.5 ở mục riêng.

### Quyết định kỹ thuật & Lưu ý cho AI ca sau

- Thêm duy nhất trường tùy chọn `lastReleaseReceipt = {token, nonce, saveSeq}` vào tài liệu khi lưu cuối; không tăng dataVersion. Claim mới bảo toàn receipt, ghi thường giữ receipt mới nhất từ kho thay vì snapshot cũ; receipt chỉ một mục nên không tăng dần theo lượt vào. Writer giữ UserIds/metadata khi keyInfo có sẵn. Khi làm schema 1.3 cần bảo toàn receipt này và các dữ liệu nghiệp vụ, không coi thiếu receipt ở hồ sơ cũ là lỗi.
- Nếu receipt cũ đã bị một lần đóng mới thay thế và không còn bằng chứng đủ cho thao tác đang chờ, báo Unconfirmed/LostLock một cách bảo thủ; không suy ra Saved chỉ từ số seq lớn hơn. Hết deadline chỉ báo chưa xác nhận tại hạn đó, không cam kết API đang treo đã bị Engine hủy.
- `SaveProfile(player, true)` đi qua tác vụ đóng chung để không còn cửa giao dịch sau nhả khóa. Reset vẫn giữ điểm vào cũ và còn lỗi 1.4 có test; không đổi tiền/thưởng hay tự sửa các mục ngoài phạm vi.
- Bản vá gồm DataService/LockHelper, hai helper mới, fixture/lifecycle/persistence tests, hai runner, README test và PROGRESS. Không sửa AGENTS/PLAN/matrix/CI của ca khác; commit `9282aa6` được giữ riêng. Tất cả ghi thử ở kho RAM giả lập, không có thao tác DataStore thật hoặc phát hành.

## Bản vá mục 1.1 — Xác nhận quyền ghi và nhả phiên rời lúc tải

### Đã hoàn thành [x]

- [x] Nhận chỉ đạo tiếp tục trên `codex/studio-data-isolation`, nền `45dd21a`, cây làm việc sạch lúc nhận ca; đọc lại AGENTS/PROGRESS/blueprint và DataService/LockHelper. Trong lúc thi công phát hiện tài liệu AGENTS/PLAN và `docs/SPEC_CODE_MATRIX.md` được ca khác sửa/tạo; đã đọc phần quy định mới, giữ nguyên và không đưa các thay đổi đó vào commit của mục 1.1.
- [x] **Codex P0-01 — lỗi trước vá, đọc mã + mô phỏng:** ngoại lệ tạo nonce trong callback hàng chờ bị `WithUserLock` bắt/cảnh báo nhưng `lockFailed` vẫn false; hồ sơ mặc định được cấp quyền ghi mà chưa xác nhận claim. Ngoài ra, kiểm giao dịch trong lúc tải có thể đặt cờ chỉ đọc rồi không gỡ dù claim sau đó thành công. Nay khóa mặc định từ đầu tải, chặn khi chưa có hồ sơ, chỉ mở lại khi claim xác nhận đúng token/nonce hoặc ở chế độ RAM-only hiện có; không cấp token và thời điểm xác nhận cho phiên chưa xác nhận claim.
- [x] **Codex P1-01 — lỗi trước vá, đọc mã + mô phỏng:** nhả khóa chỉ gọi một lần và bỏ kết quả; lỗi tạm để token cũ nằm lại tới TTL. `ReleaseToken` nay trả `Released`, `NotOwner` hoặc `TransientError`, thử tối đa **3 lần**, nghỉ **0,5 giây** giữa lần lỗi, kiểm giá trị trả về và cảnh báo khóa hồ sơ/token nếu hết lượt chưa xác nhận. Callback chỉ sửa tài liệu có đúng token; gặp chủ khác thì hủy cập nhật.
- [x] **Hai tình huống từ review sớm:** (1) claim đã ghi nhưng mất phản hồi, A rời lúc chờ thử lại; nay DataService nhả đúng token lượt vào ngay cả khi chưa nhận xác nhận claim. Việc dọn token rời lúc tải được tập trung tại DataService và chạy qua hàng chờ UserId, không dọn lặp ở Helper. (2) nhả hồ sơ bị cách ly có thể yield; nay kiểm lại người chơi/cờ đóng sau bước đó trước khi cài hồ sơ vào RAM hoặc phát callback.
- [x] **Ca biên từ review tiếp:** A vẫn online sau cả 3 claim đã ghi nhưng mất phản hồi, tải kết thúc chỉ đọc rồi A rời. Đã tái hiện token A còn giữ kho và sửa bằng kết quả thứ ba `claimMayBeOwned` của Helper: DataService dọn đúng token chưa chắc chắn ngay trong hàng chờ trước khi kết thúc tải thất bại, không đợi PlayerRemoving. Kết quả từ chối đã biết/chưa từng gửi claim không phát sinh yêu cầu nhả. Lỗi tạo nonce sau một claim chưa chắc chắn cũng giữ thông tin cần dọn thay vì để ngoại lệ làm mất dấu token. Không thay lịch gia hạn/lưu cuối của 1.2.
- [x] **File thay đổi của mục này:** `src/server/Services/DataService.luau`, `src/server/Services/DataStoreLockHelper.luau`, `tools/test_session_acquisition.ps1`, `tests/session_fixture.luau`, `tests/session_acquisition.luau`, `tests/README.md`, `PROGRESS.md`.
- [x] **RED → GREEN:** nền trước sửa có 4/8 ca lỗi (mở quyền sau ngoại lệ, không mở lại sau pending, không retry nhả, không báo hết lượt). Sau sửa đầu tiên 8/8 đạt; bổ sung đối chiếu token/nonce/quyền chủ và trạng thái nhả đạt 13/13. Hai lỗi review sớm tái hiện trong `logs/session-acquisition-review-red.log`, sửa đạt 16/16. Ca rời sau tải thất bại và nonce lỗi sau claim chưa chắc chắn tái hiện trong `logs/session-acquisition-rejoin-red.log`, sửa và bổ sung kiểm ngoại lệ hàng chờ đạt **19/19, exit 0**. Test API lỗi liên tục nay đếm riêng tối đa 3 lần nhận và 3 lần dọn token chưa chắc chắn; không nới trần mỗi thao tác. Không còn lỗi chưa giải quyết vượt giới hạn hai vòng.

| Ca | Bằng chứng | Kết quả thực tế |
|---|---|---|
| Ngoại lệ nonce trong hàng chờ nhận khóa | Mô phỏng đường thật DataService/LockHelper | Cảnh báo được ghi, giao dịch khóa, `CanWritePersistent=false`, `SaveProfile=Skipped`; lượt vào tiếp cùng UserId vẫn tải được. |
| Đang chờ claim và hồ sơ xác nhận hợp lệ | Mô phỏng | Đang chờ không có quyền ghi; khi xác nhận mở đúng quyền, lưu Gold 321 và `saveSeq=2`. |
| Lỗi API nhận khóa / phản hồi sai token / sai nonce | Mô phỏng | Nhận khóa dừng sau 3 lượt; hồ sơ giữ chỉ đọc, không lưu đè. |
| A đang giữ khóa, B xin cùng hồ sơ | Hai máy chủ độc lập mô phỏng, chung kho RAM | A còn quyền và lưu Gold 999; B bị chặn, không đổi token A. |
| Hai lượt vào cùng UserId trong một máy chủ, A rời lúc tải | Mô phỏng | B chờ hàng đợi; lần nhả đầu lỗi, lần hai thành công rồi B nhận token khác và lưu Gold 456. |
| Nhả A chậm trước commit hoặc sau commit/đang chờ phản hồi | Hai máy chủ mô phỏng | Sau B nhận khóa và lưu, nhả muộn giữ nguyên token B, `saveSeq=2`, Gold 789; không có commit ghi đè B. Ca trước commit kiểm callback chạy lại trên phiên B. |
| Nhả hết lỗi tạm / đã nhả nhưng mất phản hồi | Mô phỏng | Hết 3 lần trả `TransientError` và cảnh báo có key/token; nếu đã ghi nhưng mất phản hồi, retry xác nhận `NotOwner`, không ghi lần hai. |
| Claim đã ghi nhưng mất phản hồi rồi A rời | Mô phỏng, hai nhánh có/không chủ B | Dọn đúng token A thay vì đợi TTL; nếu B đã giữ khóa, vẫn gọi kiểm token và hủy ghi, giữ token/seq/Gold 975 của B. |
| A còn online khi cả 3 claim mất phản hồi, sau đó rời/vào ngay | Mô phỏng | Giữ chỉ đọc, dọn token trước khi kết thúc tải thất bại (3 claim + 1 nhả); lượt vào lại có quyền ghi và lưu Gold 642 mà không đợi TTL. |
| Ngoại lệ trước gửi claim / ngoại lệ nonce sau claim chưa chắc chắn | Mô phỏng | Chưa gửi claim: 0 yêu cầu kho/nhả, hàng chờ dùng lại được. Đã có claim chưa chắc chắn: chỉ đọc và dọn đúng token (1 claim + 1 nhả). Chủ khác đã được xác định: 3 lần xin khóa, 0 lần nhả thừa. |
| Rời trong lúc retry nhả hồ sơ bị cách ly | Mô phỏng DataService + ProfileMigrator thật | Nhả lần hai thành công; người đã rời không được cài lại vào `profiles`, callback tải xong phát 0 lần. |
| Studio chưa publish | Mô phỏng | RAM vẫn chơi/lưu RAM theo chế độ cũ, mở kho 0 lần, gọi DataStore 0 lần. |
| Studio/hai server Roblox thật | Chưa chạy | **Chờ nghiệm thu**; không bật API sản xuất và không ghi dữ liệu thật. |

**Lệnh tái chạy và kết quả cuối:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_session_acquisition.ps1
# SESSION_SUITE passed=19 failed=0; exit 0
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# PASS; exit 0; Studio yêu cầu tên kho sản xuất = 0
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# PASS 6/6; exit 0 — chỉ là bộ kiểm định tự động
```

- [x] Log cục bộ: `logs/session-acquisition-red.log`, `logs/session-acquisition-review-red.log`, `logs/session-acquisition.log`, `logs/studio-data-isolation.log`, `logs/app.log`. Lần verify đầu phát hiện cách gán biểu thức `number?` vào map thời điểm; sửa một lần thành nhánh `if confirmedLock`, lần verify sau và lần cuối đều đạt. Log lỗi kiểu được giữ ở `logs/session-acquisition-verify-first.log`.
- [x] Đếm độc lập: **88/88** file mã game ≤350; lớn nhất CurrencyService **342**. DataService **327**, DataStoreLockHelper **182**. HudPanel **268**, PetsService **298**, ProgressPanel **268**, BagPanel **307**, FishingService **282**, đều <310. `git diff --check` đạt.
- [x] Build `build/mighty-angler-dev.rbxlx` đối chiếu Source hai module dữ liệu **2/2 khớp**. SHA-256: **`4E4494E36988A6A453A8942D3E0DF732A22858AD63652FA3F18D1D9EB53AF25A`**. Chưa Play bản này trong Studio.

### Đang làm dở [~]

- [~] Chờ Kỹ sư trưởng review commit riêng chứa mục bàn giao này (`git log` trên nhánh hiện tại); chưa coi hai mã V3 đã được nghiệm thu Engine.

### Bước tiếp theo [ ]

- [ ] Nghiệm thu các ca trên trong Studio và hai server Roblox trên experience thử/kho thử theo blueprint; ghi đủ trace và kiểm không yêu cầu kho sản xuất.
- [ ] Dừng tại đây để review. **Chưa chuyển sang 1.2**: thời hạn quyền ghi từ dấu giờ kho, gia hạn rải nhịp, gộp hai đường đóng và bảo đảm lần lưu cuối vẫn chờ bản vá sau.

### Quyết định kỹ thuật & Lưu ý cho AI ca sau

- Bộ mới chạy nguồn thật DataService/Helper/Migrator, không mock `Get`, `CanWritePersistent`, `IsTransactionLocked` hoặc logic khóa. Chỉ giả lập biên Engine (dịch vụ, tín hiệu, đồng hồ, Instance leaderstats, kho RAM); hai server có bộ module/hàng chờ độc lập. Không suy ra đây là kết quả mạng/Roblox Engine thật.
- Giữ `_StudioDev` và chế độ RAM-only của `45dd21a`; không sửa LiveOps ở mục này. Không đổi quy tắc gia hạn/lưu cuối, schema, Reset hay HUD. Cảnh báo `Release unconfirmed` có nghĩa chưa chứng minh nhả xong sau 3 lần, không được báo thành công; token khi đó vẫn phải chờ hết hạn hoặc một lần dọn có xác nhận sau này.

## Bản vá mở đầu Đợt 1 — Cách ly dữ liệu Studio (2026-11-18)

### Đã hoàn thành [x]

- [x] Nhận ca ở `51c020c`, `git status --short` và `git diff` rỗng, đọc 5 commit gần nhất cùng AGENTS/PROGRESS/V3/blueprint và phần dữ liệu của PLAN. Không có commit mới hơn hoặc thay đổi người dùng cần giữ lại. Thi công tại đường dẫn được giao, trên nhánh cục bộ `codex/studio-data-isolation`.
- [x] **Lỗi gốc — đọc mã + tái hiện bằng mô phỏng:** `DataStoreLockHelper.TryGetStore()` đã tách `MightyAngler_Profile_v2_StudioDev`; `LiveOpsService.refreshLeaderboards()` chỉ kiểm `PlaceId > 0`, mở `MightyAngler_TopStr_v2` và `MightyAngler_TopGold_v2` ngay cả khi Studio đang chạy place đã publish. Điểm DEV có thể thành kỷ lục bền ở kho thật nếu API được bật. Đây là phát hiện bổ sung về kho điểm trong V3, bảo vệ hai mục đã đạt **Codex P1-02 / Argon P0-1**; chưa đóng các mã khóa phiên/lưu cuối của Đợt 1.
- [x] **Bản vá:** `src/server/Services/LiveOpsService.luau` thêm `RunService:IsStudio()` khi mở cả hai OrderedDataStore: Studio dùng hậu tố `_StudioDev`, máy chủ thật giữ tên cũ. Giữ nguyên `PlaceId > 0`, điều kiện `DataService.CanWritePersistent`, bỏ điểm 0 và `UpdateAsync` lấy `math.max`. `DataStoreLockHelper` không cần sửa vì đường hồ sơ đã chọn đúng kho và đã được thực thi trong phép thử.
- [x] **Phép thử mới:** `tools/test_studio_data_isolation.ps1`, `tests/studio_data_isolation.luau`, `tests/README.md`. Chạy nguyên văn 5 module nguồn trong Luau CLI 0.747, thay dịch vụ Roblox bằng kho RAM; spy ghi tên ngay tại lời gọi mở kho. Chạy cả refresh đầu tiên và refresh định kỳ. Không gọi Roblox API, không bật API Services, không ghi dữ liệu sản xuất. Binary Luau và runner sinh ra chỉ nằm trong `tools/` và `build/` đã được Git bỏ qua.
- [x] **RED → GREEN:** trước bản vá, lệnh mô phỏng exit **1**, lỗi `expected MightyAngler_TopStr_v2_StudioDev, got MightyAngler_TopStr_v2`; trace cũng ghi Gold dùng tên sản xuất. Sau một vòng sửa, lệnh dưới exit **0**, toàn bộ ca mô phỏng đạt. Không có lỗi tồn đọng sau hai vòng sửa.

| Ca | Loại bằng chứng | Kết quả thực tế |
|---|---|---|
| Studio, `PlaceId = 0` | Chạy mô phỏng | 0 lời gọi mở kho, 0 ghi bền; hồ sơ báo RAM-Only Fallback. |
| Studio, `PlaceId = 123456` (đã publish) | Chạy mô phỏng | Cả hồ sơ, Top Strength, Top Gold dùng `_StudioDev`; **0 yêu cầu tên kho sản xuất**, kể cả refresh định kỳ và các ca kỷ lục. |
| Máy chủ thật, `IsStudio = false`, `PlaceId = 123456` | Chạy mô phỏng, kho RAM | Mở đúng 3 tên sản xuất cũ. Trace routing có 5 lời gọi (1 hồ sơ + 2 bảng × 2 refresh); không có kết nối dữ liệu thật. |
| Lỗi API khi mở lần lượt hồ sơ/Strength/Gold Studio | Chạy mô phỏng | Vẫn chỉ yêu cầu kho `_StudioDev`, không thử chuyển sang tên sản xuất. |
| Hồ sơ chỉ đọc hoặc chưa tải | Chạy mô phỏng đầu vào quyền ghi của LiveOps | Không cập nhật điểm của các hồ sơ này. `DataService.Get/CanWritePersistent` là đầu vào điều khiển; chưa kiểm tính đúng của khóa phiên. |
| Kỷ lục hai bảng | Chạy mô phỏng | 125,9/250,8 → 125/250; gửi 5/10 vẫn giữ 125/250; gửi 400/800 nâng đúng; điểm 0 không tạo lượt UpdateAsync. |
| Studio thật: place cục bộ và place đã publish, API tắt/bật trên kho thử | Chưa chạy trong Studio | **Chờ nghiệm thu**: ca này không có phiên Studio kết nối để thực thi/ghi bằng chứng Engine. Không bật API sản xuất để thử. |

**Lệnh và kiểm định thực tế:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# exit 0; trace ở logs/studio-data-isolation.log của ca thi công
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# exit 0; PASS 6/6; logs/app.log; build/mighty-angler-dev.rbxlx
```

- [x] Bộ verify cũng đã đạt trên nền trước sửa. Lần kiểm sau sửa đạt 6/6 (dòng/API/sourcemap/Luau-LSP/Selene/build). **PASS 6/6 chỉ xác nhận bộ kiểm định tự động**, không phải ký nghiệm thu Studio hay phát hành.
- [x] Đếm độc lập bằng `[IO.File]::ReadAllLines`: **88/88** file mã game ≤ 350, lớn nhất `CurrencyService` **342**. `HudPanel` **268**, `PetsService` **298**, `ProgressPanel` **268**, `BagPanel` **307**, `FishingService` **282**, đều < 310; `LiveOpsService` **259**. `git diff --check` đạt.
- [x] Đọc XML bản build, đối chiếu nguyên văn `Source` của `LiveOpsService` với file nguồn: **1/1 khớp** sau chuẩn hóa xuống dòng. Place: `build/mighty-angler-dev.rbxlx`, SHA-256 **`4F186A6D7D2DFA82971B270EDD1FE712CC98BD5C673C5B34736EEED9AEA99874`**. Đây là bản build tự động, chưa được mở Play trong Studio ở ca này.

### Đang làm dở [~]

- [~] Bản vá đang chờ Kỹ sư trưởng ở chat riêng review diff/commit và quyết định nghiệm thu. Commit của bản vá là commit chứa mục bàn giao này; tra bằng `git log -n 1 --oneline` trên nhánh trên.

### Bước tiếp theo [ ]

- [ ] Nghiệm thu hai chế độ Studio thật trên đúng bản build, ghi trace mở kho với số yêu cầu tên sản xuất bằng 0; kiểm API bị chặn trên kho thử. Không tự bật API sản xuất.
- [ ] Sau khi Kỹ sư trưởng duyệt, mới tiếp tục khóa phiên và lưu cuối theo 1.1/1.2. Hai server trực tuyến trong experience thử riêng còn **chờ nghiệm thu**; chưa cấu hình hay chạy các server đó ở bản vá này.

### Quyết định kỹ thuật & Lưu ý cho AI ca sau

- Giới hạn ca này ở phần mở đầu Đợt 1 theo yêu cầu trực tiếp; không thực hiện toàn bộ blueprint, không thay session lock/Reset/migration và không gọi Gemini. Quyền review/phát hành thuộc Kỹ sư trưởng, khác vai trò thi công của Codex ở ca này.
- Giữ quy tắc đặt tên `_StudioDev` hiện có, không đổi kiến trúc kho dữ liệu. Việc cách ly này chỉ dựa vào Studio; server trực tuyến cần experience thử riêng theo blueprint trước khi thử ghi. Không suy diễn rằng bản vá đã cách ly một server thử chạy trong experience sản xuất.
- Phép thử là VM Luau với biên Roblox giả lập, không phải Play trong Studio; không dùng kết quả này để ký các lỗi khóa phiên hoặc lưu cuối. Giữ các phần bàn giao cũ bên dưới làm lịch sử; trạng thái mới nhất là mục đầu file này.

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


## Nhánh Đợt 2 · cân nặng và hạn bấm (Codex Sol, 2026-11-18)
- [x] Checkout riêng `build/v3-fishing-sol`, nhánh `codex/v3-fishing`, nền `9282aa6`; không sửa checkout gốc.
- [x] Quyết định cân nặng: thường dùng max(species.maxWeight, rod*1.15), làm tròn gần nhất; Titan giữ cap rod*1.25 và làm tròn xuống. Luau VM chạy nguồn thật kiểm Twig/Trident thường 22.0kg, Trident Titan 21.2kg, nhãn/hệ số giá giữ nguyên.
- [x] 2.3 Codex P1-10: MinigameBar không gửi sau timeoutSec, không tự đóng do đồng hồ local; đợi máy chủ. Mỗi vòng chờ ack tới khi server trả thay vì tự gửi lại sau 0.5s.
- [x] `tools/test_fishing_wave.ps1`: PASS; `tools/verify_project.ps1`: PASS 6/6 exit 0.
- [~] Test chung `tools/test_studio_data_isolation.ps1`: isolation/acquisition PASS; 4 ca persistence đỏ của nền Đợt 1 (late_save_response_cannot_extend_ownership, both_close_paths_wait_for_final_save, malformed_profile_is_quarantined, dev_reset_during_autosave), đã báo trưởng nhóm; không sửa tại nhánh gameplay.
- [ ] Chuột/chạm, 200ms 1/2/3 vòng trong Studio: chờ nghiệm thu; test VM hiện xác nhận việc giữ UI tới kết quả server, không suy ra đã thử Engine.
- File: FishingRoller.luau, MinigameBar.luau, tools/test_fishing_wave.ps1, tests/fishing_wave.luau, PROGRESS.md.


## Nhánh Đợt 2 · phạm vi giao dịch và Index (Codex Sol, 2026-11-18)
- [x] 2.4 Argon P1-3/Codex P1-06: WorldPromptAccess tìm prompt đang tồn tại trong đúng Island, lấy điểm BasePart/Attachment/Model và MaxActivationDistance thật, đo 3D. Finn cho Appraise/Bounty/Trident; chỉ Kaito NPC hoặc bệ cho Enchant, không dùng tọa độ thiết kế hoặc quầy Shop trang trí. Kiểm enabled/IslandId tại lúc xác nhận.
- [x] 2.5 Argon P1-1/Codex P1-14: signature Index chưa vẽ là nil, khác bộ sưu tập rỗng; lần đầu luôn tạo 65 thông số thẻ/counters. GridWindow không clamp lưới khuất thành hàng 0; chỉ thấy +1 hàng mỗi đầu. ViewportPool theo dõi Visible/Enabled các tổ tiên, vị trí/resize/cuộn; thả thẻ ẩn và ngừng xoay; ngắt các kết nối quan sát khi Destroying.
- [x] Bổ sung review 2.3: harness Mount thật capture nút/chuột: T-0.05 gửi 1, lặp lúc chờ ack không resend, T+0.001 không gửi mới; ACK trễ 200ms vẫn không mở lại input hay tự đóng UI. Luau nguồn thật PASS cho 1/2/3 vòng.
- [x] `tools/test_fishing_wave.ps1` PASS, `tools/verify_project.ps1` PASS 6/6 exit0. Test chung chạy lại: 4 ca dữ liệu đỏ nền Đợt 1 giữ nguyên; Bounty test giữ biên kiểm phạm vi riêng bằng WorldPromptAccess fake, logic phạm vi có bộ riêng.
- [ ] Studio NPC mặc định/override và sát bán kính, 50 lần mở/đóng/resize Index, số kết nối/thẻ sống, điện thoại: chờ nghiệm thu.
- File: EnchantAndBountyService/WorldPromptAccess, IndexGridSection/ViewportPool/GridWindow, tests/fishing_prompt_grid, tests/fishing_wave, tests/data_persistence, runner và PROGRESS.
## Nhánh thi công riêng Đợt 3 — Codex UI (nền 9282aa6)
- 3.1 / Codex P1-13: PerkService chỉ chấp nhận boolean false; lỗi API và Studio offline không còn tự mở quyền. Hai điểm trừ Gems (PetsService, EnchantAndBountyService) đã có kiểm policy server và giữ nguyên.
- `tools/test_paid_random_policy.ps1`: PASS 7 trạng thái pending/API lỗi/thiếu trường/string/numeric/true/false, thực thi nguyên hàm policy trích từ nguồn; chưa mô phỏng giao dịch đầy đủ.
- Verify PASS 6/6, exit 0. Suite chung: cách ly Studio PASS, session 19/19 PASS; data_persistence 3/7 (4 lỗi có sẵn ở nền 9282aa6 thuộc Đợt 1), không sửa ngoài phạm vi.
- Ca trứng Gold/Relic và giao dịch Gems trên Roblox, hai client/điện thoại: chờ nghiệm thu. Không mở kho thật.
- Camera/cảm ứng: dùng CameraFocusController giữ ưu tiên thoại 62°, minigame 64°, bình thường 70° và hủy tween cũ; hai thứ tự đóng chạy mô phỏng nguồn thật PASS (`test_camera_focus.ps1`). Touch chỉ cập nhật vị trí ngón đang nạp lực, ngón thứ hai không đổi aim.
- Verify sau vá camera PASS 6/6 (một sửa kiểu Tween nullable). Suite dữ liệu chạy lại vẫn 4 lỗi nền Đợt 1; log `logs/ui-camera-data-regression.log`. Rê ngón/di chuyển đồng thời và ảnh/video trên máy thật chờ nghiệm thu.
- Bổ sung review 3.1: `test_paid_random_transactions.ps1` thực thi nguyên handler HatchEgg/RollEnchant và policy từ nguồn, giả lập biên tiền/kho/địa điểm/roll. Sáu ca từ chối giữ nguyên Gems, pet, enchant, relic; Gold/Relic vẫn chạy; boolean false trừ đúng một giá mỗi hành động. PASS. Runner tự tạo build khi checkout sạch.
- Quyền lợi Studio (`DEV_UNLOCK_PERKS_IN_STUDIO`/Grant All Passes) không vượt policy; API policy thật lỗi ở Studio offline nay bị chặn Gems. Không tạo đường giả policy Allowed, không dùng kho sản xuất.
- 3.5 / Codex P2-05: thay quét toàn world/nhân vật mỗi 2s bằng cache emitter theo DescendantAdded/Removing (một scan ban đầu); mọi hạt kể cả cá đột biến người khác được lọc gần/xa và Low GFX, hỗ trợ emitter trong Attachment. Giữ trạng thái authored qua reparent để pet trở lại không bị tắt hạt vĩnh viễn.
- Pet xa >160 studs được tháo khỏi Workspace; trở lại được đặt lại cạnh chủ rồi hiện, không đứng lại đảo cũ. Dọn model kể cả lúc đang ẩn. Verify PASS 6/6; test_particle_budget PASS near/far/Low GFX/reparent/scan một lần; suite dữ liệu vẫn 4 lỗi nền Đợt 1 (log ui-fx-data-regression.log).
- Hai client, điện thoại cùng cảnh, frame-time median/p95 và ảnh/video trước/sau: chờ nghiệm thu; chưa có số hiệu năng thực máy.
- 3.3 / Codex P2-02: Shop nay cộng Strength Mastery vào Rare/Boss bar; Shop/HUD/BuffAggregator dùng CatchControl chung, máy chủ Session dùng cùng clamp/base Rare 28%, Boss 22%. Lời hứa ExtraPets đọc trực tiếp BASE/BONUS_PET_EQUIP_SLOTS (2 → 4), không còn 4 → 7.
- Verify PASS 6/6; `test_catch_control.ps1` PASS nền Rare/Boss và 36 tổ hợp Strength/Control. Suite chung vẫn đúng 4 lỗi dữ liệu nền, log ui-control-data-regression.log. Giao diện và trang bị 4 rồi từ chối con thứ 5 trên Engine chờ nghiệm thu.
- 3.4 / Codex P1-16: bỏ các asset hoạt ảnh slash/lunge/cheer dùng sai hành động; dùng tư thế riêng Cast/Reel/FishHold/Dumbbells/BenchPress/Treadmill. Mọi client dựng theo VisualAction/VisualActionAt và FishingPoseActive do server đặt; lớp Transform gỡ offset ở PreAnimation rồi áp sau Animator ở PreSimulation, tránh cộng dồn; hỗ trợ Motor6D và AnimationConstraint, làm mới theo character/descendant.
- PlayerVisuals truyền động tác tập đã được server chấp nhận; barbell gắn tay phải thay vì thân để đi theo động tác. RodVisuals truyền cast/reel/wait. Không thêm remote yêu cầu pose từ client.
- Verify PASS 6/6, suite chung vẫn 4 lỗi nền Đợt 1 (ui-animation-data-regression.log). Hai client R6/R15 Motor6D/R15 AnimationConstraint, tạ hai tay và hồi sinh: chờ nghiệm thu; chưa có ảnh/video, chưa ký đạt Engine.
- Tham chiếu thời điểm cập nhật Transform: https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint và https://create.roblox.com/docs/reference/engine/classes/Motor6D/Transform (Animator ghi sau PreAnimation, trước PreSimulation).
- Review 3.5: chỉ emitter được builder gắn ClientBudgetManaged mới chịu budget, bỏ qua Toolbox và FX tạm. Aura dùng Rate=0 + ClientBudgetEnabled=false khi tắt, đọc trạng thái động thay vì ghi đè Enabled cũ; giữ ngưỡng aura 145 studs. Test PASS mất/có aura, Rate=0, 144/146 studs và Toolbox không bị can thiệp. Pet mất Character/HRP cũng ẩn.
- Review 3.4: giữ lại nguyên neo thân/barbell offset nền 8227545 để bảo vệ Argon P1-9; thu hồi ghi chú gắn tay phải phía trên. ClearBobber chỉ phát Reel khi thực sự có active bobber; dọn trước cast không phát Reel. Verify PASS 6/6; suite dữ liệu vẫn 4 lỗi nền. Ca hình học barbell R6/R15 và hai client chờ nghiệm thu.


## Nhánh Đợt 2 · tia câu, Perfect và một lịch Auto (Codex Sol, 2026-11-18)
- [x] 2.1 Argon P1-4/Codex P1-08: FishingRayFilter dùng chung Client/Server, tường OceanBound vẫn va chạm người nhưng bị loại bằng FishingRayIgnore. Máy chủ dùng ray hit đầu tiên thật từ vai tới điểm ngắm, không tin hitWater hoặc tọa độ nảy Client; chỉ nước Terrain trong vùng đảo/mặt nước mở phiên. Sky/out-of-range không mở phiên. Auto thử tối đa 61 điểm qua đúng cùng validator; nước bị che không còn được tự coi hợp lệ.
- [x] 2.2 Argon P1-5/Codex P1-09/P1-11: Perfect chỉ theo thời gian giữ máy chủ, bỏ quyền tự khai holdRatio; kiểm biên 0.78/0.95 và 0.779/0.951 bằng nguồn thật. Pro chỉ cộng buff trong nhánh AutoPro hiện có; không đổi nhánh thưởng tay thường/Free.
- [x] FishingSessionManager.CloseSessionOnce gọi FishingCastState.Close đúng một lần, gửi FishingSessionClosed cho mọi kết thúc (cả Win/Timeout). Một nơi tính cooldown đủ Free 1.10/Pro 0.45 và gửi readyAt theo GetServerTimeNow; duplicate strike không đẩy cooldown. FishingAutoState trả ACK bật/tắt và thời điểm thử lại nếu còn hồi. Chỉ SetAutoFish chủ động được trang bị cần; recast không tự chọn ô 1.
- [x] FishingController chỉ đặt lịch qua scheduleSingleAutoRecast, theo readyAt server và ticket; reserving pending request ngăn gửi trùng. Kết quả thưởng chỉ hiển thị, không tự điều phối lịch nữa. OFF→ON khi đang hồi nhận lại hạn server. Close lặp bị chặn theo sessionId. Cất cần/hủy tay/đổi đảo/Rebirth/chết dừng Auto; có lý do đóng, người chơi bật lại chủ động. Hủy khi không có phiên cũng gửi reset để vô hiệu lịch hồi cũ.
- [x] Bộ Luau `tools/test_fishing_wave.ps1`: 4 suite PASS (cân/Perfect/input; prompt/range/grid; ray/first-hit/1–3 vòng grace 200ms/atomic close/cooldown; lịch Client OFF→ON/duplicate/cancel/unequip/death). Không thay logic Engine bằng kết luận từ mock.
- [x] `tools/verify_project.ps1`: PASS 6/6 exit0. `tools/test_studio_data_isolation.ps1`: isolation/acquisition PASS; persistence 3/7 PASS, 4 ca Đợt 1 đỏ giống nền, Bounty qua đổi server vẫn PASS. Log `logs/fishing-wave-base-data.log`.
- [x] 92/92 mã game <=350 dòng, max CurrencyService 342. Năm file cam kết: HudPanel 268, PetsService 298, ProgressPanel 268, BagPanel 307, FishingService 281 (<310). `git diff --check` PASS. XML build đối chiếu toàn bộ Source với sourcemap 92/92 khớp; SHA-256 `C95BB9928FB80A0B416E708233529CE1646DE2B965033ACBE7BE9060D2E031B3`.
- [ ] Bản build riêng `build/v3-fishing-sol/build/mighty-angler-dev.rbxlx` chưa Play Studio; năm đảo, tất cả chế độ, điện thoại, ping Engine 200ms và hai client chờ nghiệm thu. Chưa duyệt phát hành. Khi tích hợp Đợt 1/3 phải chạy lại test chung và build/hash.
- File: FishingRayFilter, WorldBuilder, HotbarAndCastController, FishingRoller, FishingService, FishingSessionManager, FishingCastState, FishingController, Net; tests/fishing_cast_lifecycle, tests/fishing_client_schedule, tests/fishing_wave, tools/test_fishing_wave.ps1.


## Nhánh Đợt 2 · sửa sau review ý định Auto và quyền trao cá (Codex Sol, 2026-11-18)
- [x] Thay quyết định OFF khi đổi đảo/Rebirth/chết ở ghi chép 768eab6: nay giữ ý định ON qua ba lý do này. Khi chưa có phiên (đang hồi), CancelSession trả reset cùng lý do và hạn hiện có; khi đang câu chỉ CloseSessionOnce gửi kết thúc. Client đợi đủ cooldown/nhân vật sống, CharacterAdded kích lại đúng một lịch. Cất cần/hủy tay/không nước/túi đầy/chỉ đọc vẫn OFF.
- [x] Ý định bật/tắt có requestId tăng dần; server ApplyRequest bỏ lệnh cũ/lặp, không tự equip lặp khi retry. Close/ACK cũ không được tắt ý định ON mới hơn; readyAt chỉ tăng trên client để ACK cũ không rút ngắn hồi. Client gửi lại cùng intent sau 1.1s nếu chưa nhận ACK; một yêu cầu cast bị bỏ im lặng cũng có watchdog 1.1s rồi thử qua lịch duy nhất. Đây xử lý mất yêu cầu vì rate bucket Net, không bỏ giới hạn chống spam.
- [x] finalizeFishAward kiểm DataService.Get và IsTransactionLocked ngay trước mọi thay đổi túi, kỷ lục, mồi, Strength; không cấp cá khi hồ sơ chỉ đọc, đang đóng hoặc đã tháo khỏi RAM. Bộ kiểm dùng handler FishingMinigameStrike thật để gọi callback thưởng thật, xác nhận túi/stats/Index không đổi ở ba ca. Biên dữ liệu bị giả lập để kiểm gate; không tuyên bố mô phỏng lại toàn bộ lease Đợt 1.
- [x] Hồi quy mở rộng đi qua FishingService.CancelSession thật (đường IslandService/ProgressionService gọi) với cả phiên mở/đang hồi, Humanoid.Died và CharacterAdded server, các handler close/reset/CharacterAdded client. Thử bật ON trong lúc close tay cũ đang bay về, ACK cũ, ACK bị bỏ/retry cùng ID; OFF→ON trong hồi vẫn một cast. Chưa chạy toàn bộ handler IslandService/ProgressionService cùng game DataModel trong VM.
- [x] `tools/test_fishing_wave.ps1` 4 suite PASS. `tools/verify_project.ps1` PASS 6/6 exit0. Test chung giữ 4 ca đỏ nền Đợt 1, isolation/acquisition và Bounty persistence PASS (logs/fishing-wave-review-data.log). Hai lỗi trong ca chỉnh sửa nội bộ: script thay đoạn bắt nhầm ranh giới hàm làm Luau parse đỏ, đã dựng lại từ HEAD và áp theo tên hàm có ranh giới; verify sau sửa PASS. Không còn lỗi đang sửa quá hai vòng.
- [x] Nguồn build 92/92 khớp sourcemap; FishingController 242, FishingService 288, FishingCastState 60 dòng. SHA-256 mới `112A71EB79B5B09907928B6073BEF74EA8C650332A789D470C90EF2FA1297D08`; build cũ ở ghi chép trước đã được thay bằng bản này trong checkout riêng.
- [ ] Studio/hai client/mobile/network thật vẫn chờ nghiệm thu. Cần chạy lại test chung khi lấy bản vá Đợt 1. Chưa phát hành.
- Bổ sung mô phỏng 3.4: `test_animation_pose.ps1` thực thi AnimationController thật với biên CFrame/Engine giả lập; PASS R6/Motor6D/AnimationConstraint, hai người nhận action riêng, 100 frame không cộng dồn offset, hết one-shot, giữ cá/giữ cần/stop và hồi sinh. Phép thử không xác nhận hướng khớp hay hình học barbell thật; các ca hai client vẫn chờ nghiệm thu.
- Tích hợp tiếp fishing `3f43d35` và UI `0ca67fe` bằng merge giữ lịch sử; thêm lại Workspace binding cạnh CameraFocus trong FishingController để dùng đồng hồ server. Shell test nạp CatchControl/FishingRayFilter/FishingCastState thật; suite fishing và regression 23/23 PASS. Chờ UI odds/Đợt 1 và kiểm sạch cuối; chưa phát hành.
- 3.2 / Argon P1-6, Codex P1-12: OddsCalculator cung cấp chung bộ lọc loài/trọng số cho FishingRoller và UI. Loài bị loại có 0%; Rare+ HUD bao gồm Boss; cộng pet mutation, trạng thái lượt câu từ server (tay thường/Perfect/Auto) và trứng dùng cùng danh sách pet/trọng số cấu hình.
- Trước mọi Prompt mua AutoPro/Dragon (Shop detail, Shop card, tab Exclusive) đều mở bảng từng loài BEFORE → AFTER, đủ bốn chế độ, nước thường/xoáy và mutation, dùng snapshot hiện thời cùng buff. Chưa có snapshot đầy đủ không đưa tới prompt. ID thật vẫn 0; không mua thật.
- `test_live_odds.ps1` PASS **19.200 rổ** qua OddsCalculator/FishingRoller/BuffAggregator/provider item+pet thật; callback RollFishSpecies đúng trọng số, tổng=100% (hoặc 0 khi rổ không loài), loài bị loại=0; trứng 10/10, Swift=0%, Midas=4/72, Tiki HUD Shiny5,5% và biên RollMutation khớp; preview đủ loài/modes. Verify PASS 6/6, diff-check PASS. Suite chung vẫn đúng 4 lỗi nền Đợt1; logs/ui-odds-data-regression.log.
- Giao diện bảng mới trên màn hình nhỏ, mọi đường mở mua với quyền mô phỏng, trứng/Enchant trong Engine: chờ nghiệm thu. Các test mới và giới hạn được ghi ở tests/README.md.
- Tích hợp UI odds `ad013c4` bằng merge giữ lịch sử. FishingRoller đã đối chiếu đủ first-hit ray, hold server và odds chung (không đánh rơi cap/rounding). Cập nhật nguồn nạp cho suite live odds/regression; ray lifecycle stub OddsCalculator chỉ vì không gọi odds trong suite đó, logic odds thật chạy riêng 19.200 rổ.
- `test_combined_integration.ps1` mới PASS server intent + client Auto + camera thật: đổi đảo/Rebirth/hồi sinh, reset trùng, hủy tay trong cửa sổ chờ, đồng hồ server khác os.clock và % UI khớp roll. Sau ghép, 12 runner: 11 exit0, data chung vẫn đúng 1.3/1.4 đỏ (5/7); verify6/6. Chờ Đợt1 cuối; 1.5 chưa xong, chưa phát hành/Engine.

### Chốt nhánh Đợt 3 — chỉ bàn giao mã/mô phỏng, chưa ký Engine/phát hành
- **Mốc mã:** ad013c4 (chuỗi commit UI nền 9282aa6 trong build/v3-ui-sol, branch codex/v3-ui; không sửa/push/merge checkout chính).
- **Kiểm cuối:** verify PASS 6/6, exit0; bảy runner Đợt3 PASS, exit0. `git diff --check` PASS; 93/93 script trong place khớp nguyên văn nguồn theo sourcemap; 93 file game ≤350, lớn nhất342; HudPanel267, PetsService298, ProgressPanel268, BagPanel307, FishingService282 (<310).
- **Place:** build/mighty-angler-dev.rbxlx trong bản sao; SHA-256 `7476AD5B6964273A3D50493843BCA708BCA31504EDDAA13029F34B781B1C7D47`.
- **Suite dữ liệu chung:** exit1; Studio isolation PASS, session19/19 PASS, persistence3/7 (còn đúng bốn lỗi nền: late_save_response_cannot_extend_ownership, both_close_paths_wait_for_final_save, malformed_profile_is_quarantined, dev_reset_during_autosave). Log `logs/ui-final-data-regression.log`; đây không phải full regression xanh và không được ký Đợt1.
- **Đang chờ:** Studio Play Solo, hai client R6/R15/Motor6D/AnimationConstraint, xác suất/mua mô phỏng qua giao diện, trang bị 4/từ chối5, camera/touch thực máy; ảnh/video hai phía; điện thoại frame-time median/p95. Chưa mở place trong Studio tại nhánh này, chưa dùng kho thật, chưa publish.
- **Nhập nhánh:** chú ý hunk chung với gameplay trong FishingController (FOV), HotbarAndCastController (touch), FishingSessionManager (CatchControl), FishingRoller (eligibility/weight helper); giữ đồng thời các bản vá Đợt2. PROGRESS chỉ nối phần bàn giao nhánh ở cuối, không ghi đè đầu sổ của ca chính.
- Review bổ sung 3.2: HUD banner là nút `[View all odds]`; mở bảng live riêng không có nút mua, cho xem tên từng loài, Base→Live nước thường/xoáy, mode hiện tại (kể cả ManualPerfect) và mutation. Bảng đang mở cập nhật khi cast/buff/cache đổi qua refreshHudLiveOdds; không phụ thuộc sở hữu pass. Bảng BEFORE→AFTER mua giữ riêng, nhãn Free→Pro nói đúng chế độ trước nâng cấp.
- Review 3.3: handler EquipPet server nay từ chối slot dư bằng toast, không tự tháo pet cũ để thay vào. `test_live_odds.ps1` chạy handler thật kiểm 2→4, con3/con5 bị từ chối và thứ tự pet đang trang bị giữ nguyên.
- Kiểm bổ sung PASS: controller UI thật mở account có cả AutoPro/Dragon, hiện từng loài Base/Live, cập nhật ManualNormal→ManualPerfect và buff, đóng không gọi PromptGamepass, không tạo nút Continue; 19.200 rổ odds vẫn PASS. Verify PASS6/6, diff-check PASS. HudPanel269/PetsService299 đều <310. Suite dữ liệu vẫn đúng4 lỗi nền Đợt1 (logs/ui-hud-review-data.log).
- Khi nhập vào Đợt1.5: chỉ nhập hunk HUD odds (TextLabel→TextButton, Activated, nhãn odds) và hunk ClientState provider/refresh, giữ nguyên safeReadOnly/cảnh báo của nhánh dữ liệu. Nhánh UI không sửa DataService hoặc giao thức safeReadOnly.
- Bảng trực tiếp trên điện thoại/Engine và readOnly UI sau tích hợp: chờ nghiệm thu. Lần đầu verify phát hiện union callback; đã giải quyết ở lần sửa thứ2 bằng khai báo kiểu và nhánh gán rõ ràng; không còn lỗi vượt hai vòng.
- UI Live Odds `9c93901` đã merge giữ lịch sử, giữ FishingRayFilter và PurchaseOddsController cùng có trong runner. Test odds PASS 19.200 rổ + người có cả AutoPro/Dragon xem Base/Live từng loài, đổi mode/buff và đóng không prompt mua. Bổ sung assertions handler thật: chủ động bỏ pet cũ để lắp con mới, Unequip All và Equip Best vẫn chọn pet mạnh nhất/đủ slot/không trùng; PASS. Đọc PetsPanel xác nhận card EQUIPPED gửi UnequipPet và nút Unequip All/Equip Best còn nguyên. Verify6/6; bảng điểm hai kho/môi trường PASS; data vẫn 1.3/1.4 đỏ nền0ded6d4. Chờ dữ liệu 1.3–1.5 cuối để kiểm HUD Live Odds không mất khi ghép safeReadOnly; chưa phát hành.
- Tích hợp dữ liệu `99216b5` bằng merge `053a393`, 12/12 test runners cũ exit0 (liệt kê từ rg), verify6/6. Dữ liệu schema29/29, Reset12/12, persistence7/7, acquisition19/19, lifecycle12/12; không nới fixture/assert. Thêm `test_place_sources.ps1` đối chiếu100/100 Source/class/path (chuẩn hóa xuống dòng XML). Tài liệu `docs/V3_BAN_GIAO_NGHIEM_THU.md` đủ23 mã/3đợt, build/hash tạm đã kiểm và checklist ngắn;1.5 còn chờ tip. Studio chưa chạy vì quyền ứng dụng, chưa phát hành; checkout chính nguyên.

## Chốt hợp nhất cuối (code kiểm sạch dd53d3a)

- [x] Merge `8699970` giữ cả dữ liệu/init/readOnly và LiveOdds/Net/FishingAutoState. Fixture client nạp đủ CatchControl/PurchaseOdds/odds/config thật; thêm biên Instance signal/Players/Vector3 hợp lệ, không nới assertion. Init13ca gốc đạt; thêm1ca cùng HUD/ClientState/LiveOdds thật qua loading→snapshot→khóa→khôi phục, nay14/14.
- [x] Từ cây sạch chạy verify6/6 rồi toàn bộ13test*.ps1 tìm bằng rg: từng runner exit0. Source101/101; SHA256 `9BD66C58AD037E8D5AAE3841841E315EC0B727465FC98CB56699A35A1D52EDE5`. HudPanel275/ProgressPanel268/PetsService299/FishingService288/BagPanel307 (<310),101file≤350.
- [x] Tài liệu bàn giao23mã/3đợt đã chốt, linkmatrix21 và đủ13runner/hash. Ghi rõ HAI server cùng universe staging riêng hoặc namespace đã xác minh; liệt kê ba kho thật và `_StudioDev` chỉ khi IsStudio. Không tự thêm namespace hoặc tự publish.
- [ ] Studio chưa chạy vì quyền ứng dụng; chưa nghiệm thu Engine/thiết bị, chưa duyệt phát hành. Kỹ sư trưởng nhập fast-forward và kiểm độc lập; phần trạng thái pending cũ bên dưới/phía trên là lịch sử của từng mốc, không phải kết luận ứng viên cuối.
