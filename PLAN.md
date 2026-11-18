# PLAN.md — MIGHTY ANGLER 2.0 (Major Game-Feel, Visual & Systems Overhaul)

> **Nguồn sự thật duy nhất (Single Source of Truth)** của dự án tại `D:\Projects\mighty-angler`, dùng chung liên thông giữa **Antigravity** và **OpenAI Codex / GPT**.
> - **Ngày cập nhật:** 2026-11-18
> - **Trạng thái nền tảng:** Bản khung v1.0 (5 Đảo cơ bản, 49 file `.luau`, PASS 6/6) đã chạy ổn định. Tài liệu này quy định **Đại Kế Hoạch Đại Tu 2.0 (Phase 2 Overhaul)** nhằm lột xác toàn diện dự án từ *"bản mẫu gameplay chạy được"* thành **Game Roblox Simulator thực thụ** chuẩn chất lượng **Fisch × Pets GO! × Arm Wrestle Simulator**.
> - **Kỷ luật kỹ thuật bất biến:** Mọi file `.luau` **≤ 350 dòng**, Server-Authoritative 100%, không xóa file tùy tiện, kiểm định tự động 6 chốt chặn qua `tools/verify_project.ps1` sau mỗi mục con.

---

## 1. MỤC TIÊU ĐẠI TU 2.0 & BẢNG QUYẾT ĐỊNH ĐÃ CHỐT CỦA CHỦ DỰ ÁN

### 1.1. Vấn đề của bản khung cũ cần giải quyết triệt để
1. **Đồ họa Thế giới & Tạo hình còn đơn sơ:** Mặt biển cũ là tấm kính phẳng; đảo vuông vức ít chi tiết đời sống; NPC ghép 3 khối thô; Cá & Pet mới ghép 3 khối cơ bản chưa ra chất sưu tầm.
2. **Cảm giác Câu cá & Bố cục Màn hình chưa chuẩn game câu cá hiện đại:** Còn dùng nút `CAST ROD` to thô thay vì cầm cần bấm thẳng màn hình; thiếu vật lý phao bay & bật nảy khi quăng trúng đất liền; thiếu ô chọn mồi nhanh ở góc phải dưới và thanh Hotbar cầm đồ/khoe cá.
3. **Túi đồ & Giao dịch cá còn thiếu chiều sâu:** Hiển thị dạng danh sách chữ dài thay vì **Ô Lưới Hình 3D To (`ViewportFrame Grid`)**; chưa có **Khóa cá (`🔒 Lock`)**, chưa cho **chọn từng con cá để bán**, chưa có **NPC Hội thoại đa lựa chọn** hay nhiệm vụ dùng cá quý đổi đồ/thẩm định kích thước.
4. **Chiều sâu Cần câu & Giữ chân treo máy:** Cần câu mới có mỗi chỉ số `Luck`; chưa có **Cần Exclusive tăng hệ số theo cần mạnh nhất** để xoay dòng Phù phép (`Enchant`) không lo lỗi thời; chưa xử lý tự sổng cá Hiếm/Boss khi người chơi treo máy không bấm Minigame.

### 1.2. Bảng 10 Quyết Định Thiết Kế Cốt Lõi (User-Approved Spec)
| Mã | Hạng mục | Quy tắc chốt chính thức |
|----|----------|-------------------------|
| **O1** | **Hotbar & Cầm Cần / Cầm Cá Khoe** | Ẩn Backpack mặc định của Roblox; dựng **Custom Hotbar** dưới đáy màn hình (`Phím 1..5`). Ô `[1]` để rút/cất Cần câu. Các ô `[2..5]` cho phép gắn **Cá trong túi ra cầm trên 2 tay đi khoe khắp đảo** (kích thước 3D trên tay tỷ lệ thật theo cân nặng & bậc *Big/Giant/Titanic* + hiệu ứng đột biến). |
| **O2** | **Cầm Cần Bấm Màn Hình & Nảy Đất** | Bỏ nút `CAST ROD`. Khi đang cầm Cần câu trên tay, **nhấn/giữ chuột (hoặc chạm màn hình)** để nạp thanh lực *Cast Power* rồi thả ra quăng phao theo quỹ đạo parabol. **Rơi trúng Nước:** nổ bọt sóng, phao dập dềnh. **Rơi trúng Đất liền / Cầu gỗ / Đá:** phao **nảy tưng 1–2 nhịp trên mặt đất**, tung bụi + tiếng *cộc*, đầu cần giật nhẹ rồi tự thu dây về ngay. |
| **O3** | **Phân cấp Câu Tay vs. Auto Free vs. Gamepass Auto Pro** | • **Câu tay (Manual Hold):** Căn thả trúng vạch *Perfect* nhận **`+25% Cast Luck Bonus` + `+15% Lure Speed`**.<br>• **Auto-Fish thường (Miễn phí cho mọi người):** Tự động quăng không giữ thanh lực, **KHÔNG có Cast Luck Bonus** (`0%`), nhịp nghỉ tiêu chuẩn.<br>• **Gamepass `Auto-Fish Pro`:** Tự động quăng chuẩn **Perfect Cast 100%**, hưởng trọn **`+25% Cast Luck Bonus` + `+15% Lure Speed`** như câu tay và quăng lại nhanh hơn! |
| **O4** | **Chống Kẹt Màn Hình Khi Treo Máy (AFK Timeout)** | Khi câu tay hoặc treo Auto mà gặp **cá Hiếm / Boss / Exclusive** bật thanh `MinigameBar`: có thanh đếm ngược **`6.5 giây`**. Nếu người chơi không bấm kịp (hoặc đang treo máy AFK), **cá tự động giật đứt dây chạy mất**, đóng `MinigameBar` sạch sẽ và **nếu đang bật Auto-Fish thì tự động quăng lượt mới tiếp tục câu**, tuyệt đối không đứng hình treo máy. |
| **O5** | **Bố cục Cụm Mồi Nhanh & Nút Auto** | • **Góc dưới bên phải:** Ô **Chọn Mồi Nhanh (`Bait Selector`)** hiện loại mồi đang gắn + số lượng còn lại; bấm vào xổ ngược danh sách mồi đang có để đổi tức thì.<br>• **Ngay phía trên Hotbar:** Đặt gọn hàng nút pill **`🏋️ Auto-Train`** và **`🎣 Auto-Fish`** (kèm trạng thái sáng rõ, không che nhân vật). |
| **O6** | **Túi Đồ Ô Lưới 3D, Khóa Cá & Bán Chọn Lọc** | Túi đồ (`Bag`), `Shop`, `Pets`, `Index` chuyển sang **Lưới Thẻ Vuông (`UIGridLayout`)**: hình 3D con cá/pet/cần xoay nhẹ chiếm trung tâm ô (`ViewportFrame`), thông số cân nặng/giá tiền viết gọn bên dưới. Hỗ trợ **`🔒 Lock/Unlock`** từng con cá (kèm cài đặt *Auto-Lock* cá hiếm/đột biến), chế độ **Tích chọn nhiều con cá để bán (`Sell Selected`)**, **`Sell Held Fish`** và **`Sell All Unlocked`**. |
| **O7** | **NPC Người Thật, Hội Thoại & Thẩm Định / Đổi Cá** | Thay NPC khối vuông bằng **NPC R15 người thật** có trang phục chủ đề, cử động thở/vẫy tay và **Khung Hội Thoại nhiều lựa chọn**:<br>• **Merchant NPC:** *Sell All Unlocked / Select Fish to Sell / Sell Held Fish*.<br>• **Appraiser & Collector NPC:** *Thẩm định cá đang cầm (`Appraise` tốn Gold để reroll kích thước Big/Giant/Titanic hoặc kích đột biến)* & *Bảng Thu Mua Cá (`Fish Bounty` — nộp đúng loài cá/đột biến đã khóa để đổi Gems, Đá Phù Phép, Mồi Boss)*. |
| **O8** | **5 Chỉ Số Cần Câu + Cần Exclusive Xoay Dòng (`Enchant`)** | • Mọi cần câu có **5 chỉ số thật:** `Max Weight (kg)`, `Lure Speed (%)`, `Luck (%)`, `Control (%)` (độ rộng thanh xanh), `Steadiness (%)` (làm chậm kim giãy của cá Boss).<br>• **Cần thường (6 cây Gold/Strength):** Không xoay dòng (vì thay đổi nhanh theo tiến trình đảo).<br>• **Cần Exclusive (3 cây đặc biệt):** Chỉ số gốc tự động bằng **`115% – 125%` cây Cần thường mạnh nhất mà người chơi đang sở hữu** (không bao giờ lỗi thời qua các bản Update, giữ nguyên sau khi Rebirth) và **độc quyền mở khóa Ô Xoay Dòng Phù Phép (`Enchant Altar`)**! |
| **O9** | **Thế Giới Sống Động & Khoe Đẳng Cấp (`Social Flex`)** | • Bản đồ dùng **Nước biển sóng thật (`Roblox Terrain Water`)**, địa hình đảo phân tầng uốn lượn, nhiều chi tiết đời sống + **Xoáy Nước Cá Hiếm (`Ocean Whirlpools` +2x Luck)** nổi ngẫu nhiên trên biển.<br>• Nhân vật có **Danh hiệu trên đầu (`Overhead Rank Title`)**, vòng **Hào quang (`Aura`)** theo mốc Strength/Rebirth, và **2 tay cầm quả tạ 3D / đòn tạ thật** khi tập Gym. |
| **O10** | **Giữ Chân Treo Máy & Tối Ưu Máy Yếu** | Bổ sung **Hộp Quà Online 9 mốc (`Playtime Gifts` từ 2p → 60p)**, hiệu ứng **Đập Trứng nứt vỏ nổ sáng**, dấu **`!`** cá đớp + **Cần câu uốn cong & Camera Zoom nhẹ** lúc đấu Minigame, âm thanh đa lớp và bảng **Settings (`Auto-Lock` + `Low GFX`)**. |

---

## 2. ĐẶC TẢ HỆ THỐNG & CÔNG THỨC KỸ THUẬT (DÀNH CHO AI IMPLEMENT & REVIEW)

### 2.1. Bảng 6 Cần Thường & 3 Cần Exclusive (`RodsConfig.luau` mới)

#### A. Sáu Cần Thường (Mua bằng Gold + Cổng Strength — Làm mốc gốc cho Cần Exclusive)
| # | ID | Tên Cần | Giá Gold | Strength Req | Max Weight | Lure Speed | Luck | Control | Steadiness |
|---|----|---------|----------|--------------|------------|------------|------|---------|------------|
| 1 | `Twig` | Twig Rod | Free | `0` | `15 kg` | `+0%` | `+0%` | `+0%` | `+0%` |
| 2 | `Bamboo` | Bamboo Rod | `500` | `1,500` | `65 kg` | `+10%` | `+15%` | `+4%` | `+5%` |
| 3 | `Carbon` | Carbon Fiber Rod | `5,000` | `12,000` | `220 kg` | `+22%` | `+35%` | `+8%` | `+12%` |
| 4 | `MysticVine` | Mystic Vine Rod | `45,000` | `90,000` | `650 kg` | `+35%` | `+65%` | `+13%` | `+20%` |
| 5 | `MagmaCore` | Magma Core Rod | `350,000` | `650,000` | `1,600 kg` | `+50%` | `+110%` | `+18%` | `+30%` |
| 6 | `Celestial` | Celestial Starlight Rod | `2,500,000` | `4,500,000` | `5,000 kg` | `+70%` | `+180%` | `+25%` | `+42%` |

#### B. Ba Cần Exclusive (`Best-Owned Normal Rod Scaling` + Mở khóa `Enchant Slot`)
- **Quy tắc tính chỉ số động (`GetEffectiveRodStats(profile, rodId)`):**
  Gọi `B` là cây Cần thường có `order` cao nhất trong `profile.ownedRods`. Nếu người chơi trang bị Cần Exclusive `E` (có hệ số `scaleFactor`, ví dụ `1.15` hoặc `1.25`):
  - `MaxWeight = math.floor(B.maxWeight * E.scaleFactor)`
  - `LureSpeed = B.lureSpeed * E.scaleFactor + E.flatLureBonus`
  - `Luck = B.luckBonus * E.scaleFactor + E.flatLuckBonus`
  - `Control = math.min(0.38, B.controlBonus + E.flatControlBonus)`
  - `Steadiness = math.min(0.60, B.steadiness + E.flatSteadinessBonus)`
  - **Tương tác khi Rebirth:** Cần Exclusive có `strengthReq = 0`, **KHÔNG bị xóa khỏi `ownedRods` và KHÔNG mất dòng `rodEnchants[rodId]` khi Rebirth**. Ngay sau Rebirth, `B` quay về `Twig Rod` nên Cần Exclusive tự động scale theo `Twig × scaleFactor` (không phá cân bằng đầu game, nhưng giữ nguyên dòng Enchant quý giá!).
- **Danh sách 3 Cần Exclusive:**
  1. **`RelicTrident` — *Abyssal Relic Trident*** (`scaleFactor = 1.15`, mở bằng **800 Gems + nộp cá Boss tại Collector NPC** — mục tiêu cày cuốc F2P cực cuốn!).
  2. **`void_scythe` — *Void Reaper Rod*** (`scaleFactor = 1.22`, mở bằng **2,200 Gems** hoặc nổ siêu hiếm `0.2%` từ Xoáy nước *Whirlpool* Đảo 4–5).
  3. **`cyber_dragon` — * Seraphim Sovereign Rod*** (`scaleFactor = 1.30`, gói **Exclusive Rod Gamepass / Shop** hiệu ứng rồng ánh sáng đôi cánh).

#### C. Sáu Dòng Phù Phép (`EnchantsConfig.luau` — Chỉ xoay cho Cần Exclusive tại `Enchant Altar`)
Chi phí mỗi lần xoay: **`1 Enchant Relic`** (câu hiếm `1.5%` / Boss drop `25%` / đổi tại NPC) hoặc **`75 Gems`**:
| Enchant ID | Tên Hiển Thị | Tỉ lệ xoay | Bậc | Hiệu ứng cộng thêm vào Cần Exclusive |
|------------|--------------|------------|-----|--------------------------------------|
| `swift_caster` | Swift Caster | `28%` | Rare | `+35% Lure Speed` |
| `iron_control` | Master Control | `26%` | Rare | `+10% Control` (rộng thanh xanh) & `+20% Steadiness` |
| `sea_fortune` | Sea Fortune | `20%` | Epic | `+65% Luck` |
| `titan_line` | Titan Line | `13%` | Legendary | `+45% Fish Weight` & `2.5x` cơ hội ra bậc *Giant / Titanic* |
| `abyssal_mutagen` | Abyssal Mutagen | `9%` | Legendary | `+85% Mutation Chance` |
| `midas_sovereign` | Midas Touch | `4%` | Mythic | `+40% Luck`, `+30% Sell Gold` & `20%` cơ hội cá câu lên hóa *Golden* |

---

### 2.2. Kích Thước Cá, Khóa Cá & Cân Nặng Tải Trọng (`Max Weight`)
- Mỗi loài cá vẫn có khoảng `[minWeight .. maxWeight]`, nhưng khi câu lên (hoặc khi **Appraise** tại NPC) có xác suất nổ **Bậc Kích Thước (`sizeTier`)**:
  - `Normal` (`85%`): `0.8x – 1.2x` cân chuẩn, hệ số giá `×1.0`.
  - `Big` (`11%`): `1.25x – 1.6x` cân chuẩn, hệ số giá `×1.45`, mô hình 3D to `1.3x`.
  - `Giant` (`3.5%`): `1.65x – 2.3x` cân chuẩn, hệ số giá `×2.2`, mô hình 3D to `1.7x`.
  - `Titanic` (`0.5%`): `2.5x – 3.5x` cân chuẩn, hệ số giá `×4.0`, mô hình 3D khổng lồ `2.25x`!
- **Ràng buộc `Max Weight`:** Chỉ những loài cá có `minWeight <= EffectiveRod.MaxWeight` mới cắn câu; đồng thời cân nặng thực tế roll ra bị kẹp trần bởi `EffectiveRod.MaxWeight * 1.25` (nên muốn bắt cá *Titanic* siêu nặng ở đảo cao bắt buộc phải nâng cấp Cần xịn!).

---

### 2.3. Công thức Gộp Buff Tổng Thể (`BuffAggregator.luau` v2 — Không đệ quy)
Mọi tính toán tiếp tục đi qua duy nhất `BuffAggregator` (giữ khóa chống đệ quy `evaluatingPlayers` & tách hàm độc lập `GetMaxEquippedPets`):
- `luckMult = (1 + rodLuck + enchantLuck + castBonusLuck + whirlpoolBonus) * (1 + petLuck) * (1 + potionLuck) * (1 + baitLuck) * (1 + eventLuck)`
  *(Trong đó: `castBonusLuck = 0.25` nếu câu tay đạt Perfect HOẶC sở hữu Gamepass `AutoFishPro`; `castBonusLuck = 0` nếu dùng Auto-Fish miễn phí! `whirlpoolBonus = 1.0` tức gấp đôi gốc nếu phao rơi trúng vòng xoáy `Ocean Whirlpool`!)*.
- `biteSpeedMult = (1 + rodLureSpeed + enchantLure + castSpeedBonus + strengthSpeedBonus) * (1 + potionSpeed) * (1 + eventSpeed)`
- `minigameWidth = clamp(baseZone + rodControl + enchantControl + strengthWidthBonus, 0.20, 0.62)`
- `minigameCursorSpeed = baseCursorSpeed / (1 + rodSteadiness + enchantSteadiness)` *(Steadiness càng cao kim chạy càng êm!)*.

---

### 2.4. Mở Rộng Schema `PlayerProfile` (Tương thích ngược 100% qua `Util.Reconcile`)
```lua
-- Cac truong bo sung vao PlayerProfile (giu nguyen toan bo truong cu):
equippedHotbarSlot = 1,                  -- 0 = tay khong, 1 = Can cau, 2..5 = Ca cam khoe
pinnedFishUids = { "", "", "", "" },     -- Tối đa 4 uid cá ghim lên ô Hotbar 2..5
rodEnchants = {},                        -- { [exclusiveRodId] = enchantId } (GIU KHI REBIRTH)
enchantRelics = 0,                       -- Da Phu Phep dung xoay dong (GIU KHI REBIRTH)
completedBounties = {},                  -- Tien do doi ca tai NPC Collector
playtimeClaimed = {},                    -- Cac moc Playtime Gifts da nhan trong phien (reset moi phien hoac moi ngay)
sessionJoinClock = 0,                    -- Tinh thoi gian mo qua Playtime Gifts
settings = {
    autoLockLegendaryPlus = true,        -- Mac dinh BAT chong ban nham ca Legendary/Boss!
    autoLockMutated = true,              -- Mac dinh BAT chong ban nham ca Shiny/Golden/Cosmic!
    lowGfx = false,                      -- Che do nhe may cho dien thoai treo dem
    muteSfx = false,
}
-- Moi phan tu CaughtFish trong fishBag bo sung:
-- sizeTier: "Normal" | "Big" | "Giant" | "Titanic"
-- locked: boolean
```

---

### 2.5. Quy Định An Toàn Kỹ Thuật Cho Nước `Terrain` & `ViewportFrame`
1. **Nước biển sóng thật (`Terrain Water`):**
   - Vẫn **CẤM TUYỆT ĐỐI** gán `part.Material = Enum.Material.Water` lên `BasePart`.
   - Chỉ tạo nước bằng `Workspace.Terrain:FillBlock(waterCFrame, waterSize, Enum.Material.Water)` sau khi `Workspace.Terrain:Clear()`, kết hợp đáy cát cứng `LagoonSeabed` bên dưới để lội nước nông an toàn.
   - Cập nhật quy tắc số 2 trong `tools/verify_project.ps1`: Chặn phép gán `.Material = Enum.Material.Water`, nhưng cho phép phép so sánh `== Enum.Material.Water` / `~= Enum.Material.Water` trong hàm `Raycast` kiểm tra mặt nước vs. đất liền!
2. **Tối ưu FPS cho `ViewportFrame` Grid:**
   - Chỉ khởi tạo/render các ô `ViewportFrame` khi cửa sổ (`Bag` / `Shop` / `Pets` / `Index`) đang mở (`Visible == true`).
   - Dùng chung kho mẫu 3D tĩnh trong `ReplicatedStorage` clone nhẹ vào `ViewportFrame` (không gắn `Humanoid` hay `WorldModel` vật lý nặng vào từng ô lưới), tự giảm chi tiết khi bật `Low GFX`.

---

## 3. KIẾN TRÚC MODULE MỚI / NÂNG CẤP (100% FILE `.luau` ≤ 350 DÒNG)

Không xóa bất kỳ file nào đã có; chỉ nâng cấp gọn file hiện hữu và bổ sung các module chuyên biệt nhỏ gọn:

```text
src/
├── shared/
│   ├── Config/
│   │   ├── EnchantsConfig.luau        ← [MỚI] 6 dòng Enchant + tỉ lệ xoay cho Cần Exclusive
│   │   ├── BountiesConfig.luau        ← [MỚI] Danh sách nhiệm vụ nộp Cá đổi Gems/Relic/Mồi + mốc Playtime Gifts
│   │   ├── RanksConfig.luau           ← [MỚI] Danh hiệu trên đầu (Overhead Title) & màu Aura theo Strength/Rebirth
│   │   └── RodsConfig.luau            ← [NÂNG CẤP] 5 chỉ số + 3 Cần Exclusive scaling
│   └── ModelBuilders/                 ← [MỚI - Dùng chung cho cả Server 3D World & Client ViewportFrame UI!]
│       ├── FishModelBuilder.luau      ← Tạo hình chi tiết 5 họ Cá (Thon, Kiếm, Đuối, Cá Mập, Thủy Quái Boss)
│       ├── PetModelBuilder.luau       ← Tạo hình Pet Chibi mắt long lanh, tai/cánh/sừng, vòng hào quang
│       └── RodAndWeightBuilder.luau   ← Tạo hình 6 Cần thường + 3 Cần Exclusive phát sáng + Tạ cầm tay 3D
├── server/
│   ├── World/
│   │   ├── TerrainWaterBuilder.luau   ← [MỚI] Đổ Terrain Water sóng thật + đảo đa tầng + tiểu cảnh đời sống
│   │   ├── NpcBuilder.luau            ← [MỚI] Dựng 4 NPC R15 người thật có trang phục, phụ kiện & Idle thở
│   │   ├── WhirlpoolManager.luau      ← [MỚI] Xoáy nước cá hiếm nổi ngẫu nhiên trên biển (+2x Luck)
│   │   └── PlayerVisuals.luau         ← [MỚI] Overhead Rank Title, Aura dưới chân, cầm Cá khoe & cầm Tạ tập Gym
│   └── Services/
│       ├── EnchantAndBountyService.luau ← [MỚI] Xoay dòng Exclusive Rod, Thẩm định cá (Appraise), Đổi cá & Playtime Gifts
│       └── (Nâng cấp gọn FishingService, CurrencyService, ShopAndItemsService, PerkService)
└── client/
    ├── Controllers/
    │   ├── HotbarAndCastController.luau ← [MỚI] Thanh Hotbar 1..5, giữ chuột nạp lực Cast, Raycast & diễn hoạt nảy đất
    │   └── EggHatchCutscene.luau        ← [MỚI] Hiệu ứng quả trứng rung lắc nứt vỏ nổ sáng (có nút Skip nhanh)
    └── UI/
        ├── Components/
        │   ├── ViewportCard.luau        ← [MỚI] Ô thẻ vuông 3D ViewportFrame + nhãn đột biến + ổ khóa 🔒 + thông số đáy
        │   ├── HotbarAndBaitUi.luau     ← [MỚI] Thanh Hotbar đáy + Nút Auto phía trên + Popup Chọn Mồi góc phải dưới
        │   └── NpcDialogueModal.luau    ← [MỚI] Khung trò chuyện NPC đa lựa chọn kiểu Fisch + Camera nghiêng nhẹ
        └── Panels/
            ├── PlaytimeAndSettingsModal.luau ← [MỚI] Bảng 9 ô Quà Online đếm ngược + Cài đặt Auto-Lock & Low GFX
            └── EnchantAndBountyModal.luau    ← [MỚI] Giao diện Bệ Phù Phép Exclusive Rod & Bảng Đổi Cá Collector
```

---

## 4. LỘ TRÌNH THI CÔNG 4 CHẶNG ĐẠI TU (PHASE 2 ROADMAP)

Trạng thái: `[ ]` Chưa làm · `[~]` Đang làm · `[x]` Đã hoàn thành & PASS 6/6.

### 🏝️ CHẶNG A: ĐẠI TU THẾ GIỚI 5 ĐẢO, NƯỚC SÓNG THẬT, XOÁY NƯỚC & NPC HỘI THOẠI
> **Mục tiêu:** Bước vào game thấy ngay cảnh biển sóng sánh thật, đảo có đồi đá/hải đăng/lửa trại có hồn, xoáy nước cá hiếm sôi sục ngoài khơi và dàn NPC người thật đứng trò chuyện.

- [ ] **A1 — Nước Biển Sóng Thật (`Terrain Water`) & Địa Hình 5 Đảo Đa Tầng Chi Tiết:**
  - Cập nhật `verify_project.ps1` cho phép so sánh `Enum.Material.Water` khi Raycast; viết `TerrainWaterBuilder.luau` và nâng cấp cảnh quan 5 Đảo (vách đá tầng, đồi cỏ, bờ cát thoải, ngọn hải đăng Đảo 1, rạn san hô sủi bọt Đảo 2, đền cổ đầm lầy Đảo 3, miệng núi lửa phun khói Đảo 4, đài thiên văn tinh thể Đảo 5 + Bệ Đá Phù Phép `Enchant Altar`, hàng rào dây thừng, thùng gỗ, đèn bão, hạt đom đóm bay).
- [ ] **A2 — Hệ Thống Xoáy Nước Cá Hiếm Trên Biển (`WhirlpoolManager.luau`):**
  - Mỗi 2.5–4 phút tự động xuất hiện xoáy nước phát sáng kèm cột tia sáng + đàn bóng cá bơi vòng dưới mặt nước tại các đảo; quăng phao trúng vùng xoáy kích hoạt **`2x Luck` + `2x Boss Chance`**.
- [ ] **A3 — Dàn 4 NPC Người Thật R15 (`NpcBuilder.luau`) & Khung Hội Thoại Đa Nhánh (`NpcDialogueModal.luau`):**
  - Thay toàn bộ NPC khối thô bằng mô hình nhân vật R15 có quần áo, mũ nón, khuôn mặt, cử động đứng thở/vẫy tay tự nhiên (Merchant, Shop/Crafter, Appraiser/Collector, Gym Coach) kèm hộp thoại chọn nhánh mượt mà và hiệu ứng nghiêng nhẹ Camera khi nói chuyện.

---

### 🎣 CHẶNG B: HOTBAR CẦM ĐỒ/KHOE CÁ, VẬT LÝ QUĂNG PHAO NẢY ĐẤT, 5 CHỈ SỐ CẦN & EXCLUSIVE ROD
> **Mục tiêu:** Cảm giác cầm cần, giữ lực quăng phao, nảy phao trên đất liền, đấu cá cong cần và xoay dòng Cần Exclusive sướng tay đúng chuẩn *Fisch*.

- [ ] **B1 — Custom Hotbar (`1..5`), Rút/Cất Cần, Cầm Cá Khoe Hàng & Cụm Chọn Mồi Nhanh + Auto Trên Hotbar:**
  - Ẩn thanh công cụ mặc định của Roblox; dựng `HotbarAndBaitUi.luau` dưới đáy màn hình, đặt 2 nút `Auto-Train` & `Auto-Fish` gọn ngay phía trên Hotbar, và làm ô **Chọn Mồi Nhanh** xổ danh sách mồi ở góc dưới bên phải. Cho phép ghim tối đa 4 con cá vào ô `2..5` để rút cá ra cầm trên 2 tay khoe khắp đảo.
- [ ] **B2 — Bấm/Giữ Màn Hình Quăng Phao, Vật Lý Nảy Đất, Phân Cấp Auto Free/Pro & Chống Kẹt Minigame (`6.5s`):**
  - Nhấn giữ chuột nạp thanh *Cast Power* (`Perfect = +25% Luck`); phân biệt chuẩn `Auto-Fish` thường miễn phí (`0%` Cast Luck) vs. Gamepass `Auto-Fish Pro` (`+25%` Perfect Cast Luck + quăng nhanh).
  - Làm quỹ đạo phao bay vòng cung + **hiệu ứng bật nảy ngược trên đất liền** khi quăng trượt nước; thêm dấu **`!`** giật nảy khi cá đớp, **uốn cong đầu cần câu + Camera zoom nhẹ** khi vào Minigame, và **tự động đứt dây sau `6.5s` nếu AFK không bấm** rồi tự câu tiếp.
- [ ] **B3 — Hệ Thống 5 Chỉ Số Cần Câu, 3 Cần Exclusive Scaling & Bệ Xoay Dòng Phù Phép (`Enchant Altar`):**
  - Nâng cấp `RodsConfig.luau` lên đủ 5 chỉ số (`Max Weight`, `Lure Speed`, `Luck`, `Control`, `Steadiness`) + 3 cây Cần Exclusive tự động tính sức mạnh bằng `115%–125%` cây cần thường khỏe nhất đang có; hoàn thiện `EnchantsConfig.luau` và tính năng xoay 6 dòng Enchant bằng *Enchant Relic* hoặc *Gems*.

---

### 🎒 CHẶNG C: GIAO DIỆN Ô LƯỚI HÌNH 3D TO (`VIEWPORTFRAME GRID`), KHÓA CÁ, BÁN CHỌN LỌC & ĐỔI ĐỒ
> **Mục tiêu:** Mở bất kỳ menu nào cũng bắt mắt như game triệu view với thẻ 3D sắc nét, khóa giữ cá quý, chọn cá lẻ để bán, thẩm định kích thước và nhận quà ngồi chơi online.

- [ ] **C1 — Bộ Thẻ Ô Lưới 3D (`ViewportCard.luau`) Cho Toàn Bộ `Bag`, `Shop`, `Pets` & `Index`:**
  - Chuyển đổi toàn bộ danh sách chữ sang lưới ô vuông 4–5 cột: hình mô hình 3D con cá / pet / cần câu to rõ chính giữa ô, nền chuyển sắc theo độ hiếm, nhãn bậc kích thước (`Big / Giant / Titanic`) & đột biến ở góc trên, cân nặng/giá bán chữ nhỏ gọn ở đáy ô.
- [ ] **C2 — Khóa Cá (`🔒 Lock`), Bán Từng Con / Bán Nhiều Con Đã Chọn / Bán Cá Đang Cầm:**
  - Bổ sung nút `Lock` bảo vệ cá quý, chế độ `Multi-Select` tích chọn các con cá muốn bán (hiện tổng tiền trực tiếp), nút `Sell Held Fish` trong hội thoại NPC Merchant, và bộ tự động khóa cá hiếm/đột biến (`Auto-Lock`).
- [ ] **C3 — NPC Thẩm Định Cá (`Appraise`), Nhiệm Vụ Đổi Cá (`Fish Bounty`) & Hộp Quà Online (`Playtime Gifts` + `Settings`):**
  - Hoàn thiện tính năng trả Gold cho NPC đo lại cân nặng/đột biến con cá đang cầm trên tay, bảng nộp cá đổi lấy *Enchant Relic / Gems / Boss Bait*, cùng hộp quà đếm ngược 9 mốc thời gian ngồi chơi và bảng Cài đặt (`Low GFX`, `Auto-Lock`, `Mute`).

---

### 🐉 CHẶNG D: ĐẠI TU MÔ HÌNH 3D CHI TIẾT CAO, ĐẬP TRỨNG, DANH HIỆU/AURA, CẦM TẠ THẬT & ÂM THANH
> **Mục tiêu:** Đẩy phần nhìn của Cá, Pet, Nhân vật và Âm thanh lên mức trau chuốt cao nhất trước khi Publish.

- [ ] **D1 — Thư Viện Tạo Hình 3D Chi Tiết Cao Cho 5 Họ Cá & 6 Dòng Pet Chibi (`ModelBuilders/`):**
  - Viết mới `FishModelBuilder.luau` (tách rõ dáng Cá Thon, Cá Kiếm mũi nhọn, Cá Đuối cánh rộng, Cá Mập vây dữ, Thủy Quái Boss nhiều đốt có sừng/râu phát sáng) và `PetModelBuilder.luau` (dáng Chibi đáng yêu có đốm mắt trắng, má hồng, tai/sừng/cánh vỗ động và hiệu ứng hạt sáng).
- [ ] **D2 — Hiệu Ứng Đập Trứng (`EggHatchCutscene.luau`), Danh Hiệu Trên Đầu, Hào Quang (`Aura`) & Cầm Tạ 3D Thật:**
  - Quả trứng hiện ra giữa màn hình rung lắc, nứt vỏ tóe ánh sáng theo màu độ hiếm khi mở (có nút `Skip` nhanh); gắn **Overhead Rank Title** + vòng **Aura** dưới chân nhân vật theo mốc Strength/Rebirth; lúc tập Gym hai bàn tay nhân vật **nắm thật vào quả tạ đôi / đòn tạ 3D** chuyển động khớp theo nhịp nâng!
- [ ] **D3 — Đại Tu Animation Toàn Thân & Hệ Thống Âm Thanh Đa Lớp + Kiểm Định Tổng Thể:**
  - Tinh chỉnh diễn hoạt cả thân người (xoay hông vung cần, ngả lưng kéo cá Boss, giơ cao cá khoe hàng), bổ sung âm thanh nền sóng biển nhẹ + bộ SFX chi tiết (dây vút, phao tủm, đập đất cộc, chuông báo Boss, cuộn dây rẹt rẹt, đập trứng nổ pháo) và rà soát toàn bộ hiệu năng/bảo mật đạt PASS 6/6.

---

## 5. GHI CHÚ KHI ĐƯA CHO GPT / CODEX REVIEW HOẶC PHỐI HỢP THI CÔNG
1. Toàn bộ 49 file nền tảng từ Giai đoạn 1 (`commit 118e101`) đang hoạt động sạch sẽ (`0` lỗi `luau-lsp --strict`, `0` lỗi `selene`).
2. Khi thi công từ **Chặng A → Chặng D**, luôn giữ nguyên các nguyên tắc:
   - Mọi tính toán tiền tệ, khóa cá, xoay dòng Enchant, thẩm định cá và kiểm tra `Max Weight` đều nằm trên **Server**.
   - Không tạo RemoteEvent rải rác ngoài `src/shared/Net.luau`.
   - Không để bất kỳ file `.luau` nào vượt quá **350 dòng**; luôn chạy `powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1` đạt `[PASS] 6/6` cuối mỗi mục!
