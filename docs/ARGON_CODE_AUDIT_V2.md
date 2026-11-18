# 🛡️ BIÊN BẢN KIỂM TOÁN CODE THỰC TẾ — MIGHTY ANGLER v2.0 (`ARGON_CODE_AUDIT_V2`)

- **Ngày kiểm toán:** 2026-11-18
- **Người thực hiện:** Antigravity — Gemini 4 Argon (Principal Roblox Systems Architect & Security/Performance Auditor — Deep Adversarial Code Audit, **100% Read-Only trên `src/`**)
- **Phạm vi đối chiếu:** Toàn bộ `85` file `.luau` trong `src/` (`commit 127411f`), `tools/verify_project.ps1`, đối chiếu trực tiếp với `PLAN.md` và `docs/CODEX_CONSENSUS_STAMP.md`.

---

## 1. KẾT QUẢ KIỂM ĐỊNH TỰ ĐỘNG & KỶ LUẬT KÍCH THƯỚC FILE

### 1.1. Chạy `tools/verify_project.ps1`
- **Kết quả:** `Exit Code = 0` — **`[PASS] 6/6 chốt chặn kiểm định`** (Giới hạn `<= 350` dòng, Quét API nguy hiểm Part Shape / Terrain Material / `CFrame.Angles` / Module `return`, Rojo Sourcemap, `luau-lsp analyze`, `selene` linter, `rojo build` ra `build/mighty-angler-dev.rbxlx`).

### 1.2. Kiểm chứng trần dòng code (`<= 350` dòng cho 85 file & `< 310` dòng cho 5 file từng sát trần)
- **Toàn bộ 85 file `.luau`:** Đạt `100% <= 350` dòng (file cao nhất là `src/client/UI/Components/ViewportCard.luau` với `312` dòng non-empty / `341` tổng dòng; `ProgressionService.luau` `338` tổng dòng; `CurrencyService.luau` `334` tổng dòng).
- **5 file cam kết `< 310` dòng:**
  1. `src/client/UI/Panels/HudPanel.luau`: **`260` tổng dòng / `224` dòng lệnh** (`< 310`).
  2. `src/server/Services/PetsService.luau`: **`289` tổng dòng / `252` dòng lệnh** (`< 310`).
  3. `src/client/UI/Panels/ProgressPanel.luau`: **`274` tổng dòng / `245` dòng lệnh** (`< 310`).
  4. `src/client/UI/Panels/BagPanel.luau`: **`307` tổng dòng / `269` dòng lệnh** (Đạt `< 310` dòng theo cam kết chung mục 1 & 3 của `PLAN.md`, lưu ý cao hơn con số `< 250` ghi trong ngoặc ở dòng 130 `PLAN.md`).
  5. `src/server/Services/FishingService.luau`: **`301` tổng dòng / `259` dòng lệnh** (`< 310`).

---

## 2. BẢNG ĐỐI CHIẾU CAM KẾT KỸ THUẬT (NHỮNG HẠNG MỤC ĐÃ ĐẠT CHUẨN)

Trước khi liệt kê các lỗ hổng cần vá, dưới đây là các cơ chế cốt lõi đã được xác minh **đúng thiết kế trong code thực tế**:
- **Session Lock & Gia hạn khóa định kỳ (`DataService.luau:78-114, 275-310`):** Chiếm khóa khi `holder == nil or holder == SERVER_JOB_ID or lockAge > 120` (`SESSION_LOCK_EXPIRE_SEC = 120`), thử lại `3 lần × 1.5s`, vòng lặp `60s` (`AUTOSAVE_INTERVAL_SEC = 60`) luôn gọi `SaveProfile(player, false)` để gia hạn `lockTimestamp = os.time()` và tăng `saveSeq` kể cả khi `dirtyRevision` không đổi.
- **`MigrateProfileToV2` Idempotent (`ProfileMigrator.luau:25-63`):** Chạy lặp nhiều lần vẫn giữ nguyên `originalValue` (kể cả sau khi cá `soulbound` bị đưa `sellValue = 0`), giữ nguyên `sizeTier`, `midasBonus`, `locked`, và chỉ reset `playtimeTodaySec` / `playtimeClaimedToday` khi sang ngày UTC mới (`merged.playtimeDay ~= today`).
- **Bảo vệ cá `soulbound == true` & `locked == true` ở cả 4 luồng bán Gold (`CurrencyService.luau:159-297`):** `SellAllFish`, `SellSingleFish`, `SellSelectedFish`, `SellHeldFish` đều kiểm tra `isProtectedFromGoldSell` (`entry.soulbound == true or entry.locked == true`) trước khi xóa khỏi `fishBag`. Kể cả khi người chơi bấm mở khóa (`locked = false`) trên cá Trophy, cờ `soulbound == true` vẫn chặn bán Gold tuyệt đối.
- **Công thức `BuffAggregator` & Xoáy nước (`BuffAggregator.luau:68-137`, `FishingRoller.luau:117-130`, `RodsConfig.luau:248-266`):**
  - Cần Exclusive có `equipStrengthReq = 0`, tách biệt hoàn toàn với `masteryBaselineStrength = baseRod.strengthReq`.
  - `minigameWidth` kẹp trần `0.68` (`GameConfig.MINIGAME_MAX_WIDTH`) ở bước cuối cùng (`FishingSessionManager.luau:135`).
  - Xoáy nước (`inWhirlpool`) nhân `2.0x` vào `effectiveLuck` VÀ nhân `2.0x` trực tiếp vào trọng số cá `Boss` trước khi chuẩn hóa (`FishingRoller.luau:117-125`).
  - `midas_sovereign` lưu `midasBonus = 1.30` vào từng con cá (`FishingService.luau:81-93`), tính đúng 1 lần khi `Appraise` (`EnchantAndBountyService.luau:225-226`), và `20%` nâng `None`/`Shiny` lên `Golden` không bao giờ đè `Cosmic`/`Golden` (`FishingRoller.luau:169-173`).
- **4 Chế độ quăng cần & Cổng kép trước khi trừ mồi (`FishingService.luau:136-149, 179-188`):** Người sở hữu Gamepass `AutoFish` khi câu tay (`castMode = "Manual"`) trượt vạch xanh vẫn nhận `0%` bonus (`ManualNormal`). Cổng kép `effPower >= f.minRodPower and f.minWeight <= effMaxWeight` kiểm tra ngay đầu `StartCast`, từ chối trước khi chạm tới mồi câu.

---

## 3. DANH SÁCH LỖ HỔNG & SAI LỆCH PHÁT HIỆN TRONG CODE THỰC TẾ

### 🔴 [P0 - Critical / Data Loss / Exploit / Policy Compliance]

#### [P0-1] Ghi đè xóa trắng điểm Bảng Xếp Hạng Toàn Cầu (`OrderedDataStore`) khi người chơi rơi vào chế độ `loadFailedPlayers` (Read-Only Mode)
- **File + Dòng code:** `src/server/Services/LiveOpsService.luau:162-174` (phối hợp với `src/server/Services/DataService.luau:123-136`)
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Khi người chơi vào server lúc khóa phiên `activeSessionId` đang bận ở server cũ hoặc DataStore lỗi tạm thời (khi `game.PlaceId > 0`), `DataService` bật `loadFailedPlayers[player] = true` và cấp một hồ sơ tạm trong RAM (`GameConfig.CreateDefaultProfile()`) với **`strength = 0`** và **`stats.goldEarned = 0`**.
  - Mặc dù `DataService.SaveProfile` đã chặn ghi đè vào DataStore chính, vòng lặp `refreshLeaderboards()` mỗi `20s` trong `LiveOpsService.luau:162-174` lại duyệt toàn bộ `Players:GetPlayers()`, lấy `prof = DataService.Get(p)` và gọi thẳng:
    ```luau
    strStore:SetAsync(tostring(p.UserId), math.floor(prof.strength))
    goldStore:SetAsync(tostring(p.UserId), math.floor(prof.stats.goldEarned))
    ```
    mà **không kiểm tra `DataService.IsTransactionLocked(p)`**. Hệ quả: Một người chơi Top Server nếu chẳng may kết nối lại khi khóa phiên chưa nhả kịp sẽ bị `LiveOpsService` ghi đè `0` Strength và `0` Gold lên cả 2 bảng xếp hạng toàn cầu `MightyAngler_TopStr_v2` và `MightyAngler_TopGold_v2`!
- **Đề xuất cách sửa chuẩn xác:**
  - Trong `LiveOpsService.luau:166-172`, bắt buộc kiểm tra `if prof and not DataService.IsTransactionLocked(p, false) then` (và chỉ ghi khi `prof.strength > 0` hoặc dùng `UpdateAsync` với `math.max(oldVal or 0, newVal)` để không bao giờ hạ kỷ lục Leaderboard của người chơi).

---

#### [P0-2] Thiếu kiểm tra `PolicyService` (`ArePaidRandomItemsRestricted`) khi đập Trứng Pet bằng Gems (`HatchEgg`)
- **File + Dòng code:** `src/server/Services/PetsService.luau:110-156` (đặc biệt dòng `141-149`)
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Mục `O10` và `2.2(3)` của `PLAN.md` quy định: *"Tích hợp kiểm tra `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` để chặn quay ngẫu nhiên trả phí với người chơi thuộc vùng hạn chế"*.
  - Trong `EnchantAndBountyService.luau:50-57`, luồng xoay Enchant bằng Gems đã kiểm tra `if PerkService.ArePaidRandomItemsRestricted(player) then`.
  - Tuy nhiên, trong `PetsService.HandleHatchEgg` (`PetsService.luau:141-149`), khi người chơi mở các **Trứng Pet trả bằng Gems (`egg.currency == "Gems"`)**, Server gọi thẳng `CurrencyService.SpendGems(player, egg.cost)` và quay ngẫu nhiên `Util.PickWeighted(egg.pets, ...)` mà **hoàn toàn quên kiểm tra `PerkService.ArePaidRandomItemsRestricted(player)`**.
- **Đề xuất cách sửa chuẩn xác:**
  - Trong `PetsService.luau:141`, ngay đầu nhánh `else` (`egg.currency == "Gems"`), bổ sung kiểm tra `if PerkService.ArePaidRandomItemsRestricted(player) then` (báo Toast từ chối và `return` trước khi trừ Gems, giống hệt `EnchantAndBountyService.luau:51-57`).

---

#### [P0-3] Lỗ hổng điều kiện `oldData == nil` trong `SaveProfile`, nguy cơ kẹt `saveInFlight` ngoài `pcall`, tuần tự `BindToClose` và lỗi kẹt `saveSeq` khi `ResetProfileForDev`
- **File + Dòng code:** `src/server/Services/DataService.luau:157-192`, `216-227`, `261-273`
- **Mô tả lỗi / Kịch bản tái hiện:**
  1. **Sai lệch điều kiện `oldData ~= nil` trong `UpdateAsync` (`DataService.luau:170`):** `PLAN.md` mục `2.3(1)` quy định rõ: *"Bên trong `UpdateAsync(oldData)`: CHỈ ĐƯỢC GHI KHI `oldData ~= nil and oldData.activeSessionId == SERVER_JOB_ID`"*. Nhưng dòng `170` lại viết `if type(oldData) == "table" then ... end` — nếu `oldData == nil` (key bị xóa/evict), hàm bỏ qua hoàn toàn bước kiểm tra `activeSessionId` và ghi đè `snapshot`.
  2. **Nguy cơ kẹt vĩnh viễn `saveInFlight[player] = true` nếu lỗi xảy ra trước `pcall` (`DataService.luau:157-168`):** `saveInFlight[player] = true` được gán ở dòng `157`, trước khi thực hiện `local nextSeq = expectedSeq + 1` và `local snapshot = Util.DeepCopy(profile)` (dòng `160-161`) nằm ngoài `pcall`. Nếu có bất kỳ ngoại lệ nào trước dòng `168`, `saveInFlight[player]` không bao giờ được trả về `nil`, làm treo vĩnh viễn vòng lặp `while saveInFlight[player] do task.wait(0.05) end` ở mọi lần lưu sau và khi `PlayerRemoving`.
  3. **`BindToClose` chạy tuần tự từng người chơi & gọi trùng với `PlayerRemoving` (`DataService.luau:261-273`):** Khi tắt server, `PlayerRemoving` gọi `SaveProfile(player, true)` nhưng chỉ xóa `profiles[player] = nil` ở dòng `263` (*sau* khi `SaveProfile` xong). Cùng lúc đó `BindToClose` chạy vòng lặp tuần tự `for player, _ in pairs(profiles)` sẽ thấy `player` vẫn còn trong `profiles`, dẫn tới xếp hàng gọi `SaveProfile(player, true)` lần thứ 2 và chạy nối đuôi nhau (dễ chạm trần timeout 30s của `BindToClose` khi đông người chơi).
  4. **`ResetProfileForDev` làm tụt `saveSeq` về `0` (`DataService.luau:216-227`):** Khi bấm nút `[DEV] Reset Save` trong Studio có bật API DataStore (`PlaceId > 0`), `fresh = GameConfig.CreateDefaultProfile()` đặt lại `fresh.saveSeq = 0` trong khi trên DataStore `oldData.saveSeq` đang `>= 1`. Mọi lần `SaveProfile` tiếp theo đều bị chặn tại dòng `174` (`(tonumber(oldData.saveSeq) or 0) > expectedSeq`)!
- **Đề xuất cách sửa chuẩn xác:**
  - Dòng `170`: Sửa thành `if type(oldData) ~= "table" or oldData.activeSessionId ~= SERVER_JOB_ID or (tonumber(oldData.saveSeq) or 0) > expectedSeq then return nil end`.
  - Đưa toàn bộ khối tạo `snapshot` + `store:UpdateAsync` vào trong `pcall` (hoặc đặt `saveInFlight[player] = true` ngay sát `pcall`) để đảm bảo `saveInFlight[player] = nil` luôn được thực thi.
  - Thêm cờ `releasingLock: { [Player]: boolean }` để `PlayerRemoving` và `BindToClose` không gọi nhả khóa 2 lần cho cùng 1 người chơi, và dùng `task.spawn` + bộ đếm chờ song song trong `BindToClose`.
  - Trong `ResetProfileForDev`: giữ lại `fresh.saveSeq = profiles[player].saveSeq`.

---

#### [P0-4] Exploit gửi tọa độ `FishingCastWithAim` tùy ý & Tự động dịch chuyển nhân vật (`PivotTo`) xuyên đảo
- **File + Dòng code:** `src/server/Services/FishingService.luau:158-165`, `190-204` và `src/server/Services/FishingRoller.luau:24-48`
- **Mô tả lỗi / Kịch bản tái hiện:**
  1. **Exploit `hitWater = false` không kiểm tra khoảng cách và `NaN` (`FishingService.luau:158-165`):** Khi Client gửi `C2S_FishingCastWithAim` với `{ hitWater = false, targetPos = hitPos }`, Server chỉ kiểm tra `typeof(hitPos) == "Vector3"` rồi truyền thẳng vào `RodVisuals.PlayLandBounce(player, hitPos)`. Kẻ tấn công có thể truyền tọa độ chứa `NaN` (`Vector3.new(0/0, 0/0, 0/0)`) hoặc tọa độ cách xa hàng nghìn studs ở đảo khác để xả Part/Beam vào `Workspace`.
  2. **Bypass vật cản mặt cầu gỗ & tự động Teleport nhân vật (`FishingService.luau:190-200`, `FishingRoller.luau:24-48`):**
     - `ValidateAimedWaterPoint` trên Server chỉ kiểm tra tọa độ `(X, Z)` nằm trong hộp `FishingWater` và cách nhân vật `<= 82` studs, **không hề Raycast trên Server** để kiểm tra điểm đó có bị mặt cầu gỗ (`FishingDock`) che phía trên hay không.
     - Nghiêm trọng hơn, ở `FishingService.luau:193-200`, nếu `ValidateAimedWaterPoint` trả về `nil` (ví dụ người chơi cầm cần bấm nhầm lên bầu trời hoặc bấm ra ngoài tầm 82 studs khi đang đứng ở khu vực Gym/Quảng trường), thay vì báo quăng quá xa, Server lại tự động fallback sang `FindWaterCastPoint` và **dịch chuyển tức thời nhân vật ra mũi cầu cảng (`player.Character:PivotTo(CFrame.new(pierSpot)...)` ở dòng `198`)**!
- **Đề xuất cách sửa chuẩn xác:**
  - Ở nhánh `hitWater == false` (`FishingService.luau:158-165`): Kiểm tra `hitPos.X == hitPos.X and hitPos.Y == hitPos.Y and hitPos.Z == hitPos.Z` (chống `NaN`) và khoảng cách tới `HumanoidRootPart` `<= GameConfig.FISHING_MAX_WATER_DIST + 40` trước khi gọi `PlayLandBounce`.
  - Trong `ValidateAimedWaterPoint` (`FishingRoller.luau:24-48`): Thực hiện một `Workspace:Raycast` ngắn từ `Vector3.new(target.X, wCenter.Y + half.Y + 25, target.Z)` chiếu thẳng xuống `-30` studs (loại trừ `Character` và `OceanWhirlpools`, `IgnoreWater = false`) để xác nhận bề mặt chạm đầu tiên thực sự là `Enum.Material.Water`.
  - Trong `FishingService.StartCast` (`lines 190-204`): Khi quăng thủ công (`rawMode == "Manual"`), nếu `ValidateAimedWaterPoint` thất bại thì báo `tooFar` ngay, **bỏ đoạn `player.Character:PivotTo(pierSpot)`** (hoặc chỉ cho phép tự tìm điểm nước gần khi đang đứng sẵn gần bờ).

---

### 🟠 [P1 - Gameplay Logic / Spec Drift vs PLAN.md / Memory Leak]

#### [P1-1] Rò rỉ hiệu năng / Tái tạo toàn bộ 65 `ViewportFrame` 3D trong `IndexGridSection` mỗi khi `ProgressionUpdated` bắn về
- **File + Dòng code:** `src/client/UI/Components/IndexGridSection.luau:19-119` và `src/client/UI/Panels/ProgressPanel.luau:44-50, 131, 189, 253-264`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Trái với `BagPanel`, `ShopPanel` và `PetsPanel` (nơi `ViewportPool.CreateGrid` chỉ được gọi **1 lần duy nhất** lúc `Mount` để tái sử dụng các ô thẻ), `ProgressPanel.Render()` lại gọi `clearBody(w.body)` xóa trắng toàn bộ cây con ở dòng `131`, sau đó `IndexGridSection.Render()` gọi mới **`ViewportPool.CreateGrid(body, 1, ...)` ở dòng `58` trong mỗi lần Render**!
  - Khi người chơi đang mở tab `Index` (hoặc chuyển qua lại các tab trong `ProgressPanel`), mỗi lần câu được 1 con cá, tập 5 nhịp Gym, hoặc nở 1 quả trứng, gói `ProgressionUpdated` bắn về (`ProgressPanel.luau:253-264`) sẽ gọi `ProgressPanel.Render()`, **phá hủy và dựng mới từ đầu 65 `ViewportFrame` + 65 `Camera` + 130 `RBXScriptConnection` + 65 mô hình 3D (~600 BasePart)**, gây khựng khung hình (frame spike) rõ rệt trên thiết bị di động.
  - Ngoài ra, `ViewportPool.luau` hiện đang tạo thẻ cho toàn bộ phần tử trong mảng `specs` cùng lúc chứ chưa giới hạn theo vùng nhìn cuộn (virtualized scroll window) như mô tả ở mục `3.2` của `PLAN.md`.
- **Đề xuất cách sửa chuẩn xác:**
  - Tách riêng một `indexContainer: Frame` cố định và khởi tạo `indexGridHandle = ViewportPool.CreateGrid(...)` **đúng 1 lần duy nhất**; khi chuyển sang tab khác chỉ ẩn `indexContainer.Visible = false`, và khi ở tab `Index` chỉ gọi `indexGridHandle.SyncItems(specs, focusedIndexKey)` để tái sử dụng 100% mô hình 3D theo `modelSignature`.

---

#### [P1-2] `AppraiseFish` có thể làm tụt bậc `sizeTier` (từ `Titanic`/`Giant` về `Normal`) và giảm 66% giá trị cá dù cân nặng giữ sàn `>= 85%`
- **File + Dòng code:** `src/server/Services/EnchantAndBountyService.luau:214-234`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Trong `handleAppraiseFish`:
    ```luau
    local newTier, rolledW, tierValMult = FishingRoller.RollSizeTierAndWeight(fishDef, effRod.maxWeight, mults.titanWeightFactor)
    local newWeight = math.max(math.floor(entry.weight * 0.85 * 10 + 0.5) / 10, rolledW)
    ...
    entry.sizeTier = newTier
    entry.weight = newWeight
    ```
  - Giả sử người chơi mang một con cá **`Titanic`** (`tierValMult = 3.00`, `scaleMult = 2.15`, nặng `100 kg`) đi Appraise để thử vận may lên đột biến hoặc tăng cân. Nếu lượt roll rơi vào `75%` tỉ lệ ra bậc `"Normal"` (`tierValMult = 1.00`, `scaleMult = 1.00`), thì dù `newWeight` được bảo vệ ở mức sàn `85 kg` (`>= 0.85 * oldWeight`), nhãn `entry.sizeTier` vẫn bị ghi đè thành `"Normal"` và `tierValMult` tụt từ `3.00` xuống `1.00`!
  - Hệ quả: Con cá bị mất nhãn `Titanic`, mô hình cầm trên tay (`PetAndFishVisuals.luau:101-108`) bị teo nhỏ từ `2.15x` về `1.00x`, và giá bán (`sellValue` / `originalValue`) bị bốc hơi **66%**!
- **Đề xuất cách sửa chuẩn xác:**
  - Bổ sung bảng thứ tự bậc kích thước (`Normal = 1, Big = 2, Giant = 3, Titanic = 4`). Khi `newWeight` được giữ bởi sàn `0.85 * entry.weight` (hoặc theo quy tắc không hạ bậc kích thước khi Appraise), giữ nguyên `sizeTier` và `tierValMult` cũ nếu `newTier` có thứ hạng thấp hơn `entry.sizeTier` hiện tại.

---

#### [P1-3] Kiểm tra khoảng cách `AppraiseFish` sai tâm (cho phép Appraise từ mọi nơi trên đảo)
- **File + Dòng code:** `src/server/Services/EnchantAndBountyService.luau:26-34, 174`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - `PLAN.md` mục `2.2(3)` yêu cầu: *"kiểm tra khoảng cách tới NPC và quyền sở hữu `uid`"*.
  - Hàm `isNearIslandCenterOrCollector` (`EnchantAndBountyService.luau:26-34`) lại tính `(root.Position - islDef.centerPosition).Magnitude <= 145`. Bán kính `145` studs tính từ tâm đảo bao phủ toàn bộ hòn đảo (từ khu Gym đến tận mũi cầu gỗ), nên người chơi đứng ở đâu trên đảo cũng bắn Remote `C2S_AppraiseFish` được mà không cần đứng gần NPC Old Man Finn (`islDef.centerPosition + Vector3.new(-11, 0, 48.2)`).
- **Đề xuất cách sửa chuẩn xác:**
  - Tính khoảng cách tới đúng vị trí của NPC Collector (`islDef.centerPosition + Vector3.new(-11, 0, 48.2)`) với bán kính hợp lý (`<= 28` studs), đồng thời kiểm tra tương tự cho `TurnInBounty` và `RollEnchant`.

---

#### [P1-4] Tường chắn vô hình ngoài khơi (`OceanBoundS/W/E`) để `CanQuery = true`, làm phao câu nảy giữa không trung trên mặt biển
- **File + Dòng code:** `src/server/World/WorldBuilder.luau:137-139` và `src/client/Controllers/HotbarAndCastController.luau:47-75`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Trong `WorldBuilder.luau:137-139`, 3 bức tường chặn vô hình quanh hồ biển (`OceanBoundS`, `OceanBoundW`, `OceanBoundE`, cao `24` studs từ `Y = 4` đến `Y = 28`, `Transparency = 1`) được tạo bằng `PartFactory.Block` với `CanQuery = true` mặc định.
  - Khi người chơi đứng ở mũi cầu cảng (`Z = c.Z + 117`) và giữ chuột ngắm quăng phao ra vùng nước phía xa (`Z ≈ c.Z + 160..173` hoặc hai bên mép Đông/Tây), tia `Workspace:Raycast` từ Camera (`HotbarAndCastController.luau:67`) đâm trúng bức tường vô hình `OceanBoundS/W/E` ở độ cao trên mặt nước (`hit.Material = Enum.Material.SmoothPlastic ~= Enum.Material.Water`).
  - Hệ quả: Phao câu nảy tưng giữa không trung ngay trên mặt biển và báo lỗi *"💥 Bobber bounced off dry land! Aim at the ocean water!"*.
  - Ngoài ra, `excludeList` trong `HotbarAndCastController.luau:57-65` mới chỉ loại trừ `localPlayer.Character` và `OceanWhirlpools`, chưa loại trừ nhân vật của người chơi khác đang đứng chen chúc trên mũi cầu gỗ hoặc thư mục `ClientRenderedPets`.
- **Đề xuất cách sửa chuẩn xác:**
  - Đặt `CanQuery = false` cho cả 3 tường vô hình `OceanBoundS`, `OceanBoundW`, `OceanBoundE` trong `WorldBuilder.luau:137-139`.
  - Trong `HotbarAndCastController.luau:57-65`, thêm `ClientRenderedPets` và `Character` của tất cả người chơi trong `Players:GetPlayers()` vào `excludeList`.

---

#### [P1-5] Kẹt trạng thái `Auto-Fish` (nút vẫn báo `ON` màu xanh nhưng ngừng quăng) sau khi Đổi đảo, Rebirth, Hủy quăng hoặc Chết
- **File + Dòng code:** `src/client/Controllers/FishingController.luau:168-178`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Khi người chơi đang bật `Auto-Fish: ON` và thực hiện một trong các hành động: dịch chuyển sang đảo khác (`IslandService.HandleTravel`), `Rebirth` (`ProgressionService.handleDoRebirth`), bấm `✖ REEL IN`, hoặc nhân vật bị chết (`Humanoid.Died`), Server gọi `CloseSessionOnce` và gửi gói `S2C_FishingStateReset` với `reason = "Cancel"` hoặc `reason = "Died"`.
  - Tại `FishingController.luau:168-178`, trình xử lý `FishingStateReset` chỉ tắt `autoFishEnabled = false` khi `payload.bagFull or payload.tooFar or payload.weakRod or payload.reason == "Unequip"`, nhưng với `reason == "Cancel"` hoặc `"Died"`, nó **không tắt `autoFishEnabled` mà cũng không gọi `scheduleSingleAutoRecast()`**!
  - Hệ quả: Sau khi chuyển đảo, Rebirth hoặc hồi sinh, nút trên HUD vẫn hiển thị **`🎣 AUTO-FISH: ON` (màu xanh lá)** nhưng nhân vật đứng im vĩnh viễn không quăng cần lượt tiếp theo!
- **Đề xuất cách sửa chuẩn xác:**
  - Trong `FishingController.luau:168-178`: Nếu `payload.reason == "Cancel"` do người chơi bấm `CancelCurrentCast` thì tắt `autoFishEnabled = false`; còn nếu phiên bị đóng do chuyển đảo / Rebirth / hồi sinh mà `autoFishEnabled == true` và đang cầm cần ở ô `[1]`, gọi `scheduleSingleAutoRecast()` (sau `1.1s`) để tiếp tục chu kỳ Auto-Fish mượt mà.

---

#### [P1-6] Thiếu bảng xác suất `%` thực tế đang hiệu lực trên UI Câu cá / Bệ Enchant & Mô tả thẻ Gamepass bị cắt cụt (Cam kết O10 & mục 2.2(3) `PLAN.md`)
- **File + Dòng code:** `src/client/UI/Panels/HudPanel.luau:68-88`, `src/client/UI/Panels/EnchantAndBountyModal.luau:194-204`, `src/client/UI/Panels/PetsPanel.luau:130-145`, `src/client/UI/Panels/ShopPanel.luau:125-147`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Đối chiếu mục `O10` và `2.2(3)` của `PLAN.md`: *"Hiển thị bảng `%` gốc VÀ xác suất `%` thực tế đang hiệu lực (sau khi áp dụng `Auto-Fish Pro`, Cần câu đang cầm, Mồi, Thuốc, Xoáy nước) ngay trên UI câu cá / Trứng Pet / Bệ `Enchant Altar` và hộp mô tả trước khi mua `Auto-Fish Pro` / `ExclusiveDragonRod`."*
  - Kiểm tra thực tế trong code:
    1. **Trên UI câu cá (`HudPanel.luau` / `IslandsModal.luau`):** Mới chỉ hiển thị tổng `+%d%% Luck` trên 1 dòng chữ nhỏ, **chưa có bảng/dòng đối chiếu `%` gốc vs `%` thực tế đang hiệu lực** của các bậc cá (`Common..Boss`) và đột biến khi cầm cần / dùng mồi / bật `Auto-Fish Pro` / quăng vào Xoáy nước.
    2. **Trên Bệ `Enchant Altar` (`EnchantAndBountyModal.luau:194-204`):** Chỉ in cứng `e.chance * 100` (`28%, 26%, 20%, 13%, 9%, 4%`), trong khi hàm `EnchantsConfig.RollEnchant(prevEnchant)` loại trừ dòng đang có trên cần (`0%`) và chuẩn hóa lại tổng xác suất của 5 dòng còn lại! UI chưa hiển thị xác suất `%` thực tế sau khi loại trừ dòng đang active.
    3. **Trên thẻ Trứng Pet (`PetsPanel.luau:130-142`):** Chỉ ghi `"Odds: 60% / 30% / 10%"` mà không ghi tên/bậc Pet tương ứng với từng mức `%`.
    4. **Tại tab `Passes` (`ShopPanel.luau:125-147`):** Dùng chung ô nhỏ `ViewportCard` (`subLbl` cao `15px` một dòng duy nhất, `TextTruncate.AtEnd`), khiến mô tả của `Auto-Fish Pro` và `Seraphim Dragon Rod` bị cắt cụt thành `"100% Perfect Auto-Ca..."` và chưa có khung thông tin chi tiết trước khi bấm mua.
- **Đề xuất cách sửa chuẩn xác:**
  - Hiển thị rõ dòng đối chiếu **`Base Odds vs. Your Effective Odds`** ngay trên `HudPanel` / `IslandsModal` (hoặc bảng thông tin câu cá), hiển thị cả `% gốc` và `% thực tế (Re-normalized)` trên từng dòng trong `EnchantAndBountyModal.luau:199`, ghi rõ bậc hiếm kèm `%` trên `PetsPanel`, và thêm hộp thông tin chi tiết đầy đủ ở đầu tab `Passes` trong `ShopPanel`.

---

#### [P1-7] `TurnInBounty` và `UnlockExclusiveRod("RelicTrident")` có thể tự động nuốt mất cá `locked == true` hoặc `soulbound` giá trị cao
- **File + Dòng code:** `src/server/Services/EnchantAndBountyService.luau:120-145, 262-286` và `src/client/UI/Panels/EnchantAndBountyModal.luau:87-102, 146`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Khi người chơi bấm đổi `Abyssal Relic Trident` (`EnchantAndBountyModal.luau:146`), Client truyền `bossFishUid = nil`. Server (`EnchantAndBountyService.luau:121-129`) duyệt từ đầu `profile.fishBag` và xóa ngay con cá Boss Đảo 3+ đầu tiên tìm thấy, **kể cả khi con cá Boss đó đang được người chơi khóa (`locked == true`) hoặc là cá `Soulbound Trophy` / `Titanic Cosmic` quý hiếm**!
  - Tương tự, ở tab `Bounties`, hàm `findBestMatchingFishForBounty` (`EnchantAndBountyModal.luau:87-102`) lấy ngay con cá đầu tiên trong túi thỏa điều kiện mà không ưu tiên cá chưa khóa (`locked == false`) hoặc cá có giá trị thấp nhất.
- **Đề xuất cách sửa chuẩn xác:**
  - Trong `handleUnlockExclusiveRod("RelicTrident")`: Từ chối tiêu thụ cá có `locked == true` hoặc `soulbound == true` (chỉ nhận cá Boss thường đã mở khóa, đúng cam kết `PLAN.md` dòng 120: *"Cá soulbound chỉ có thể tiêu thụ hợp lệ khi người chơi chủ động chọn nộp vào Nhiệm vụ Đổi Cá (Fish Bounty)"*).
  - Trong `findBestMatchingFishForBounty`: Ưu tiên chọn con cá thỏa điều kiện có `locked == false`, `soulbound == false` và `originalValue` thấp nhất (hoặc cho phép người chơi chọn đích danh con cá muốn nộp).

---

#### [P1-8] Rò rỉ Model Pet 3D và Connection trong `ClientPetRenderer` khi người chơi rời phòng sát lúc `CharacterAdded`
- **File + Dòng code:** `src/client/Controllers/ClientPetRenderer.luau:55-65, 111-121`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Trong `watchPlayer(player)`:
    ```luau
    player.CharacterAdded:Connect(function()
        task.wait(0.25)
        playerSignatures[player] = nil
        rebuildPetsForPlayer(player)
    end)
    ```
  - Các kết nối `GetAttributeChangedSignal` và `CharacterAdded` không được lưu lại để `Disconnect()` khi `PlayerRemoving`.
  - Nếu một người chơi rời server trong khoảng `0.25s` ngay sau khi `CharacterAdded` kích hoạt (`PlayerRemoving` đã chạy xong `clearPetsForPlayer(player)`), thì sau `0.25s` coroutine thức dậy và gọi `rebuildPetsForPlayer(player)` mà **không kiểm tra `player:IsDescendantOf(Players)`**, tạo ra tới 4 mô hình Pet 3D mồ côi nằm vĩnh viễn trong `Workspace.ClientRenderedPets`!
- **Đề xuất cách sửa chuẩn xác:**
  - Thêm `if not player:IsDescendantOf(Players) then return end` ngay đầu `rebuildPetsForPlayer(player)`, và lưu mảng `RBXScriptConnection` theo `player` để `Disconnect()` sạch sẽ trong `clearPetsForPlayer(player)`.

---

#### [P1-9] Lệch trục gắn Đòn Tạ (`BenchPress Barbell`) và Quả Tạ (`Dumbbells`) trên R15/R6 khi tập Gym
- **File + Dòng code:** `src/server/World/PlayerVisuals.luau:171-206` và `src/shared/ModelBuilders/RodAndWeightBuilder.luau:115-161`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Với `BenchPress` (`PlayerVisuals.luau:190-205`), thanh đòn tạ dài `5.8` studs (`BarShaft`) chỉ được hàn (`WeldConstraint`) vào bàn tay phải (`rHand`) với độ lệch `CFrame.new(-1.1, -0.15, -0.25)`. Khi `AnimationController.PlayGymRep("BenchPress")` (`AnimationController.luau:182-188`) xoay vai phải nghiêng góc `Z = -14°` rồi `-20°`, đầu bên trái của đòn tạ dài `5.8` studs bị văng chéo xuyên qua đầu/ngực nhân vật thay vì nằm ngang cân đối qua hai bàn tay.
  - Với nhân vật R6 (`Right Arm` / `Left Arm` dài `2.0` studs), vị trí bàn tay nằm ở `Y = -0.95` (như đã xử lý đúng trong `RodVisuals.luau:55-57`), nhưng `PlayerVisuals.luau:175, 192` lại dùng cứng `Y = -0.18` và `-0.15`, khiến quả tạ gắn lệch lên giữa bắp tay trên R6.
- **Đề xuất cách sửa chuẩn xác:**
  - Với `BenchPress`: Gắn/weld thanh đòn tạ theo `UpperTorso`/`Torso` (hoặc căn góc ngang cố định phía trước ngực và nâng hạ theo nhịp đẩy) để đòn tạ luôn song song với vai, và áp dụng offset `Y = -0.95` khi phát hiện R6 (`hand.Name == "Right Arm" or hand.Name == "Left Arm"`).

---

#### [P1-10] Vòng lặp `RunService.Heartbeat` 60Hz chạy trên Server cho 20 NPC và 8 cá xoáy nước gây tốn băng thông mạng không cần thiết
- **File + Dòng code:** `src/server/World/NpcBuilder.luau:34-49` và `src/server/World/WhirlpoolManager.luau:186-201`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - `NpcBuilder` cập nhật `CFrame` của `torso` và `rightArm` cho toàn bộ 20 NPC (4 NPC × 5 đảo = 40 Part) ở mỗi nhịp `Heartbeat` trên **Server**.
  - `WhirlpoolManager` cập nhật `CFrame` của 8 `ShadowFish` ở mỗi nhịp `Heartbeat` trên **Server**.
  - Việc thay đổi `Part.CFrame` liên tục 60 lần/giây trên Server buộc Roblox Engine phải đồng bộ ~2.880 gói CFrame/giây qua mạng tới mọi Client (kể cả các NPC ở Đảo 2–5 khi không có ai đứng gần).
- **Đề xuất cách sửa chuẩn xác:**
  - Giảm nhịp cập nhật trên Server hoặc chuyển diễn hoạt thở/vẫy tay của NPC và xoay bóng cá Whirlpool sang Client (hoặc chỉ cập nhật khi có người chơi đứng trên đảo đó), giúp giảm tải 100% băng thông replication.

---

### 🟡 [P2 - Polish / UX / Spec Drift Nhỏ / Edge Case]

#### [P2-1] Sai lệch tiêu chí phụ khi sắp xếp 12 cá `Soulbound Trophy` giữa Client Preview và Server Rebirth + Cắt chữ danh sách 12 cá
- **File + Dòng code:** `src/client/UI/Panels/ProgressPanel.luau:97-101, 164-165` vs `src/server/Services/ProgressionService.luau:119-126`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Trên Server (`ProgressionService.luau:119-126`), khi hai cá `locked` có cùng `originalValue`, `table.sort` phân định bằng `return a.weight > b.weight`. Nhưng trên Client (`ProgressPanel.luau:97-101`), hàm sort chỉ viết `return oa > ob` (thiếu nhánh so sánh `a.weight > b.weight`), dẫn tới nguy cơ danh sách 12 cá hiển thị xem trước trên UI khác với 12 cá thực tế được giữ khi có nhiều cá trùng giá trị.
  - Ngoài ra, ô hiển thị danh sách 12 cá Trophy (`ProgressPanel.luau:165`) có chiều cao cố định `92px` và `s.Size = UDim2.new(0.70, 0, 1, -32)`, nên khi nối tên + cân nặng + `[Slot X]` của 12 con cá sẽ bị tràn khung ở màn hình nhỏ.
- **Đề xuất cách sửa chuẩn xác:**
  - Đồng bộ hàm sort trên `ProgressPanel.luau:97-101` giống hệt Server (`if oa ~= ob then return oa > ob end return (tonumber(a.weight) or 0) > (tonumber(b.weight) or 0)`), và tăng chiều cao/dùng `AutomaticSize` cho khung xem trước danh sách Trophy.

---

#### [P2-2] Trần cân nặng `titan_line` trong `FishingRoller.RollSizeTierAndWeight` dùng `math.max(fishDef.maxWeight, ...)` thay vì `math.min`
- **File + Dòng code:** `src/server/Services/FishingRoller.luau:147-149`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Mục `2.1(C)(4)` của `PLAN.md` quy định: `kẹp trần min(weight, effectiveRod.maxWeight * 1.25)`.
  - Trong `FishingRoller.luau:148`, code viết `local finalCap = math.max(fishDef.maxWeight, effMaxWeight * capMult)`. Khi người chơi câu một loài cá có `fishDef.maxWeight > effMaxWeight * 1.25` (ví dụ cầm cần `Twig 15 kg` câu `Sunset Barracuda` có `minWeight = 9 kg <= 15 kg` nhưng `maxWeight = 22 kg > 18.75 kg`), phép `math.max` cho phép cá nặng tới `22 kg`, vượt quá trần `effMaxWeight * 1.25` (`18.75 kg`) của cần câu.
- **Đề xuất cách sửa chuẩn xác:**
  - Sửa dòng `148` thành `local finalCap = effMaxWeight * capMult` (đúng công thức `min(scaledKg, effectiveRod.maxWeight * capMult)`).

---

#### [P2-3] Hướng dẫn tân thủ (`TutorialController.luau`) còn nhắc tên nút cũ của bản v1 (`[🎣 CAST ROD]` & `[💰 SELL ALL]`)
- **File + Dòng code:** `src/client/Controllers/TutorialController.luau:31, 33`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - Dòng `31` hiện `"Walk onto the Wooden Pier & click [🎣 CAST ROD]!"` và dòng `33` hiện `"Click [💰 SELL ALL]..."`, trong khi ở bản Đại Tu 2.0 hai nút này đã được thay bằng thao tác **cầm Cần ở ô `[1]` và nhấn giữ chuột xuống mặt nước biển** cùng giao diện **NPC Captain Barnaby / Bag Panel**.
- **Đề xuất cách sửa chuẩn xác:**
  - Cập nhật chuỗi văn bản ở dòng `31` và `33` khớp 100% với cơ chế Hotbar `[1]` + giữ chuột quăng phao và bán cá tại Captain Barnaby / `[🎒 Bag]`.

---

#### [P2-4] Xung đột `Camera.FieldOfView` giữa `NpcDialogueModal`, `MinigameBar` và độ lệch góc `PunchCamera`
- **File + Dòng code:** `src/client/UI/Components/NpcDialogueModal.luau:35-42`, `src/client/Controllers/FishingController.luau:104-113`, `src/client/Controllers/SoundAndFxController.luau:68-79`
- **Mô tả lỗi / Kịch bản tái hiện:**
  - `PunchCamera` (`SoundAndFxController.luau:75-77`) xoay Camera lên `+deg` rồi chỉ trả về `-deg * 0.6`, để lại độ lệch `+0.4 * deg` sau mỗi lần bắt cá hiếm/mở trứng.
  - Nếu hộp thoại NPC đóng lại trong lúc `MinigameBar` đang mở, `NpcDialogueModal.Close()` ép `FieldOfView = 70` đè lên mức zoom `64` của Minigame.
- **Đề xuất cách sửa chuẩn xác:**
  - Trong `PunchCamera`, trả góc xoay về đúng `-deg` (hoặc dùng hai bước `-0.6 * deg` và `-0.4 * deg`), và kiểm tra `MinigameBar.IsOpen()` trước khi trả `FieldOfView` về `70`.

---

## 4. KẾT LUẬN KIỂM TOÁN CHỐT CUỐI

> ### 🛠️ KẾT LUẬN: **`CẦN BẢN VÁ HOTFIX VÒNG CUỐI`**

**Đánh giá tổng thể của Kiến trúc sư trưởng (Argon):**
- Nền tảng kiến trúc v2.0 của dự án (`85` file `.luau`, phân tách module gọn gàng `<= 350` dòng, `luau-lsp` + `selene` + `rojo build` đạt `[PASS] 6/6`, cơ chế Session Lock cốt lõi, bảo vệ `Soulbound Trophy` qua 4 luồng bán Gold, Minigame sóng tam giác tất định, `BuffAggregator` và hệ thống 5 Đảo) đã được xây dựng rất bài bản.
- Tuy nhiên, để đạt chuẩn **Production-Grade An Toàn Tuyệt Đối**, dự án **bắt buộc phải thực hiện một vòng Hotfix ngắn gọn** nhằm xử lý dứt điểm **4 mục `[P0]`** (chặn `LiveOpsService` ghi đè `0` điểm lên `OrderedDataStore` khi `loadFailedPlayers`, bổ sung kiểm tra `PolicyService` cho Trứng Gems trong `PetsService`, khóa chặt điều kiện `oldData ~= nil` & `pcall` trong `DataService`, khóa kiểm tra tọa độ/bỏ tự động teleport trong `FishingService`) cùng các mục **`[P1]`** (tái sử dụng `GridHandle` trong `IndexGridSection` tránh dựng lại 65 Viewport 3D, giữ bậc `sizeTier` khi `Appraise`, chặn `RelicTrident` nuốt cá `locked`/`soulbound`, tắt `CanQuery` trên tường biển vô hình `OceanBoundS/W/E`, và giữ nhịp `Auto-Fish` sau khi chuyển đảo).
