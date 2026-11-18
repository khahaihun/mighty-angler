# PLAN.md — MIGHTY ANGLER 2.0 (Major Game-Feel, Visual & Systems Overhaul)

> **Nguồn sự thật duy nhất (Single Source of Truth)** của dự án tại `D:\Projects\mighty-angler`, đã qua **Hội Nghị Phản Biện Chéo 2 AI (Antigravity ↔ OpenAI Codex `gpt-6.2-astra`)**.
> - **Ngày cập nhật:** 2026-11-18
> - **Trạng thái nền tảng:** Bản khung v1.0 (`commit 118e101`, **62 file `.luau`** trong `src/`, PASS 6/6) đang chạy ổn định. Tài liệu này quy định **Đại Kế Hoạch Đại Tu 2.0 (Phase 2 Overhaul)** lột xác toàn diện dự án thành **Game Roblox Simulator thực thụ** chuẩn **Fisch × Pets GO! × Arm Wrestle Simulator**.
> - **Kỷ luật kỹ thuật bất biến:** Mọi file `.luau` **≤ 350 dòng** (5 file đang sát trần `331–336` dòng sẽ được tách bớt helper về `< 310` dòng ngay khi chạm tới), Server-Authoritative 100%, không xóa file tùy tiện, chạy `tools/verify_project.ps1` đạt `[PASS] 6/6` sau mỗi mục con.

---

## 1. MỤC TIÊU ĐẠI TU 2.0 & 10 QUYẾT ĐỊNH CỐT LÕI ĐÃ CHỐT

| Mã | Hạng mục | Quy tắc chốt chính thức |
|----|----------|-------------------------|
| **O1** | **Hotbar & Cầm Cần / Cầm Cá Khoe** | Ẩn Backpack mặc định của Roblox; dựng **Custom Hotbar** dưới đáy màn hình (`Phím 1..5`). Ô `[1]` để rút/cất Cần câu. Các ô `[2..5]` cho phép ghim tối đa 4 con cá trong túi để **rút cá ra cầm trên 2 tay khoe khắp đảo** (tỷ lệ kích thước thật theo bậc *Normal / Big / Giant / Titanic* + hiệu ứng đột biến). |
| **O2** | **Cầm Cần Bấm Màn Hình & Nảy Đất** | Bỏ nút `CAST ROD`. Khi đang cầm Cần câu trên tay, **nhấn/giữ chuột (hoặc chạm màn hình)** để nạp thanh lực *Cast Power* rồi thả ra quăng phao theo quỹ đạo parabol. **Điểm va chạm đầu tiên quyết định kết quả:** chạm `Terrain Water` trong vùng câu đảo → nổ bọt sóng, phao dập dềnh; chạm **Đất liền / Mặt cầu gỗ / Đá** (kể cả khi bên dưới cầu có nước) → phao **nảy tưng 1–2 nhịp**, tung bụi + tiếng *cộc*, đầu cần giật nhẹ rồi thu dây về ngay, không trừ mồi. |
| **O3** | **Bảng 4 Chế Độ Quăng Cần (Manual vs. Auto Free vs. Auto Pro)** | 1. **Câu tay thường (thả ngoài vạch Perfect):** `castLuckAdd = 0%`, `castLureAdd = 0%` *(kể cả khi sở hữu Gamepass Auto Pro — quăng tay vẫn do kỹ năng căn tay quyết định!)*.<br>2. **Câu tay Perfect (`holdRatio ∈ [0.78, 0.95]`):** `castLuckAdd = +25%`, `castLureAdd = +15%`.<br>3. **Auto-Fish Free (Miễn phí cho mọi người):** Không giữ thanh lực, `castLuckAdd = 0%`, `castLureAdd = 0%`, nhịp quăng lại `1.10s`.<br>4. **Auto-Fish Pro (Gamepass `AutoFishPro` — giữ nguyên/ánh xạ `GamepassId` của `AutoFish` cũ):** Mọi lượt quăng tự động đạt chuẩn Perfect (`castLuckAdd = +25%`, `castLureAdd = +15%`), nhịp quăng lại nhanh `0.45s`. |
| **O4** | **Minigame Chống Gian Lận & Chống Kẹt AFK** | Hạn bấm của người chơi tính theo số vòng: **`timeoutSec = 5.5 + rounds * 2.0`** (`Rare` 1 vòng = `7.5s`, `Epic/Legendary` 2 vòng = `9.5s`, `Boss` 3 vòng = `11.5s`), trong khi hẹn giờ tự đóng trên Server lùi thêm **`+0.40s` ân hạn mạng (`serverCloseDelay = timeoutSec + 0.40s`)** để cú bấm hợp lệ ở sát giây cuối vẫn kịp bay về Server. Client gửi từng cú bấm theo từng vòng (`FishingMinigameStrike`), Server đối chiếu đồng hồ thật & sóng tam giác tất định; hết hạn thì `CloseSessionOnce` đóng phiên đúng 1 lần và **duy nhất 1 bộ điều phối Auto-Fish quăng lượt tiếp theo** (không kẹt màn hình qua đêm). |
| **O5** | **Bố cục Cụm Mồi Nhanh & Nút Auto** | • **Góc dưới bên phải:** Ô **Chọn Mồi Nhanh (`Bait Selector`)** hiện mồi đang gắn + số lượng; bấm vào xổ ngược danh sách mồi đang có để đổi tức thì.<br>• **Ngay phía trên Hotbar:** Đặt gọn 2 nút pill **`🏋️ Auto-Train`** và **`🎣 Auto-Fish`**. |
| **O6** | **Túi Đồ Ô Lưới 3D, Khóa Cá & Bán Chọn Lọc** | `Bag`, `Shop`, `Pets`, `Index` chuyển sang **Lưới Thẻ Vuông (`UIGridLayout` + `ViewportPool`)**: hình 3D con cá/pet/cần ở giữa ô, thông số cân nặng/giá tiền gọn dưới đáy. Hỗ trợ **`🔒 Lock/Unlock`**, *Auto-Lock* cá hiếm/đột biến, chế độ **`Multi-Select` chọn nhiều cá để bán**, **`Sell Held Fish`** và **`Sell All Unlocked`**. |
| **O7** | **NPC Người Thật R15, Hội Thoại & Thẩm Định / Đổi Cá** | Thay NPC khối thô bằng **4 NPC R15 người thật** có trang phục, cử động thở/vẫy tay và **Khung Hội Thoại đa lựa chọn** (mở rồi đóng thoại giữ nguyên 100% túi cá, không tự bán như bản cũ): *Merchant* (bán lẻ/bán cá cầm tay/bán hết cá mở khóa), *Shop & Crafter*, *Appraiser & Collector* (thẩm định cá + bảng nhiệm vụ nộp cá *Fish Bounty*), *Gym Coach*. |
| **O8** | **5 Chỉ Số Cần Câu + 3 Cần Exclusive (`115%–130%`) & Xoay Dòng `Enchant`** | • Mọi cần câu có **5 chỉ số:** `Max Weight (kg)`, `Lure Speed`, `Luck`, `Control`, `Steadiness`.<br>• **6 Cần thường:** Không xoay dòng.<br>• **3 Cần Exclusive (`115% / 122% / 130%`):** Ăn hệ số động theo cây Cần thường mạnh nhất đang sở hữu, giữ vĩnh viễn qua Rebirth và **độc quyền mở Ô Xoay Dòng Phù Phép (`Enchant Altar`)**. |
| **O9** | **Thế Giới Sống Động & Khoe Đẳng Cấp (`Social Flex`)** | • Đổ **Nước biển sóng thật (`Terrain:FillBlock` cục bộ)**, địa hình 5 đảo đa tầng + **Xoáy Nước Cá Hiếm (`Ocean Whirlpools`)** ngoài khơi.<br>• Nhân vật có **Overhead Rank Title**, vòng **Aura** theo mốc Strength/Rebirth, và **2 tay cầm quả tạ 3D / đòn tạ thật** khi tập Gym. |
| **O10** | **Quà Online Ngày UTC, Minh Bạch Xác Suất & Tối Ưu Máy Yếu** | Bổ sung **Hộp Quà Online 9 mốc cộng dồn theo ngày UTC** (`playtimeDay` + `playtimeTodaySec` + mảng `playtimeClaimedToday` lưu bền trên Server), hiệu ứng **Đập Trứng nứt vỏ**, dấu **`!`** cá đớp + **Cần uốn cong & Camera Zoom nhẹ**, bảng **Settings (`Auto-Lock` + `Low GFX`)**, hiển thị bảng `%` xác suất gốc **kèm xác suất thực tế đang hiệu lực** khi bật `Auto-Fish Pro` / cầm cần tăng Luck + kiểm tra `PolicyService` chuẩn quy định Roblox. |

---

## 2. ĐẶC TẢ CÔNG THỨC, DỮ LIỆU & CHỐT CHẶN AN TOÀN (ĐÃ ĐỒNG THUẬN KỸ THUẬT)

### 2.1. Hệ Thống 6 Cần Thường, 3 Cần Exclusive & Dải Cân Nặng 5 Đảo

#### A. Bảng 6 Cần Thường & Khớp Tải Trọng Cổng Kép (`Power` + `Max Weight`)
| # | ID | Tên Cần | Giá Gold | Strength Req | Power | Max Weight | Lure Speed | Luck | Control | Steadiness |
|---|----|---------|----------|--------------|-------|------------|------------|------|---------|------------|
| 1 | `Twig` | Twig Rod | Free | `0` | `1` | `15 kg` | `+0%` | `+0%` | `+0%` | `+0%` |
| 2 | `Bamboo` | Bamboo Rod | `500` | `1,500` | `2` | `65 kg` | `+10%` | `+15%` | `+4%` | `+5%` |
| 3 | `Carbon` | Carbon Fiber Rod | `5,000` | `12,000` | `3` | `220 kg` | `+22%` | `+35%` | `+8%` | `+12%` |
| 4 | `MysticVine` | Mystic Vine Rod | `45,000` | `90,000` | `4` | `650 kg` | `+35%` | `+65%` | `+13%` | `+20%` |
| 5 | `MagmaCore` | Magma Core Rod | `350,000` | `650,000` | `5` | `1,600 kg` | `+50%` | `+110%` | `+18%` | `+30%` |
| 6 | `Celestial` | Celestial Starlight Rod | `2,500,000` | `4,500,000` | `6` | `5,000 kg` | `+70%` | `+180%` | `+25%` | `+42%` |

- **Cân bằng lại dải cân nặng cá 5 Đảo khớp với `Max Weight`:**
  - Đảo 1 (`Power 1–2`): Common→Legendary `0.5 – 48 kg`, Boss `52 – 110 kg` (`minRodPower = 2` → đòi `Bamboo 65 kg`).
  - Đảo 2 (`Power 2–3`): `4 – 175 kg`, Boss `185 – 360 kg` (`minRodPower = 3` → đòi `Carbon 220 kg`).
  - Đảo 3 (`Power 3–4`): `18 – 540 kg`, Boss `560 – 1,050 kg` (`minRodPower = 4` → đòi `Mystic Vine 650 kg`).
  - Đảo 4 (`Power 4–5`): `75 – 1,420 kg`, Boss `1,480 – 2,800 kg` (`minRodPower = 5` → đòi `Magma Core 1,600 kg`).
  - Đảo 5 (`Power 5–6`): `260 – 4,300 kg`, Boss `4,500 – 9,500 kg` (`minRodPower = 6` → đòi `Celestial 5,000 kg`).
- **Kiểm tra Cần quá yếu trước khi quăng:** Lọc ứng viên theo **cổng kép** `effectiveRod.power >= fish.minRodPower` **VÀ** `fish.minWeight <= effectiveRod.maxWeight`. Nếu người chơi cầm cần yếu (ví dụ cầm lại `Twig` trên Đảo 5) khiến danh sách ứng viên rỗng → **Server từ chối lượt quăng ngay từ đầu** (báo Toast *"Your rod is too weak for these waters! Equip a stronger rod!"*, **không trừ mồi, không bắt đầu chờ cá**).

#### B. Bảng 3 Cần Exclusive (`Best-Owned Normal Rod Scaling` + Tách Đường Nhận Riêng)
Gọi `B` là cây Cần thường có `order` cao nhất trong `profile.ownedRods`. Khi cầm Cần Exclusive `E`:
- **Điều kiện cầm (`equipStrengthReq`):** `0` (cầm được ngay cả sau khi Rebirth).
- **Mốc tính thưởng Strength (`masteryBaselineStrength`):** Bằng đúng **`B.strengthReq`** (tránh lỗi cầm Exclusive vừa Rebirth đã đạt trần thưởng Strength sớm hơn cần thường!).
- **Cấp Power hiệu dụng (`effectivePower`):** Bằng đúng **`B.power`**.
- **5 Chỉ số hiệu dụng:**
  - `MaxWeight = math.floor(B.maxWeight * E.scaleFactor)`
  - `LureSpeed = B.lureSpeed * E.scaleFactor + E.flatLure`
  - `Luck = B.luckBonus * E.scaleFactor + E.flatLuck`
  - `Control = B.controlBonus + E.flatControl` *(kẹp trần cuối cùng ở `BuffAggregator`)*
  - `Steadiness = math.min(0.65, B.steadiness + E.flatSteadiness)`

| ID | Tên Cần Exclusive | `scaleFactor` | `flatLure` | `flatLuck` | `flatControl` | `flatSteadiness` | Nguồn Mở Khóa Duy Nhất (Không qua `BuyRod` bằng Gold) |
|----|-------------------|---------------|------------|------------|---------------|------------------|-------------------------------------------------------|
| `RelicTrident` | Abyssal Relic Trident | `1.15` (`115%`) | `+5%` | `+15%` | `+2%` | `+5%` | Đổi tại Collector NPC: **`800 Gems` + nộp 1 cá Boss Đảo ≥ 3** |
| `VoidScythe` | Void Reaper Rod | `1.22` (`122%`) | `+8%` | `+25%` | `+4%` | `+8%` | Mua tại Exclusive Tab (**`2,200 Gems`**) hoặc rớt `0.2%` ở Xoáy nước Đảo 4–5 *(trùng quy đổi `+350 Gems + 2 Relics`)* |
| `SeraphimDragon` | Seraphim Sovereign Rod | `1.30` (`130%`) | `+12%` | `+40%` | `+6%` | `+12%` | Mở qua Gamepass `ExclusiveDragonRod` (`PerkService.HasGamepass`) |

#### C. Sáu Dòng Phù Phép (`EnchantsConfig.luau` — Chỉ áp dụng cho 3 Cần Exclusive, chi phí `1 Enchant Relic` hoặc `75 Gems`)
1. `swift_caster` (`28%`, Rare): `+35% Lure Speed`.
2. `iron_control` (`26%`, Rare): `+10% Control` & `+20% Steadiness`.
3. `sea_fortune` (`20%`, Epic): `+65% Luck`.
4. `titan_line` (`13%`, Legendary): Nhân `×2.5` trọng số roll bậc *Big/Giant/Titanic* → nhân `×1.45` cân nặng → kẹp trần `min(weight, effectiveRod.maxWeight * 1.25)` (**giữ nguyên nhãn `sizeTier` và hệ số giá của `sizeTier` sau khi kẹp cân**).
5. `abyssal_mutagen` (`9%`, Legendary): `+85% Mutation Chance`.
6. `midas_sovereign` (`4%`, Mythic): `+40% Luck`, lưu cờ `midasBonus = 1.30` trực tiếp lên từng con cá câu được bởi cần này (để đổi cần lúc bán hoặc đem đi *Appraise* vẫn tính đúng `×1.30` một lần duy nhất!), và `20%` cơ hội nâng cá có đột biến `"None"` / `"Shiny"` lên `"Golden"` (**không bao giờ ghi đè `"Cosmic"` hay `"Golden"`**).

---

### 2.2. Công Thức `BuffAggregator`, Xoáy Nước, Minigame Chấm Điểm & Appraise

1. **Công thức `BuffAggregator` & Xoáy nước (`Ocean Whirlpool`):**
   - `luckMult = (1 + rodLuck + enchantLuck + castLuckAdd) * (1 + baitLuck + potionLuck) * (1 + petLuck) * (1 + eventLuck) * (if inWhirlpool then 2.0 else 1.0)`
   - Trọng số roll cá Boss trong `FishingRoller`: `w_boss = baseBossWeight * bossChanceMult * (if inWhirlpool then 2.0 else 1.0) * (1 + 0.25 * (luckMult - 1))` *(Cam kết văn bản chính xác: Xoáy nước nhân đôi hệ số Luck tổng và nhân đôi trọng số rớt Boss trước chuẩn hóa xác suất!)*.
   - `biteSpeedMult = (1 + rodLureSpeed + enchantLure + castLureAdd + strengthSpeedBonus) * (1 + potionSpeed) * (1 + eventSpeed)` *(sàn thời gian chờ cá cắn `0.55s`)*.
   - `minigameWidth = math.clamp(baseZone + rodControl + enchantControl + strengthWidthBonus, 0.20, 0.68)` *(kẹp trần `0.68` ở bước cuối cùng sau khi cộng hết mọi nguồn, hiển thị `%` thực nhận sau kẹp trần trên HUD/Shop)*.
   - `minigameSpeed = baseSpeed / (1 + rodSteadiness + enchantSteadiness)`.

2. **Chấm Điểm Minigame Theo Từng Vòng Đối Chiếu Đồng Hồ Server & Đóng Phiên 1 Lần (`Per-Strike Server Verification`):**
   - **Chốt thông số lượt câu ngay lúc phao chạm nước:** Lưu cứng `snapshot = { rodId, activeBait, inWhirlpool, castMode, mults }` vào `CastSession` (đổi cần/mồi giữa chừng không làm sai lệch thưởng hay trừ nhầm mồi; xác định `inWhirlpool` ngay tại toạ độ phao chạm nước).
   - Khi cá `Rare+` cắn câu: Server sinh sẵn mảng `zoneCenters` độ dài `rounds` (mỗi tâm thuộc `[0.30, 0.82]`), ghi `promptSentClock = os.clock()`, `currentRound = 1`, đặt hạn bấm `timeoutSec = 5.5 + rounds * 2.0` nhưng hẹn giờ tự đóng ở **`serverCloseDelay = timeoutSec + 0.40`** (tách rõ **hạn bấm** khỏi **hạn nhận gói** để cú bấm cuối ở giây `timeoutSec - 0.05` bay qua mạng trong `0.40s` ân hạn vẫn được chấm công bằng!).
   - Client vẽ kim chạy mượt `60 FPS` theo sóng tam giác tất định `pos(t) = triangleBounce(0.08, speed, t)`. **Mỗi lần bấm ở vòng `r`**, Client gửi ngay gói `FishingMinigameStrike(sessionId, r, clientElapsed)` lên Server:
     - Server kiểm tra đúng `sessionId`, đúng thứ tự vòng `r == session.currentRound`, `0 < clientElapsed <= timeoutSec`, đồng thời đối chiếu đồng hồ thật của Server: `serverElapsed = os.clock() - session.promptSentClock`, yêu cầu `clientElapsed <= serverElapsed + 0.08` và `(serverElapsed - clientElapsed) <= 0.45` (chống khai gian thời gian mà vẫn chịu tốt ping cao `200ms+`).
     - Tính vị trí `pos = triangleBounce(0.08, speed, clientElapsed)`; nếu nằm trong `zoneCenters[r] ± (zoneWidth * 0.52 + 0.05)` thì tăng `session.currentRound += 1` (đủ `rounds` thì trao cá và đóng phiên ngay!), nếu trượt thì đóng phiên báo hụt ngay.
   - Mọi sự kiện `Timeout`, `Thắng`, `Trượt`, `Đổi Đảo`, `Cất Cần`, `Chết` hoặc `Rebirth` đều đi qua hàm đóng phiên nguyên tử `CloseSessionOnce(player, sessionId, reason)` phát tín hiệu đóng `MinigameBar` trên Client; chỉ duy nhất `FishingController` điều phối quăng lại `Auto-Fish` 1 lần sau khi phiên khép lại.

3. **Quy tắc Thẩm Định Cá (`Appraise`) & Tuân Thủ Chính Sách Xác Suất Roblox (`PolicyService`):**
   - **Appraise:** Chi phí `max(100, floor(fishDef.baseValue * 0.35))` Gold; kiểm tra khoảng cách tới NPC và quyền sở hữu `uid`. **Cho phép Appraise cả cá `soulbound`** để người chơi nâng bậc kích thước cầm khoe (*Big / Giant / Titanic*), nhưng giữ nguyên `soulbound = true` và `sellValue = 0` (chỉ cập nhật `originalValue` và kỷ lục `indexFish[id] = max(oldBest, newWeight)`). Với mọi cá Appraise: giữ nguyên `uid`, `locked`, `midasBonus`; reroll cân nặng với sàn `>= 0.85 * oldWeight`, chỉ nâng bậc đột biến nếu roll ra bậc cao hơn (`Cosmic > Golden > Shiny > None`).
   - **Minh bạch xác suất động & `PolicyService`:** Hiển thị bảng `%` gốc VÀ **xác suất `%` thực tế đang hiệu lực** (sau khi áp dụng `Auto-Fish Pro`, Cần câu đang cầm, Mồi, Thuốc, Xoáy nước) ngay trên UI câu cá / Trứng Pet / Bệ `Enchant Altar` và hộp mô tả trước khi mua `Auto-Fish Pro` / `ExclusiveDragonRod`. Tích hợp kiểm tra `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` để chặn quay ngẫu nhiên trả phí với người chơi thuộc vùng hạn chế nếu mở nạp Gems bằng Robux.

---

### 2.3. An Toàn Dữ Liệu Đa Phiên (`Session Lock`), Migration `v2` & Quy Tắc `Soulbound Trophy` Khi Rebirth

1. **Khóa Phiên Ghi DataStore Độc Quyền & Tuần Tự (`DataService.luau` P0 Hardening):**
   - Mỗi Server giữ `SERVER_JOB_ID = if game.JobId ~= "" then game.JobId else Util.NewUid()`.
   - Hồ sơ lưu kèm `{ activeSessionId: string?, lockTimestamp: number, saveSeq: number }`, kèm khóa tuần tự theo người chơi `saveInFlight[player]: boolean`:
     - **Khi Load:** Dùng `UpdateAsync` yêu cầu nhận khóa `activeSessionId = SERVER_JOB_ID`, `lockTimestamp = os.time()`. Chỉ được chiếm khóa nếu `oldData == nil`, `oldData.activeSessionId == nil`, `oldData.activeSessionId == SERVER_JOB_ID`, hoặc khóa cũ đã quá hạn `os.time() - (oldData.lockTimestamp or 0) > 120`. Nếu đang bị server khác giữ khóa còn mới, thử lại tối đa `3 lần × 1.5s`; **nếu hết 3 lần vẫn chưa lấy được khóa HOẶC DataStore báo lỗi (khi `PlaceId > 0`), bắt buộc gắn `loadFailedPlayers[player] = true`**, khóa toàn bộ giao dịch tiêu Gems / đổi cá / xoay dòng / Rebirth của phiên đó và **cấm ghi đè DataStore**.
     - **Khi Autosave / Gia hạn Khóa định kỳ (mỗi `60s`):** Kể cả khi `dirtyRevision` chưa tăng (túi không đổi), Server vẫn gia hạn `lockTimestamp = os.time()` (nếu đang giữ khóa hợp lệ) để phiên chơi dài đứng yên không bao giờ hết hạn `120s`! Trước khi lưu, nếu `saveInFlight[player]` đang chạy thì đợi lượt đó xong; chụp `revBefore = dirtyRevision[player]`. Bên trong `UpdateAsync(oldData)`: **CHỈ ĐƯỢC GHI KHI `oldData ~= nil and oldData.activeSessionId == SERVER_JOB_ID` và `(oldData.saveSeq or 0) <= profile.saveSeq`** (nếu khóa đã nhả `nil` hoặc chuyển sang server khác thì hủy ghi ngay lập tức!). Khi ghi thành công, tăng `saveSeq += 1` và chỉ xóa cờ cần lưu nếu `dirtyRevision[player] == revBefore`.
     - **Khi `PlayerRemoving` / `BindToClose`:** Bắt buộc **chờ lượt `saveInFlight[player]` đang chạy (nếu có) kết thúc hoàn toàn**, sau đó thực hiện `UpdateAsync` cuối cùng vừa lưu trạng thái mới nhất vừa nhả `activeSessionId = nil` (chỉ khi `oldData.activeSessionId == SERVER_JOB_ID`) để server mới tiếp nhận tức thì.

2. **Hàm Nâng Cấp Hồ Sơ Cũ An Toàn (`MigrateProfileToV2` — Idempotent) & Quà Online Ngày UTC:**
   - Khi nạp hồ sơ `dataVersion < 2`: duyệt toàn bộ `fishBag`, giữ nguyên `uid`, `weight`, `sellValue` cũ; bổ sung `originalValue = entry.originalValue or entry.sellValue`, `sizeTier = entry.sizeTier or "Normal"`, `midasBonus = entry.midasBonus or 1.0`, `soulbound = entry.soulbound == true`, và nếu `entry.locked == nil` thì tự bật `locked = true` cho cá `Legendary`/`Boss` hoặc có đột biến (`~= "None"`). Khởi tạo `playtimeDay = Util.GetUtcDayIndex()`, `playtimeTodaySec = 0`, `playtimeClaimedToday = {}` (lưu đồng bộ cả số giây đã chơi và các mốc đã nhận trong ngày UTC đó). Nâng `dataVersion = 2`.

3. **Quy Tắc Rebirth & Kỷ Vật Cá Khóa (`Soulbound Trophy` — Khóa chặt 100% lỗ hổng):**
   - **Giữ nguyên qua Rebirth:** `gems`, `pets`, `equippedPetUids`, `potions`, `activePotions`, `indexFish`, `indexPets`, `claimedIndexRewards`, `claimedAchievements`, `rodEnchants`, `enchantRelics`, `playtimeDay`, `playtimeTodaySec`, `playtimeClaimedToday`, **các cây Cần Exclusive trong `ownedRods`**, cùng **tối đa `12` con cá có `locked == true`**.
   - **Cách chọn & hiển thị xác nhận 12 con cá kỷ vật:**
     - Sắp xếp các con cá đang `locked == true` ưu tiên theo **`originalValue` giảm dần** (giữ bền các Trophy giá trị gốc cao qua mọi lần Rebirth tiếp theo!).
     - Gắn `soulbound = true`, `sellValue = 0` cho 12 con được giữ; lọc `pinnedFishUids` chỉ giữ các `uid` nằm trong danh sách 12 con đó.
     - **Màn hình xác nhận Rebirth** hiển thị trực tiếp **danh sách tên cụ thể của tối đa 12 con cá được giữ làm Trophy, các ô ghim Hotbar `2..5` nào tiếp tục còn hiệu lực**, và số cá còn lại sẽ bị xóa trước khi bấm nút chốt Rebirth.
   - **Bảo vệ tuyệt đối cá `soulbound == true` ở mọi luồng bán Gold:**
     - Cả `SellAllUnlocked`, `SellSelectedFish`, `SellSingleFish` và `SellHeldFish` đều **bỏ qua mọi con cá có `soulbound == true` hoặc `locked == true` NGAY TRƯỚC KHI xóa khỏi `fishBag`** (kể cả khi người chơi bấm mở khóa `locked = false` hay mang đi `Appraise`, cá `soulbound` vẫn mang cờ `soulbound = true` nên không bao giờ bị xóa nhầm hay bán ra 1 Gold!).
     - Cá `soulbound` chỉ có thể tiêu thụ hợp lệ khi người chơi chủ động chọn nộp vào **Nhiệm vụ Đổi Cá (`Fish Bounty`)** tại Collector NPC (Server kiểm tra đúng `uid` thuộc sở hữu, xóa đúng 1 lần nguyên tử trước khi cộng Gems/Relic, đồng thời dọn `pinnedFishUids` và mô hình cầm trên tay nếu đang cầm đúng con đó; các gói Bounty cấp đảo cao yêu cầu đã mở khóa đảo đó trong vòng Rebirth hiện tại!).

---

## 3. KIẾN TRÚC TÁCH FILE & TỐI ƯU HIỆU NĂNG (`≤ 350 DÒNG / FILE`, `< 310` CHO 5 FILE SÁT TRẦN)

1. **Tách nhẹ 5 file đang sát trần (`331–336` dòng) ngay đầu chặng tương ứng:**
   - `HudPanel.luau (336)` → chuyển phần Hotbar, nút Auto & Chọn mồi sang `HotbarAndBaitUi.luau` (giảm `HudPanel` xuống `< 230` dòng).
   - `PetsService.luau (336)` → chuyển phần dựng/diễn hoạt Pet sang `ClientPetRenderer.luau` trên Client.
   - `ProgressPanel.luau (333)` → tách tab Index 3D sang `IndexGridSection.luau`.
   - `BagPanel.luau (332)` → chuyển dựng ô thẻ sang `ViewportCard.luau` + `ViewportPool.luau` (giảm `BagPanel` xuống `< 250` dòng).
   - `FishingService.luau (331)` → tách bộ quản lý phiên & kiểm toán Minigame sang `FishingSessionManager.luau`.
2. **Tối ưu FPS trên Mobile (`ClientPetRenderer` & `ViewportPool`):**
   - Server chỉ đồng bộ danh sách ID Pet đang đeo qua Attribute/Remote; `ClientPetRenderer` nội suy chuyển động mượt trên Client (giảm tần suất khi xa `> 85 studs` hoặc khi bật `Low GFX`).
   - `ViewportPool` chỉ cấp phát số thẻ vừa khung nhìn cuộn cộng 1 hàng đệm, tái sử dụng theo `uid`, không dựng lại toàn bộ lưới khi tiền nhảy số, chỉ xoay 1 thẻ đang chọn và dừng hoàn toàn khi đóng cửa sổ.

---

## 4. LỘ TRÌNH THI CÔNG 4 CHẶNG & CA NGHIỆM THU BẮT BUỘC

Trạng thái: `[ ]` Chưa làm · `[~]` Đang làm · `[x]` Đã hoàn thành & PASS 6/6.

### 🏝️ CHẶNG A: ĐẠI TU THẾ GIỚI 5 ĐẢO, NƯỚC SÓNG THẬT, XOÁY NƯỚC & NPC HỘI THOẠI
- [x] **A1 — Nước Biển Sóng Thật (`Terrain:FillBlock` cục bộ) & Địa Hình 5 Đảo Đa Tầng Chi Tiết:**
  - Cập nhật `verify_project.ps1` cho phép `Terrain:FillBlock` và phép so sánh `==` / `~=` với `Enum.Material.Water` nhưng chặn mọi phép gán `.Material = Enum.Material.Water` lên `BasePart`.
  - Đổ `Terrain Water` sóng thật đúng trong hộp hồ biển của 5 đảo (không gọi `Terrain:Clear()`), giữ `FishingWater` vô hình nằm đúng trong từng thư mục `Island_<id>` với mặt trên khớp mặt nước (loại khỏi Raycast vật cản), nâng cấp cảnh quan đa tầng 5 Đảo + Bệ `Enchant Altar`.
  - *Nghiệm thu ngay cuối A1:* Câu thành công trên **cả 5 đảo** ngay sau khi thay nước Terrain, và địa hình ngoài hộp tạo biển vẫn còn nguyên vẹn.
- [x] **A2 — Hệ Thống Xoáy Nước Cá Hiếm Trên Biển (`WhirlpoolManager.luau`):**
  - Xuất hiện ngẫu nhiên xoáy nước sủi bọt + cột sáng + đàn bóng cá bơi vòng dưới mặt nước; quăng trúng vùng xoáy nhân đôi hệ số Luck tổng và nhân đôi trọng số Boss.
- [x] **A3 — Dàn 4 NPC Người Thật R15 (`NpcBuilder.luau`) & Khung Hội Thoại (`NpcDialogueModal.luau`):**
  - Dựng 4 NPC R15 (Merchant, Shop/Crafter, Appraiser/Collector, Gym Coach) có cử động đứng thở/vẫy tay + hộp thoại đa lựa chọn; mở rồi đóng thoại Merchant giữ nguyên 100% túi cá.
  - *Nghiệm thu Chặng A:* Câu thành công trên cả 5 đảo ngay trên nước Terrain mới; địa hình ngoài vùng biển giữ nguyên; đóng/mở thoại NPC an toàn.

---

### 🎣 CHẶNG B: DỮ LIỆU AN TOÀN `V2`, HOTBAR CẦM ĐỒ/KHOE CÁ, VẬT LÝ NẢY ĐẤT, 5 CHỈ SỐ CẦN & EXCLUSIVE ROD
- [x] **B1 — Khóa Phiên `DataService` (`Session Lock`), Migration `v2` & Tách `FishingSessionManager`:**
  - Nâng cấp `DataService` (khóa độc quyền `activeSessionId == SERVER_JOB_ID`, gia hạn khóa định kỳ, chờ `saveInFlight` trước khi nhả khóa, khóa giao dịch nếu thử 3 lần không lấy được khóa + `MigrateProfileToV2`) và quy tắc `Soulbound Trophy` khi Rebirth.
  - *Nghiệm thu B1:* Nộp cá tại Bounty rồi chuyển máy chủ ngay → cá đã nộp mất đúng 1 lần, phần thưởng giữ nguyên đúng 1 lần; thử khóa tải lỗi chặn giao dịch an toàn.
- [x] **B2 — Custom Hotbar (`1..5`), Cầm Cá Khoe Hàng, Cụm Chọn Mồi Nhanh + Auto & Vật Lý Quăng Phao Nảy Đất:**
  - Ẩn Backpack mặc định; dựng `HotbarAndBaitUi.luau` + `HotbarAndCastController.luau`; giữ chuột nạp thanh lực *Cast Power* (4 chế độ Manual / Perfect / Auto Free / Auto Pro); Raycast điểm chạm đầu tiên (trúng cầu/đất nảy tưng bật về, trúng nước Terrain xét thưởng xoáy); dấu `!` cá đớp + cong cần + Camera zoom nhẹ; chấm điểm Minigame theo từng vòng `FishingMinigameStrike` đối chiếu đồng hồ Server (tách hạn bấm `7.5s / 9.5s / 11.5s` và hạn nhận gói `+0.40s` ân hạn mạng; nghiệm thu cả ở chế độ mô phỏng ping cao `200ms` trong Studio).
- [x] **B3 — Bộ 5 Chỉ Số Cần Câu, Cân Bằng Lại Kg 5 Đảo, 3 Cần Exclusive (`115–130%`) & Bệ Xoay Dòng `Enchant Altar`:**
  - Nâng cấp `RodsConfig.luau` + 5 file Đảo, tách 3 đường nhận Cần Exclusive, hoàn thiện `EnchantsConfig.luau` + `EnchantAndBountyService.luau` (xoay 6 dòng Enchant bằng Relic/Gems kèm bảng `%` công khai & kiểm tra `PolicyService`).

---

### 🎒 CHẶNG C: GIAO DIỆN Ô LƯỚI 3D (`VIEWPORTPOOL`), KHÓA CÁ, BÁN CHỌN LỌC, THẨM ĐỊNH & ĐỔI ĐỒ
- [x] **C1 — Lưới Thẻ 3D Tối Ưu (`ViewportPool.luau` + `ViewportCard.luau`) Cho `Bag`, `Shop`, `Pets` & `Index`:**
  - Tái sử dụng ô thẻ mượt trên mobile, hình 3D lớn chính giữa ô, nhãn bậc *Big/Giant/Titanic* & đột biến góc trên, cân nặng/giá tiền gọn dưới đáy, không dựng lại toàn lưới khi tiền thay đổi.
- [x] **C2 — Khóa Cá (`🔒 Lock`), Bán Chọn Lọc Nhiều Cá (`Multi-Select`), Bán Cá Cầm Tay & Bảo Vệ `Soulbound`:**
  - Hoàn thiện mọi đường bán kiểm tra chặt `locked` và `soulbound` trước khi xóa khỏi túi, đồng bộ tức thì với ô ghim Hotbar và mô hình cá đang cầm trên tay.
- [x] **C3 — NPC Thẩm Định Cá (`Appraise`), Bảng Đổi Cá (`Fish Bounty`), Quà Online Cộng Dồn Ngày UTC & `Settings`:**
  - Hoàn thiện `Appraise`, 3 hợp đồng `Fish Bounty` (tiêu đúng `uid` nguyên tử 1 lần), hộp quà 9 mốc tính theo `playtimeTodaySec` (ngày UTC) và bảng `Settings` (`Auto-Lock` + `Low GFX` + `Mute`).

---

### 🐉 CHẶNG D: ĐẠI TU MÔ HÌNH 3D CHI TIẾT CAO, `CLIENTPETRENDERER`, ĐẬP TRỨNG, AURA & ÂM THANH
- [x] **D1 — Thư Viện Mô Hình 3D Chi Tiết Cao (`FishModelBuilder`, `PetModelBuilder`, `RodAndWeightBuilder`) & `ClientPetRenderer`:**
  - Dựng chi tiết 5 họ Cá (Thon, Kiếm, Đuối, Cá Mập, Thủy Quái Boss), 6 dòng Pet Chibi mắt long lanh và chuyển toàn bộ diễn hoạt bay của Pet sang Client.
- [x] **D2 — Hiệu Ứng Đập Trứng (`EggHatchCutscene`), Overhead Rank Title, Hào Quang (`Aura`) & Cầm Tạ 3D Thật:**
  - Diễn hoạt đập trứng nứt vỏ nổ sáng (có nút `Skip`), gắn Danh hiệu & Aura theo mốc Strength/Rebirth, và gắn quả tạ đôi / đòn tạ 3D thật vào bàn tay nhân vật khi tập Gym.
- [x] **D3 — Đại Tu Animation Toàn Thân, Âm Thanh Đa Lớp & Kiểm Định Tổng Thể:**
  - Tinh chỉnh diễn hoạt toàn thân, lắp âm thanh nền sóng biển + bộ SFX chi tiết, kiểm tra hiệu năng khi túi đầy & nhiều Pet trên cầu tàu, đạt `[PASS] 6/6` sẵn sàng phát hành.
