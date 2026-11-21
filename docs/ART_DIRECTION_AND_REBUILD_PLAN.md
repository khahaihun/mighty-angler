# Mighty Angler v2 — Kế Hoạch Mỹ Thuật & Nâng Cấp Toàn Diện (Art Direction & Master Rebuild Plan)

> **Ngày ban hành:** 2026-11-22 · **Người lập:** Kỹ sư trưởng (Kiến trúc sư kỹ thuật & Review)  
> **Trạng thái duyệt:** Đã chốt hướng đi cốt lõi cùng Chủ dự án · **Chưa chỉnh sửa mã nguồn (`src/`)** · **Chưa duyệt phát hành**  
> **Nền mã hiện tại:** Nhánh `codex/studio-data-isolation`, commit mã sạch `dd53d3a` / tài liệu `20218b8` (**101 file `.luau` ≤ 350 dòng**, 5 file cam kết `< 310`, **13/13** bộ test VM đạt `exit 0`, `verify_project.ps1` **PASS 6/6**). Toàn bộ kiểm thử thực tế trên Roblox Studio, 2 Client ping 200ms, 2 Server Staging và điện thoại thật vẫn đang **chờ nghiệm thu** ([V3_BAN_GIAO_NGHIEM_THU.md](V3_BAN_GIAO_NGHIEM_THU.md)).

---

## 1. Tóm Tắt 5 Quyết Định Cốt Lõi Đã Chốt Với Chủ Dự Án

1. **Đảo thử nghiệm (Pilot) trước khi nhân rộng:** Làm lại **Đảo 1 — Sunny Shores** hoàn chỉnh trước để Chủ dự án bấm **Play (F5)** duyệt phong cách rồi mới nhân sang Đảo 2–5.
2. **Gu mỹ thuật (Phong cách B — Cartoon Vibrant / Glossy Chibi):**
   - Hoạt hình đậm màu, bóng bẩy, dễ thương theo cảm hứng **Pet Simulator 99 × Arm Wrestle Simulator**.
   - Màu sắc rực rỡ, độ tương phản rõ, hình khối tròn đầy dễ đọc ngay cả trên màn hình điện thoại nhỏ, ưu tiên chạy mượt 60 FPS.
3. **Địa hình đảo bằng Terrain tự nhiên (Cách 2 — Studio Map-First + Code Anchors):**
   - Nắn mặt đất, bờ cát cong, đồi cỏ, ghềnh đá và vịnh biển **trực tiếp bằng Terrain Editor trong Roblox Studio** (lưu làm bản đồ gốc / template).
   - Đặt các điểm đánh dấu vô hình (`IslandMarkers`) cho Spawn, Cầu tàu, Vùng nước `FishingWater`, 4 NPC, 3 máy Gym, Bệ Trứng, Bệ Enchant và Cổng đảo.
   - Code `WorldBuilder` khi thấy đảo Terrain dựng sẵn sẽ **giữ nguyên địa hình**, không sinh khối hộp `Part` đè lên nữa, chỉ gắn logic, prompt, xoáy nước và biển tên vào đúng điểm neo.
4. **Hệ thống Trứng & Pet mới (6 Trứng · 24 Pet · Exclusive Pet Scale theo Pet khỏe nhất):**
   - **Trứng Gold (5 mẫu, mỗi đảo 1 trụ):** Mang phong cách riêng của từng đảo (không cần thiết kế vỏ trứng theo từng pet), mỗi trứng nở ngẫu nhiên **4 pet** chủ đề đảo đó (`5 × 4 = 20` pet thường).
   - **Trứng Gem Exclusive (duy nhất 1 trụ đặt tại Hub Đảo 1 — Sunny Shores):** Bệ đá quý sang trọng có hào quang nổi bật, vỏ trứng thiết kế đẳng cấp riêng, nở ngẫu nhiên **4 pet Exclusive siêu đẹp** (chibi tròn mập có cánh, vương miện, hào quang).
   - **Cơ chế sức mạnh của 4 Pet Exclusive:** **Tự scale theo con Pet thường khỏe nhất người chơi đang sở hữu** (chuẩn PS99, đồng bộ hoàn toàn với cơ chế Cần Exclusive đang có trong game), kèm sàn chỉ số tối thiểu để người chơi mới mở sớm vẫn mạnh ngay lập tức.
5. **Ngân sách 0 đồng & Kỷ luật kiểm duyệt Asset:**
   - Ưu tiên 100% tài nguyên **miễn phí & sạch bản quyền** (`CC0 / CC-BY` từ Quaternius, Kenney, Poly Pizza, Sketchfab Free + Roblox Creator Store đã quét sạch Script ẩn + tự dựng/tinh chỉnh trong Roblox Studio / Blender).
   - **Quy tắc bắt buộc:** Mọi asset miễn phí (hoặc tham khảo) đều phải lập **bảng đề xuất có Ảnh xem trước, Link nguồn, Giấy phép và Giá (`0đ`)**. Tuyệt đối **không tự mua hay tự nhét vào game** khi Chủ dự án chưa duyệt từng món.

---

## 2. Bộ Quy Chuẩn Phong Cách Mỹ Thuật (Style Bible — Sunny Shores)

### 2.1. Bảng màu & Ánh sáng Sunny Shores
| Khu vực | Tông màu chủ đạo | Vật liệu gợi ý | Mục tiêu thị giác |
|---|---|---|---|
| **Biển & Vịnh câu** | Xanh ngọc tươi (`#1AA8E0` ➔ `#38D8FF`) | `Terrain Water` sóng nhẹ, độ trong vừa phải | Nhìn rõ phao nổi, bọt sóng và xoáy nước cá hiếm từ xa |
| **Bãi cát & Đường mòn** | Vàng kem nắng ấm (`#F6E0A6`) | `Terrain Sand` + lát đá bước nhẹ | Sáng mặt, phân tách rõ đường đi từ Spawn thẳng ra Cầu tàu |
| **Cỏ & Đồi sau đảo** | Xanh lá tươi (`#52CC58` ➔ `#7CE064`) | `Terrain Grass / LeafyGrass` | Nền dịu mắt giúp làm nổi bật Pet, Quầy chợ và Biển hiệu |
| **Gỗ Cầu tàu & Quầy chợ** | Nâu mật ong ấm (`#A87042`) + mái sọc Đỏ/Trắng & Xanh/Trắng | `WoodPlanks` + `SmoothPlastic` | Cảm giác bến cảng nhiệt đới vui tươi, nhìn 1 giây biết đâu là Chợ / Shop |
| **Điểm nhấn hiếm (Trứng Exclusive, Bệ Enchant, Cá Đột Biến)** | Vàng kim, Tím Neon, Lam Ngọc phát sáng | `SmoothPlastic` bóng + viền `Neon` + `Highlight` mảnh | Tạo cảm giác "đáng khoe" (Social Flex) đúng gu PS99 |

### 2.2. Bố cục mặt bằng Đảo 1 (Sunny Shores Hub)
Mặt bằng giữ trục nhìn mở (**từ điểm Spawn quay mặt thẳng ra Cầu tàu & Biển** để người chơi mới vừa vào game 1 giây đã thấy ngay nước biển, cầu câu và hai quầy chính):
- **Trung tâm (`Spawn`):** Quảng trường tròn sáng sủa, có bảng Xếp hạng Top Strength / Top Gold đặt hơi chếch hai bên lối vào.
- **Phía Nam (hướng Biển):** Đường đá dẫn thẳng ra **Cầu tàu gỗ chữ T** vươn ra vịnh `Terrain Water`; hai bên đầu cầu là **Chợ Cá (Captain Barnaby)** bên trái, **Tiệm Cần & Mồi (Master Kaito)** bên phải, và **Bàn Thẩm Định & Bounty (Old Man Finn)** ngay sát mép cầu.
- **Phía Tây:** **Khu Gym Bãi Biển** (3 bệ tập: Tạ đơn, Máy chạy bộ, Ghế đẩy tạ + **Coach Atlas** đứng cổ vũ) nằm trên nền cát/gỗ phẳng.
- **Phía Đông:** **Quảng trường Trứng** gồm **Trụ Trứng Gold Đảo 1** và **Bệ Trứng Gem Exclusive trung tâm** (làm bậc thang + vòm hào quang riêng để hút ánh nhìn toàn đảo).
- **Góc Đông Bắc (trên đồi cao):** **Ngọn Hải Đăng Sunny Shores** làm cột mốc nhận diện từ xa + **Bệ Phù Phép (`Enchant Altar`)** đặt trên bệ đá cổ phía dưới chân đồi.
- **Phía Bắc:** **Cổng sang Đảo 2 (Coral Depths)** với vòm cổng màu san hô phát sáng.

### 2.3. Chuẩn kỹ thuật cho mọi Model 3D (Asset Contract)
Để mọi model 3D cắm vào game chạy mượt trên điện thoại và không lỗi xoay/lệch tay:
- **Hướng chuẩn (`Orientation`):** Mặt trước của Cá, Pet, NPC, Trứng hướng về `-Z` (trục nhìn chuẩn Roblox); Cần câu có `Grip` làm `PrimaryPart`, mũi cần hướng về `-Z` và có `Attachment` tên `RodTipAttachment` ở đầu cần.
- **Tỷ lệ gốc (`Base Scale`):**
  - Cá gốc: dài khoảng `2.4 – 3.0 studs` (trước khi nhân hệ số *Normal / Big / Giant / Titanic*).
  - Pet Chibi: khối cầu/tròn mập khoảng `1.8 – 2.2 studs` (Pet Exclusive nhỉnh hơn nhẹ `2.2 – 2.6 studs` + có cánh/vòng hào quang).
  - Trứng: cao khoảng `4.5 – 5.2 studs` trên bệ (thu phóng tự động khi vào Viewport và cutscene đập trứng).
- **Ngân sách đa giác (Mobile-safe):**
  - Đạo cụ nhỏ / Cá / Pet thường: `≤ 1,500 – 3,000 tris`.
  - Pet Exclusive / Boss Fish / Cần Exclusive: `≤ 4,000 – 6,000 tris`.
  - Nhà / Quầy / Hải đăng / Máy Gym: `≤ 6,000 – 10,000 tris`.
- **An toàn tuyệt đối:** Mọi model lấy từ Roblox Creator Store hoặc nguồn ngoài đều bị **xóa 100% `Script` / `LocalScript` / `ModuleScript` / `Require` ẩn** trước khi đưa vào `ReplicatedStorage.Assets`.

---

## 3. Thiết Kế Trứng, Pet (Scale Theo Pet Khỏe Nhất) & Cá Đảo 1

### 3.1. Cơ cấu 6 Trứng · 24 Pet toàn game (thay cho cấu trúc cũ 10 Trứng · 30 Pet)
- **5 Trụ Trứng Gold (1 trụ/đảo, mỗi trứng 4 pet):**
  - Đảo 1 (*Sunny Shell Egg*): 4 pet biển nắng dễ thương (Common 55% · Uncommon 28% · Rare 13% · Epic 4%).
  - Đảo 2 (*Coral Pearl Egg*), Đảo 3 (*Spore Pod Egg*), Đảo 4 (*Magma Core Egg*), Đảo 5 (*Starlight Egg*): mỗi trứng 4 pet theo chủ đề đảo.
- **1 Trụ Trứng Gem Exclusive duy nhất tại Đảo 1 (*Sovereign Ocean Egg* — 4 Pet Exclusive):**
  - Vị trí: Quảng trường Trứng ở Đảo 1 (mọi người chơi đều thấy ngay từ phút đầu, và người chơi đảo cao quay về Đảo 1 mở).
  - Chính sách bắt buộc: Giữ nguyên kiểm tra chặt `PolicyService` (`ArePaidRandomItemsRestricted == false` theo chuẩn boolean nghiêm ngặt của V3) trước khi trừ Gems, hiển thị công khai `%` của đủ 4 pet trước khi bấm ấp.
  - **4 bậc Pet Exclusive dự kiến & hệ số Scale theo Pet thường khỏe nhất (`B_pet`):**

| Bậc trong Trứng Exclusive | Tỷ lệ rơi | Hệ số Scale theo `B_pet` | Vai trò & Ngoại hình (Gu B) |
|---|---|---|---|
| **Exclusive I (Epic)** | `60%` | `100%` (`1.00× B_pet`) | Chibi có hào quang nhỏ & phụ kiện biển sang trọng |
| **Exclusive II (Legendary)** | `27%` | `115%` (`1.15× B_pet`) | Có cánh mini + hiệu ứng lấp lánh |
| **Exclusive III (Mythic)** | `10%` | `130%` (`1.30× B_pet`) | Thiết kế rồng/thiên thần biển chibi, vương miện sáng |
| **Exclusive IV (Secret / Divine)** | `3%` | `150%` (`1.50× B_pet`) | Đỉnh cao khoe hàng: cánh lớn phát sáng + vòng hào quang hoàng kim |

> **Công thức tính chỉ số thực tế (Single Source of Truth tại `PetsConfig.GetEffectivePetStats`):**
> - Tìm `B_pet` = con Pet **không phải Exclusive** có `GetPowerScore` cao nhất trong `profile.pets` (tuyệt đối không cho Exclusive tự scale lẫn nhau để tránh vòng lặp).
> - Với mỗi chỉ số (`sellBonus`, `strengthBonus`, `luckBonus`, `mutationBonus`):
>   `effectiveStat = math.max(petDef.floorStat, bestNormalStat * petDef.scaleFactor)`
> - Cả `PetsService` (`BuffAggregator` + `EquipBest`), `OddsCalculator` và `PetsPanel` **dùng chung đúng 1 hàm này** để số hiển thị trên UI luôn khớp 100% với Server.
> - **Tương thích dữ liệu & Boss 3% drop:**
>   - Cập nhật `IslandDef.gemEggId` thành tùy chọn (`string?`), chỉ Đảo 1 gắn Trụ Exclusive Gem.
>   - Boss drop `3%` ở [init.server.luau](file:///d:/Projects/mighty-angler/src/server/init.server.luau) chuyển sang rơi pet hiếm nhất của **Trứng Gold của đảo đó** (hoặc giữ 1 móc riêng theo cấu hình) để Đảo 2–5 không bị `nil` khi bỏ trụ Gem.
>   - Giữ bảng ánh xạ/tương thích ngược cho các `petId` cũ (ví dụ `pet_tiki_spirit` trong bộ test `live_odds.luau` và hồ sơ test cũ) để không phá vỡ bản lưu hiện có.

### 3.2. Danh sách 7 loài Cá Đảo 1 Sunny Shores (Thật + Tưởng tượng)
Giữ nguyên toàn bộ thông số cân nặng, giá tiền và cổng kép (`Power` + `Max Weight`) đã chốt trong [PLAN.md](../PLAN.md):
1. **Sunny Sardine** *(Common — Cá thật)*: cá trích ánh bạc xanh, dễ nhận ra ngay.
2. **Striped Clownfish** *(Common — Cá thật)*: cá hề cam sọc trắng rực rỡ kiểu hoạt hình.
3. **Coastline Snapper** *(Uncommon — Cá thật)*: cá hồng vàng cam vây đỏ nổi bật.
4. **Azure Mahi-Mahi** *(Rare — Cá thật)*: cá nục heo xanh lam–vàng chanh, dáng thuôn đẹp.
5. **Sunset Barracuda** *(Epic — Cá thật pha tưởng tượng)*: cá nhồng thon dài pha sắc tím hoàng hôn & vây ánh cam.
6. **Sunburst Marlin** *(Legendary — Cá thật pha tưởng tượng)*: cá kiếm vây buồm vàng mặt trời có viền phát sáng nhẹ.
7. **King Reef Shark** *(Boss — Tưởng tượng nổi bật)*: cá mập chúa rạn san hô đội vương miện/gai san hô rực đỏ–vàng, cầm 2 tay cực hoành tráng.

---

## 4. Nâng Cấp Kỹ Thuật ("Ổ Cắm 3D" & Terrain Hook) Cần Làm Trước Khi Lắp Asset

Qua rà soát toàn bộ mã nguồn hiện tại, có **5 nâng cấp kỹ thuật nhỏ gọn** (vẫn giữ chặt mọi file `≤ 350` dòng và 5 file cam kết `< 310` dòng) cần làm ở Chặng 2 để cắm đồ 3D vào là chạy đẹp ngay:

1. **Mở rộng [AssetRegistry.luau](file:///d:/Projects/mighty-angler/src/shared/AssetRegistry.luau):**
   - Bổ sung thêm 3 thư mục chuẩn: `Eggs`, `Npcs`, `Buildings` (bên cạnh 6 thư mục cũ `Trees`, `Props`, `Gym`, `Rods`, `Fish`, `Pets`).
   - Hỗ trợ chuẩn hóa neo/vật lý riêng theo loại (ví dụ NPC chỉ neo `HumanoidRootPart`, mở khóa khớp tay chân; đạo cụ/nhà neo toàn bộ).
2. **Sửa lỗi khóa cứng khớp NPC 3D tại [NpcBuilder.luau](file:///d:/Projects/mighty-angler/src/server/World/NpcBuilder.luau):**
   - Bỏ việc truyền `anchored = true` cho toàn bộ bộ phận khi clone NPC 3D từ `AssetRegistry`; chỉ neo `HumanoidRootPart` để NPC R15 thật vẫn thở/vẫy tay mượt trên Client.
3. **Nối `AssetRegistry` cho Trứng & Shop Rod Preview:**
   - [PropsBuilder.luau](file:///d:/Projects/mighty-angler/src/server/World/PropsBuilder.luau) và [EggHatchCutscene.luau](file:///d:/Projects/mighty-angler/src/client/Controllers/EggHatchCutscene.luau) đọc chung model từ `Assets/Eggs/<eggId>` (rơi về khối mặc định nếu chưa có).
   - [RodAndWeightBuilder.luau](file:///d:/Projects/mighty-angler/src/shared/ModelBuilders/RodAndWeightBuilder.luau) (`BuildRodPreview`) đọc chung model từ `Assets/Rods/<rodId>` để cây cần trong Shop 3D giống hệt cây cần cầm trên tay.
4. **Giữ nguyên Đột biến (`Shiny / Golden / Cosmic`), Silhouette Index & Scale trên MeshPart 3D:**
   - Nâng cấp [FishModelBuilder.luau](file:///d:/Projects/mighty-angler/src/shared/ModelBuilders/FishModelBuilder.luau) và [PetModelBuilder.luau](file:///d:/Projects/mighty-angler/src/shared/ModelBuilders/PetModelBuilder.luau) để kể cả khi dùng model 3D override từ `AssetRegistry`:
     - Chế độ `silhouette = true` vẫn phủ màu tối bóng đen chuẩn sổ Index.
     - Đột biến `Shiny / Golden / Cosmic` vẫn gắn `Highlight` + `ParticleEmitter` (gắn thuộc tính `ClientBudgetManaged = true` để tuân thủ V3 P2-05 Low GFX).
     - Dùng `Model:ScaleTo()` chuẩn Roblox Engine thay vì chia tỷ lệ từng Part thủ công (tránh lệch khớp trên MeshPart phức tạp).
5. **Chế độ nhận diện Đảo Terrain dựng sẵn trong [WorldBuilder.luau](file:///d:/Projects/mighty-angler/src/server/World/WorldBuilder.luau):**
   - Kiểm tra xem trong `Workspace/MightyWorldManual/Island_<id>` đã có đảo Terrain + các điểm neo (`Markers`) chưa.
   - Nếu có: giữ nguyên địa hình Terrain và công trình đặt tay, chỉ khởi tạo vùng nước `FishingWater` khớp cao độ nước, gắn NPC, máy Gym, bệ Trứng, Cổng đảo, Xoáy nước và Bảng xếp hạng vào đúng `Markers`.
   - Nếu chưa có (ví dụ Đảo 2–5 trong giai đoạn Pilot Đảo 1): vẫn tự sinh đảo mặc định như cũ để toàn bộ 5 đảo vẫn chơi thông suốt không bị đứt quãng.

---

## 5. Lộ Trình Triển Khai 3 Chặng (Kết Hợp Mỹ Thuật + Nghiệm Thu V3)

### Chặng 1 — Lập Bảng Đề Xuất Asset 0 Đồng Cho Sunny Shores (Chờ Chủ dự án duyệt)
- Săn và chọn lọc danh sách model **miễn phí 100%** (CC0 / CC-BY / Roblox Creator Store sạch) cho đủ 7 nhóm của Đảo 1 Sunny Shores:
  1. Cây dừa, bụi cỏ, đá biển, dù bãi biển, thùng gỗ, lửa trại.
  2. Quầy Chợ cá, Tiệm cần, Bàn thẩm định, Cầu tàu, Hải đăng, Bệ Enchant, Cổng đảo.
  3. 4 NPC R15 trang phục đúng vai trò.
  4. 7 loài Cá Đảo 1 (4 cá thật + 3 cá hiếm/tưởng tượng).
  5. 2 mẫu Trứng 3D (Trứng Gold Sunny Shores + Trứng Gem Exclusive) & 8 Pet Chibi (4 Pet Đảo 1 + 4 Pet Exclusive).
  6. 3 máy Gym + 2–3 cây Cần đầu tiên.
- Trình Chủ dự án bảng gồm: **Tên món · Ảnh/mô tả · Link nguồn · Giấy phép · Giá (`0đ`) · Ghi chú chỉnh sửa**. Chỉ nạp món nào đã được duyệt.

### Chặng 2 — Nâng Cấp Ổ Cắm 3D + Cấu Trúc Trứng/Pet Mới + Dựng Bản Mẫu Sunny Shores
- Khi Chủ dự án ra lệnh thi công:
  - Áp dụng 5 nâng cấp kỹ thuật ở Mục 4 và cập nhật cấu trúc 6 Trứng / 24 Pet + cơ chế **Exclusive Pet Scaling** (`PetsConfig`, `PetsService`, `OddsCalculator`, `PetsPanel`, `PropsBuilder`, `init.server.luau`).
  - Chạy lại toàn bộ **13+ bộ test tự động VM** + `verify_project.ps1` đạt **PASS 6/6**, giữ chặt trần `≤ 350` dòng/file và 5 file `< 310`.
  - Hỗ trợ dựng **phôi Terrain Sunny Shores** trong Roblox Studio, nắn đẹp bờ cát/đồi/vịnh biển và lắp toàn bộ asset đã duyệt để Chủ dự án bấm **F5 duyệt phong cách**.

### Chặng 3 — Nghiệm Thu Chơi Thật V3 & Nhân Rộng Đảo 2–5
- Thực hiện đủ 4 cột mốc nghiệm thu còn treo của V3 ([V3_BAN_GIAO_NGHIEM_THU.md](V3_BAN_GIAO_NGHIEM_THU.md)):
  1. **Play Solo (F5)** trên Sunny Shores mới.
  2. **Server & Clients (2 client, ping 200ms)**.
  3. **2 Server trên Universe Staging riêng biệt** (xác nhận tách hoàn toàn Production DataStore).
  4. **Điện thoại thật (Mobile)** đo cảm ứng đa điểm + FPS/p95.
- Sau khi Sunny Shores được duyệt gu + qua kiểm tra chơi thật, nhân rộng đúng quy trình sang **Đảo 2–5** và chốt ID Gamepass thật trước khi ký duyệt phát hành.
