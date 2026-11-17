# PLAN.md — MIGHTY ANGLER v2 (Fishing + Gym Simulator, Roblox)

> **Nguồn sự thật duy nhất (Single Source of Truth)** của dự án tại `D:\Projects\mighty-angler`, dùng chung liên thông giữa **Antigravity** và **OpenAI Codex**.
> - **Ngày chốt thiết kế:** 2026-11-18
> - **Phiên bản:** Launch v1.0 (5 Đảo chất lượng cao + kiến trúc mở rộng nhanh cho các đợt Update sau)
> - **Nguyên tắc thi công:** Chạy tự động trọn gói theo **3 Chặng lớn** (người dùng không cần ngồi canh từng bước nhỏ; xong mỗi chặng mới mở Roblox Studio kiểm tra 1 lượt ~5–10 phút). Giới hạn cứng **≤ 350 dòng / file `.luau`**.

---

## 1. TỔNG QUAN SẢN PHẨM & QUYẾT ĐỊNH ĐÃ CHỐT

### 1.1. Ý tưởng cốt lõi (Core Loop 2 trục nâng cấp)
Game Roblox Simulator kết hợp **Câu cá kiếm vàng (Gold)** và **Tập Gym tăng sức mạnh (Strength)**:

```
Câu cá (Cá thường tự lên / Cá Hiếm-Boss có Minigame) ──→ Bán lấy Gold
   ▲                                                          │
   │                                                          ▼
   │                     Mua Đảo mới (1→5) + Mồi câu + Đồ tập Gym + Trứng Gold
   │                                                          │
   └── Mua & Cầm Cần câu xịn ◄── Đủ mốc Strength ◄── Tập Gym (Click chuột / Auto-Train)
       (+ Strength giúp cá cắn nhanh hơn nhẹ & thanh Minigame rộng hơn)
```

### 1.2. Bảng chốt thiết kế của Chủ dự án (User Decisions)
| Mã | Hạng mục | Quyết định chính thức |
|----|----------|-----------------------|
| **D1** | **Vai trò Gold & Strength** | **Gold** dùng mở khóa Đảo mới, mua Cần câu, Mồi câu, Đồ tập Gym, Trứng Pet Gold. **Strength** vừa là điều kiện bắt buộc để cầm Cần câu cấp cao, vừa cho **lợi thế thực chiến lúc câu** (giảm nhẹ thời gian chờ cá cắn & mở rộng nhẹ thanh đỡ Minigame khi gặp cá Hiếm/Boss, có trần cân bằng). |
| **D2** | **Cảm giác Câu cá** | Quăng cần có Animation + phao nhấp nhô. **Cá thường (Common/Uncommon) tự động giật lên luôn** (nhàn tay, cá 3D văng lên + chữ nổi `+Gold`). Chỉ khi gặp **cá Hiếm / Boss (Rare+)** mới hiện thanh **Minigame** kịch tính. |
| **D3** | **Tập Gym & Tách quyền lợi Auto** | Bước vào máy tập **bấm chuột (click/tap)** để nhân vật diễn Animation nâng tạ/chạy bộ thật + nhảy `+Strength`. **Tách riêng 2 gói Auto thương mại:**<br>• **Auto-Train (Tự tập Gym):** Miễn phí khi **Join Roblox Group** (kéo thành viên cho Group).<br>• **Auto-Fish (Tự quăng cần liên tục):** Mở khóa bằng **Gamepass giá rẻ** (kèm hệ sinh thái Gamepass kiếm Robux).<br>*(Trong Roblox Studio có cờ bật sẵn quyền Auto để chủ dự án test nhanh trước khi điền ID thật).* |
| **D4** | **Đồ họa 3D & Ngôn ngữ** | **UI/Text trong game bằng Tiếng Anh** chuẩn thị trường Roblox quốc tế. Cảnh quan, máy tập, cần câu, cá, pet do AI dựng **Low-Poly mượt đẹp bằng code API chuẩn**, kèm cơ chế **`Assets Override`** (thả mô hình 3D từ Toolbox vào thư mục `Assets` đúng tên là game tự động dùng mẫu đó thay cho mẫu code). |
| **D5** | **Quy mô Bản Launch** | Tập trung làm thật chất lượng **5 Đảo đặc sắc nhất** + cổng **"COMING SOON — NEXT UPDATE!"** ở cuối Đảo 5. Cấu hình tách rời từng đảo để sau này ra bản Update Đảo 6, 7... cực nhanh. |
| **D6** | **Nhịp kiểm thử** | Chia dự án thành **3 Chặng lớn chạy tự động**. AI tự thi công và tự quét lỗi kỹ thuật trong suốt cả chặng; người dùng chỉ cần mở Studio kiểm tra **3 lần** tương ứng 3 cột mốc lớn. |

---

## 2. THÔNG SỐ THIẾT KẾ & ĐƯỜNG CONG KINH TẾ (5 ĐẢO LAUNCH)

### 2.1. Năm Đảo bản Launch v1.0 (Mở khóa bằng Gold)
Mỗi đảo có bảng màu, ánh sáng, cây cối/vật trang trí Low-Poly đặc trưng, khu nước câu cá, 3 máy tập Gym (Dumbbells / Treadmill / Bench Press), quầy Sell, 2 trụ Trứng Pet (Gold & Gems) và cổng sang đảo kế tiếp:

| # | Tên Đảo (UI Tiếng Anh) | Giá mở khóa | Chủ đề hình ảnh Low-Poly | Hệ số giá Cá & Gym |
|---|------------------------|-------------|--------------------------|--------------------|
| **1** | **Sunny Shores** | Miễn phí | Bãi biển nắng vàng, cát mịn, dừa cong, cầu gỗ, dù biển | `×1.0` |
| **2** | **Coral Depths** | `2,500 Gold` | Vịnh san hô xanh ngọc phát sáng, đá biển, bong bóng nước | `×4.5` |
| **3** | **Mystic Swamp** | `25,000 Gold` | Đầm lầy tím huyền ảo, nấm khổng lồ phát quang, đèn lồng | `×20` |
| **4** | **Ember Isle** | `200,000 Gold` | Đảo núi lửa cam đỏ, đá đen bóng (`Slate`), khe dung nham `Neon` | `×90` |
| **5** | **Celestial Deep** | `1,500,000 Gold` | Vịnh tinh thể thiên hà tím hồng lơ lửng + cổng *Next Update* | `×400` |

- Mỗi đảo có **7 loài cá** (`Common`, `Uncommon`, `Rare`, `Epic`, `Legendary` + **1 Boss đảo**).
- **Đột biến (Mutations):** *Shiny* (`×2` giá, `5%`) · *Golden* (`×5` giá, `2%`) · *Cosmic* (`×12` giá, `0.5%`).

### 2.2. Sáu Cần câu (Mua bằng Gold + Yêu cầu mốc Strength)
| # | Tên Cần câu | Giá Gold | Yêu cầu Strength | Rod Power | Đảo mục tiêu |
|---|-------------|----------|------------------|-----------|--------------|
| **1** | **Twig Rod** | Miễn phí | `0` | `1` | Đầu Đảo 1 |
| **2** | **Bamboo Rod** | `500` | `1,500` | `2` | Cuối Đảo 1 → Đảo 2 |
| **3** | **Carbon Rod** | `5,000` | `12,000` | `3` | Đảo 2 → Đảo 3 |
| **4** | **Mystic Vine Rod** | `45,000` | `90,000` | `4` | Đảo 3 → Đảo 4 |
| **5** | **Magma Core Rod** | `350,000` | `650,000` | `5` | Đảo 4 → Đảo 5 |
| **6** | **Celestial Rod** | `2,500,000` | `4,500,000` | `6` | Tối thượng Đảo 5 |

- **Tác dụng thực chiến của Strength khi câu cá:**
  - So với mốc yêu cầu của cần đang cầm, lượng Strength tích lũy giúp **tăng nhẹ tốc độ cắn câu (tối đa `+20%`)** và **mở rộng nhẹ thanh xanh Minigame cá Hiếm/Boss (tối đa `+25%` độ rộng)** — giúp người chơi tập Gym xong ra câu thấy khỏe tay ngay lập tức mà không làm mất cân bằng.

### 2.3. Vật phẩm bổ trợ, Pet, Rebirth & Kiếm tiền (Monetization)
- **Mồi câu (Bait — 4 loại mua bằng Gold, trừ 1 viên mỗi lần câu thành công):**
  - `Worm Bait` (`25G`, `+25% Luck`) · `Shiny Bait` (`200G`, `+60% Luck`) · `Boss Bait` (`1,500G`, `+40% Luck`, `×3 Boss Chance`) · `Cosmic Bait` (`8,000G`, `+120% Luck`, `+50% Mutation`).
- **Đồ tập Gym (Gym Gear — 4 cấp mua tuần tự bằng Gold, nhân vĩnh viễn cho tới khi Rebirth):**
  - `Wrist Straps` (`2,500G`, `+20%`) → `Lifting Gloves` (`20,000G`, `+40%`) → `Power Belt` (`150,000G`, `+75%`) → `Titan Suit` (`1,000,000G`, `+120%`).
- **Pets (2 Trứng mỗi đảo = 10 Trứng cho 5 đảo):**
  - *Gold Egg* (mua bằng Gold theo đảo: thường → hiếm, buff `+5%` đến `+15%`) & *Gem Egg* (mua bằng Gems: Epic → Mythic, buff `+25%` đến `+60%`).
  - Mặc định trang bị **2 Pet** bay lượn hai bên sau lưng nhân vật (nâng lên **4 Pet** nếu sở hữu Gamepass `+2 Pet Slots`).
- **Thuốc Buff (Potions — 5 loại × 2 cỡ Small 5 phút / Large 10 phút):**
  - `Lucky Elixir` (Luck), `Titan Brew` (Strength), `Gold Draught` (Sell), `Mutagen Vial` (Mutation), `Swift Tonic` (Bite Speed). Nhận từ: Boss drop, câu cá hiếm, Thành tựu, Rebirth, Server Event.
- **Chuyển sinh (Rebirth):**
  - Yêu cầu Strength khởi điểm từ `5,000,000` (cuối Đảo 5), tăng dần theo cấp Rebirth; thưởng **Gems + Gói Potions + Hệ số nhân Strength & Sell vĩnh viễn (`+50%` mỗi lần)**. Giữ lại Gems, Pets, Potions, Index, Achievements.
- **Hệ thống Thương mại hóa (Group & Gamepasses):**
  - **Free Group Perk:** `Auto-Train` (tự động tập Gym khi đứng trên máy).
  - **Gamepasses (cấu hình ID tập trung tại `GamepassesConfig.luau`):**
    1. `Auto-Fish` (giá rẻ chủ lực — tự động quăng cần lặp lại)
    2. `x2 Gold` (nhân đôi tiền bán cá)
    3. `x2 Strength` (nhân đôi điểm tập Gym)
    4. `+2 Pet Equip` (đeo 4 Pet cùng lúc)

---

## 3. KIẾN TRÚC KỸ THUẬT & LƯỚI CHỐNG LỖI V1

### 3.1. Cấu trúc thư mục Modular (Mọi file `.luau` bắt buộc `≤ 350 dòng`)
```text
D:\Projects\mighty-angler\
├── PLAN.md                      ← Bản kế hoạch tổng thể này
├── AGENTS.md                    ← Quy chuẩn làm việc cho Antigravity & Codex
├── PROGRESS.md                  ← Sổ bàn giao ca & tiến độ thực tế
├── default.project.json         ← Cấu hình ánh xạ Rojo
├── run.bat                      ← Chạy 1-click build .rbxlx + bật rojo serve
├── tools/
│   ├── rojo.exe                 ← Rojo 7.7.1 (đóng gói & đồng bộ Studio)
│   ├── luau-lsp.exe             ← Trình phân tích kiểu & kiểm tra API Roblox chính chủ
│   ├── globalTypes.d.luau       ← Từ điển định nghĩa API chuẩn của Roblox Engine
│   ├── selene.exe               ← Linter bắt biến thừa / biến chưa khai báo
│   ├── install_tools.ps1        ← Script tự tải/khôi phục bộ công cụ khi sang máy mới
│   └── verify_project.ps1       ← Trạm gác tự động 6 chốt chặn (dòng code, API, LSP, Selene, Build)
└── src/
    ├── shared/
    │   ├── Net.luau             ← Manifest duy nhất cho toàn bộ RemoteEvent
    │   ├── Types.luau           ← Kiểu dữ liệu Profile, Fish, Island, Pet, Item
    │   ├── Util.luau            ← Format số (1.2K, 3.5M), weighted random, math helpers
    │   ├── AssetRegistry.luau   ← Cơ chế kiểm tra model Toolbox override trước khi vẽ code
    │   └── Config/
    │       ├── GameConfig.luau          ← Hằng số chung, GroupId, cờ Dev Studio test
    │       ├── RodsConfig.luau          ← 6 cần câu
    │       ├── BaitConfig.luau          ← 4 mồi câu
    │       ├── GymGearConfig.luau       ← 4 đồ tập gym
    │       ├── PotionsConfig.luau       ← 10 loại thuốc
    │       ├── PetsConfig.luau          ← 10 trứng & danh sách Pet 5 đảo
    │       ├── RebirthConfig.luau       ← Mốc chuyển sinh & phần thưởng
    │       ├── EventsConfig.luau        ← 5 sự kiện toàn server (chu kỳ 30 phút)
    │       ├── AchievementsConfig.luau  ← Thành tựu & nhiệm vụ ngày
    │       ├── GamepassesConfig.luau    ← ID Gamepass & quyền lợi
    │       ├── SoundConfig.luau         ← ID âm thanh an toàn
    │       └── Islands/                 ← TÁCH RIÊNG TỪNG ĐẢO (dễ thêm Đảo 6, 7 sau này)
    │           ├── init.luau
    │           ├── Island1_SunnyShores.luau
    │           ├── Island2_CoralDepths.luau
    │           ├── Island3_MysticSwamp.luau
    │           ├── Island4_EmberIsle.luau
    │           └── Island5_CelestialDeep.luau
    ├── server/
    │   ├── init.server.luau
    │   ├── World/                       ← Dựng cảnh quan Low-Poly tách nhỏ (không phình file)
    │   │   ├── PartFactory.luau         ← Helper tạo Part chuẩn API thật (chặn lỗi vật liệu/shape)
    │   │   ├── WorldBuilder.luau        ← Điều phối dựng 5 đảo & Lighting
    │   │   ├── PropsBuilder.luau        ← Cầu gỗ, quầy Sell, cổng Đảo, máy Gym, trụ Trứng
    │   │   ├── IslandScenery1_2.luau    ← Cây cối & decor riêng Đảo 1–2
    │   │   ├── IslandScenery3_5.luau    ← Cây cối & decor riêng Đảo 3–5 + cổng Coming Soon
    │   │   ├── RodVisuals.luau          ← Cần câu gắn tay nhân vật + dây câu + phao nổi
    │   │   └── PetAndFishVisuals.luau   ← Mô hình Pet bay theo & Cá 3D văng lên khi câu dính
    │   └── Services/
    │       ├── DataService.luau         ← Lưu/tải DataStore an toàn, session lock nhẹ, autosave
    │       ├── BuffAggregator.luau      ← Nơi DUY NHẤT gộp mọi hệ số nhân (Strength/Gold/Luck...)
    │       ├── PerkService.luau         ← Kiểm tra Join Group (Auto-Train) & Gamepass (Auto-Fish...)
    │       ├── CurrencyService.luau     ← Cộng/trừ Gold, Gems, bán cá
    │       ├── FishingService.luau      ← Quăng cần, tự giật cá thường, kiểm duyệt Minigame Rare/Boss
    │       ├── GymService.luau          ← Tập Gym click chuột & vòng lặp Auto-Train trên Server
    │       ├── IslandService.luau       ← Mở khóa đảo bằng Gold & dịch chuyển nhân vật
    │       ├── ShopAndItemsService.luau ← Mua Cần, Mồi, Đồ Gym, dùng Thuốc Potions
    │       ├── PetsService.luau         ← Mở trứng, trang bị 2–4 Pet, cập nhật vị trí Pet
    │       ├── ProgressionService.luau  ← Rebirth, Index sưu tập, Achievements, Daily Rewards
    │       ├── LiveOpsService.luau      ← Server Event 30 phút & Bảng xếp hạng Leaderboard
    │       └── DevTestService.luau      ← Lệnh test nhanh (+Gold/Str, ép Boss, Reset) KHÓA CỨNG chỉ chạy ở Studio
    └── client/
        ├── init.client.luau
        ├── Controllers/
        │   ├── AnimationController.luau ← Diễn hoạt vung cần, kéo cá, nâng tạ, chạy bộ, đẩy ngực
        │   ├── FishingController.luau   ← Điều khiển câu cá, hiệu ứng phao, nút Auto-Fish
        │   ├── GymController.luau       ← Xử lý bấm chuột tập Gym, hiệu ứng mồ hôi/số bay, Auto-Train
        │   ├── SoundAndFxController.luau← Âm thanh, chữ nổi +Gold/+Strength, rung nhẹ camera
        │   ├── PromptController.luau    ← Tương tác gần quầy Sell, cổng Đảo, trụ Trứng, máy Gym
        │   └── StudioErrorReporter.luau ← Tự hiện băng báo lỗi góc màn hình trong Studio (khỏi mò Output)
        └── UI/
            ├── Theme.luau               ← Design System: viền UIStroke tươi sáng, bo góc, nút nhún lò xo, 6 màu độ hiếm
            ├── Components/              ← Nút bấm có hiệu ứng nhún, cửa sổ khung, thẻ vật phẩm, Toast
            └── Panels/                  ← Tách riêng từng màn hình (< 300 dòng/file)
                ├── HudPanel.luau        ← Tiền tệ, thanh Strength, nút Auto-Train / Auto-Fish, nút Menu
                ├── MinigameBar.luau     ← Thanh kéo/căn nhịp khi gặp cá Hiếm & Boss
                ├── BagPanel.luau        ← Túi Cá / Thuốc / Mồi + nút Sell All
                ├── ShopPanel.luau       ← Cửa hàng Cần câu / Mồi / Đồ tập Gym / Gamepasses
                ├── PetsPanel.luau       ← Kho Pet & Ấp trứng
                ├── ProgressPanel.luau   ← Rebirth, Sổ Index, Thành tựu & Quà ngày
                └── DevTestPanel.luau    ← Bảng nút [DEV] 1 chạm trong Studio (+Gold/Str, Force Boss, Event, Reset)
```

### 3.2. Sáu Chốt Chặn An Toàn Kỹ Thuật (Bắt buộc chạy tự động sau mỗi Task)
Để chủ dự án yên tâm cho AI chạy tự động hết cả chặng mà mở Studio lên không gặp lỗi sập ngầm như bản v1, script `tools/verify_project.ps1` sẽ tự động kiểm tra đủ **6 bước**:
1. **Kiểm tra kích thước file:** Báo lỗi ngay nếu bất kỳ file `.luau` nào vượt quá **350 dòng**.
2. **Quét chặn API nguy hiểm:** Cấm `Instance.new("Ball"|"Cylinder"|"Block"|"Wedge")`, cấm gán 13 vật liệu Terrain lên `BasePart`, kiểm tra `CFrame.Angles(rx, ry, rz)` đủ 3 tham số, cấm viết comment giữ chỗ cắt xén code, và bắt buộc mọi `ModuleScript` có `return` ở cuối file.
3. **Rojo Sourcemap:** Ánh xạ cây dự án ra `build/sourcemap.json` chuẩn xác.
4. **`luau-lsp analyze` + `globalTypes.d.luau`:** Đối chiếu toàn bộ mã nguồn với từ điển API chính chủ của Roblox Engine (bắt sai tên thuộc tính, sai kiểu tham số, gọi nhầm `require`).
5. **`selene` Linter (`std = "roblox"`):** Bắt sạch biến chưa khai báo, biến gán nhầm và lỗi cú pháp Luau.
6. **Rojo Build Pass:** Xuất thành công `build/mighty-angler-dev.rbxlx` với mã thoát `0`.

### 3.3. Quy chuẩn Giao diện & Công cụ Test nhanh cho Chủ dự án
- **Visual Vibe (Design System chốt từ đầu):** Phong cách Roblox Simulator ăn khách (kiểu *Pet Simulator 99 / Arm Wrestle Simulator*) — khung tương phản cao, viền `UIStroke` dày sắc nét, bo góc tròn mềm, nút bấm có hiệu ứng phóng nhẹ khi rê chuột & nảy lò xo khi bấm, chữ có viền dễ đọc trên cả điện thoại. Bảng màu 6 bậc độ hiếm đồng nhất toàn game: *Common (Xám) → Uncommon (Xanh lá) → Rare (Xanh dương) → Epic (Tím) → Legendary (Vàng kim) → Boss/Cosmic (Đỏ rực / Cầu vồng)*.
- **Bảng nút `[DEV]` chỉ hiện trong Roblox Studio:** Giúp chủ dự án kiểm tra trọn vẹn 1 chặng chỉ trong 3–5 phút bằng các nút bấm 1 chạm (`+Gold`, `+Strength`, `+Gems`, `Force Boss Next Cast`, `Trigger Event`, `Reset Data`) mà không cần ngồi cày chay hàng giờ hay gõ lệnh Command Bar. Khi Publish lên Roblox, bảng này và remote tương ứng tự động khóa 100% đối với người chơi thường.
- **Băng báo lỗi trực quan `StudioErrorReporter`:** Trong Studio, nếu có bất kỳ lỗi đỏ nào phát sinh, game tự hiện thông báo nhỏ trên góc màn hình để chủ dự án chụp ảnh gửi AI xử lý trong vài giây.

---

## 4. LỘ TRÌNH THI CÔNG 3 CHẶNG TỰ ĐỘNG (MILESTONES)

Trạng thái: `[ ]` Chưa làm · `[~]` Đang làm · `[x]` Đã hoàn thành & Verify xanh.

### 🟢 CHẶNG 1: ĐẢO 1 HOÀN CHỈNH & CẢM GIÁC CHƠI CỐT LÕI (CORE VERTICAL SLICE)
> **Mục tiêu:** Chạy tự động một mạch từ khung dự án đến khi chơi trọn vẹn, mượt mà và đẹp mắt ngay tại **Đảo 1 (Sunny Shores)**.
> **Nghiệm thu Studio Lần 1 (~5 phút):** Mở `run.bat` → đi dạo Đảo 1 ngắm cảnh Low-Poly, quăng cần câu cá thường (tự lên) & cá Hiếm/Boss (Minigame), ra máy Gym bấm chuột & bật thử `Auto-Train` / `Auto-Fish`, bán cá mua Cần mới, thoát ra vào lại giữ nguyên dữ liệu.

- [ ] **M1.1 — Bộ kiểm tra tự động & Nền tảng Shared (`Net`, `Types`, `Util`, `AssetRegistry`, Config cơ bản):**
  - Tạo `tools/verify_project.ps1`, `Net.luau`, `Types.luau`, `Util.luau`, `AssetRegistry.luau`, `GameConfig.luau`, `RodsConfig.luau` và `Island1_SunnyShores.luau`.
- [ ] **M1.2 — Dựng Cảnh quan Low-Poly Đảo 1 & Ánh sáng (`PartFactory`, `WorldBuilder`, `PropsBuilder`, `IslandScenery1_2`):**
  - Dựng Đảo 1 *Sunny Shores* có bãi cát, biển trong xanh, cầu gỗ câu cá, 3 máy tập Gym chi tiết, quầy bán cá, cổng khóa Đảo 2, hàng dừa cong và bộ `Lighting` tươi sáng; đảm bảo `SpawnLocation` vững chắc 100%.
- [ ] **M1.3 — Dữ liệu Người chơi, Tiền tệ, Quyền lợi Auto & Khung `BuffAggregator`:**
  - Hoàn thiện `DataService` (lưu/tải an toàn + làm việc trơn tru cả khi Studio chưa bật API Services bằng chế độ fallback thông báo rõ), `CurrencyService`, `PerkService` (tách rõ `Auto-Train = Join Group` và `Auto-Fish = Gamepass` + công tắc test Studio) và `BuffAggregator`.
- [ ] **M1.4 — Hệ thống Câu cá Server + Visual Cần/Phao/Cá + Animation + Minigame:**
  - Cần câu gắn trên tay nhân vật, Animation vung cần & giật cá, dây câu + phao nhấp nhô; cá thường tự giật lên nảy mô hình cá 3D + chữ `+Gold`, cá Rare/Boss bật thanh `MinigameBar` (có hưởng lợi thế từ Strength); tích hợp nút `Auto-Fish`.
- [ ] **M1.5 — Hệ thống Tập Gym Click chuột + Auto-Train + Animation Tập luyện:**
  - Bước vào 3 máy Gym bấm chuột diễn Animation nâng tạ / chạy bộ / đẩy ngực thật + tia sáng + số bay `+Strength`; bật nút `Auto-Train` tự tập mượt mà theo chuẩn kiểm tra của Server.
- [ ] **M1.6 — Giao diện Tiếng Anh Đảo 1 (`Theme`, `HudPanel`, `BagPanel`, `ShopPanel`, `DevTestPanel`, `StudioErrorReporter`):**
  - Thiết kế UI chuẩn Simulator hiện đại (nút nhún lò xo, viền `UIStroke`, chữ rõ trên PC & Mobile); tương tác quầy Sell All, mua & trang bị 6 Cần câu, gắn sẵn bảng nút **`[DEV]` chỉ hiện trong Studio** (`+Gold`, `+Strength`, `Force Boss`, `Reset Save`) + hộp đen báo lỗi trực quan `StudioErrorReporter`, đóng gói `build/mighty-angler-dev.rbxlx` sẵn sàng cho **Lần Check Studio 1**.

---

### 🔵 CHẶNG 2: MỞ RỘNG ĐỦ 5 ĐẢO & CHIỀU SÂU VÒNG LẶP (ECONOMY & PETS)
> **Mục tiêu:** Hoàn thiện trọn bộ **Đảo 2 → Đảo 5**, đưa vào Mồi câu, Đồ tập Gym, Thuốc Potions và hệ thống Trứng Pet bay theo sau lưng.
> **Nghiệm thu Studio Lần 2 (~5–7 phút):** Mua cổng mở khóa xuyên suốt 5 đảo, ấp trứng đeo 2 Pet bay lượn, mua mồi & đồ tập gym, uống thuốc buff và cảm nhận nhịp tăng tiến tiền/sức mạnh.

- [ ] **M2.1 — Cấu hình & Cảnh quan Low-Poly cho Đảo 2, 3, 4, 5 + Cổng *Coming Soon*:**
  - Tạo config cá/boss/giá tiền cho `Island2`..`Island5` và dựng cảnh quan riêng biệt (San hô phát sáng, Đầm lầy nấm tím, Núi lửa dung nham, Thiên hà tinh thể + cổng hẹn bản Update kế tiếp); hoàn thiện `IslandService` mở khóa & dịch chuyển.
- [ ] **M2.2 — Mồi câu (Bait), Đồ tập Gym (Gear) & Lọ thuốc (Potions):**
  - Hoàn thiện `BaitConfig`, `GymGearConfig`, `PotionsConfig`, `ShopAndItemsService`; nối toàn bộ hệ số vào `BuffAggregator`; mở rộng đủ 3 tab cho `ShopPanel` và `BagPanel`, hiển thị icon thuốc/mồi đang kích hoạt trên HUD.
- [ ] **M2.3 — Hệ thống 10 Trứng Pet (Gold & Gems) & Mô hình Pet bay theo sau lưng:**
  - Hoàn thiện `PetsConfig` (2 trứng × 5 đảo), `PetsService`, mô hình 3D Low-Poly cho các dòng Pet (bay/nhảy mượt mà 2 bên vai nhân vật), cùng giao diện `PetsPanel` và trụ ấp trứng trực quan tại mỗi đảo.
- [ ] **M2.4 — Cân bằng Kinh tế 5 Đảo & Đóng gói Check Studio Lần 2:**
  - Kiểm toán đường cong giá cá / tốc độ tập Gym / giá mở Đảo / mốc Cần câu từ Đảo 1 đến Đảo 5 đảm bảo mượt, không bị kẹt tiền hay nhảy vọt vô lý; xuất bản build cho **Lần Check Studio 2**.

---

### 🟣 CHẶNG 3: ENDGAME, SỰ KIỆN, ÂM THANH & THƯƠNG MẠI HÓA (READY TO PUBLISH)
> **Mục tiêu:** Đưa game đạt độ hoàn thiện thương mại sẵn sàng Publish lên Roblox, giữ chân người chơi lâu dài và tối ưu doanh thu Robux.
> **Nghiệm thu Studio Lần 3 (~10 phút):** Tổng duyệt Chuyển sinh, Sổ sưu tập, Sự kiện 30 phút, Bảng xếp hạng, Âm thanh và các nút mua Gamepass.

- [ ] **M3.1 — Chuyển sinh (Rebirth) & Sổ sưu tập (Fish/Pet Index):**
  - Hoàn thiện chức năng Rebirth cuối Đảo 5 (nhận Gems + gói thuốc + nhân vĩnh viễn) và Sổ sưu tập thưởng Gems mỗi khi câu được loài cá mới hoặc mở trúng Pet mới.
- [ ] **M3.2 — Thành tựu (Achievements), Quà đăng nhập & Nhiệm vụ hằng ngày:**
  - Hoàn thiện `AchievementsConfig`, bảng tiến độ nhận Gems/Potions tự động, quà điểm danh theo chuỗi ngày và 3 nhiệm vụ đổi mới mỗi ngày trong `ProgressPanel`.
- [ ] **M3.3 — Sự kiện Toàn Server 30 phút, Bảng xếp hạng Đảo 1 & Hướng dẫn Tân thủ:**
  - Vòng quay sự kiện tự động mỗi 30 phút (`Lucky Tide`, `Mutation Surge`, `Iron Will`...), 2 bảng Vinh danh Top Strength & Top Gold tại Đảo 1, cùng mũi tên hướng dẫn nhẹ nhàng cho người mới vào game lần đầu.
- [ ] **M3.4 — Âm thanh (SFX/BGM), Cửa hàng Gamepass Thương mại & Rà soát Bảo mật/Hiệu năng:**
  - Lắp đặt hiệu ứng âm thanh sống động (`SoundAndFxController`), hoàn thiện tab/nút mua nhanh 4 gói Gamepass (`Auto-Fish`, `x2 Gold`, `x2 Strength`, `+2 Pet Equip`), kiểm tra chống spam/hack trên toàn bộ RemoteEvent và tối ưu FPS trên điện thoại trước **Lần Check Studio 3 (Bản Phát Hành)**.

---

## 5. QUY TRÌNH MỞ RỘNG BẢN CẬP NHẬT SAU KHI PHÁT HÀNH (POST-LAUNCH UPDATES)
Nhờ kiến trúc tách rời trong mục 3.1, mỗi khi muốn tung bản cập nhật mới (ví dụ **Update 1: Frostbite Bay & Void Trench**):
1. Tạo thêm `Island6_FrostbiteBay.luau` trong `src/shared/Config/Islands/`.
2. Thêm hàm trang trí cảnh quan Đảo 6 và dời cổng *"COMING SOON"* sang cuối Đảo 6.
3. Thêm 1–2 Cần câu mới vào `RodsConfig.luau` và 2 Trứng mới vào `PetsConfig.luau`.
→ Không cần sửa lại code hệ thống Câu cá, Gym hay UI!
