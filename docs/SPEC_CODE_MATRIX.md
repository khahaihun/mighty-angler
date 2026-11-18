# SPEC_CODE_MATRIX — Đặc tả, mã thực hiện và bằng chứng

- **Ngày đối chiếu:** 2026-11-18, Codex; phạm vi chỉ cập nhật tài liệu.
- **Mốc nguồn:** `45dd21a` trên nhánh `codex/studio-data-isolation`. [V3][audit] kiểm `8227545`; bản vá `45dd21a` chỉ bổ sung cách ly bảng điểm Studio và phép thử hồi quy. Không suy diễn rằng bản vá này đóng các mã khóa phiên/lưu cuối.
- **Nguồn đã đọc:** [PLAN](../PLAN.md), [AGENTS](../AGENTS.md), [PROGRESS](../PROGRESS.md), [blueprint V3][v3], biên bản V3, mã liên quan và bộ thử Studio.
- **Công việc song song:** Khi đối chiếu, xuất hiện thay đổi ở `src/server/Services/DataService.luau`, `src/server/Services/DataStoreLockHelper.luau`, `tests/README.md`, `PROGRESS.md` và ba file mới `tests/session_acquisition.luau`, `tests/session_fixture.luau`, `tools/test_session_acquisition.ps1`. Các mô tả lỗi gốc dưới đây đối chiếu mốc `45dd21a`; cập nhật bổ sung theo đầu PROGRESS lúc 17:45: code `45dd21a` đã được duyệt, mục 1.1 báo 16/16 ca mô phỏng và PASS 6/6, chờ review commit riêng. Ca tài liệu không tự chạy lại hoặc ký nghiệm thu thay ca thi công; xem D-LOAD. Không sửa hoặc đưa file của ca song song vào commit tài liệu.

## Cách đọc trạng thái và bằng chứng

- **Đã xong:** Chỉ xác nhận phạm vi ghi rõ, chẳng hạn giá trị cấu hình hoặc cấu trúc module đã đọc/đếm. Không phải ký phát hành hoặc chứng minh đã chơi thử.
- **Đang chờ sửa:** Có sai lệch đã biết theo mã/V3. Dẫn đến mục tương ứng trong blueprint; sửa dở ngoài mốc nguồn chưa được tính là đã đóng.
- **Chưa nghiệm thu:** Có mã nhưng thiếu bằng chứng chạy đúng ca trong Studio, hai server/client, ping hoặc thiết bị. Nếu V3 ghi “đạt theo mã”, vẫn phải thử lại trên bản ứng viên.
- **Phép thử dự kiến** là điều kiện cần chạy, không phải kết quả. Chỉ các dòng ghi “đã lưu” có bằng chứng chạy từ ca trước. Ca tài liệu này không chạy game, không tạo build và không cấp quyền ghi dữ liệu.
- **Bằng chứng đã lưu:** phần bàn giao cách ly trong [PROGRESS](../PROGRESS.md) ghi PASS 6/6, exit 0; log verify được đọc đầu ca ghi `2026-11-18 17:30:02`, [log Studio](../logs/studio-data-isolation.log) ghi suite PASS. Bàn giao mục 1.1 lúc 17:45 ghi thêm 16/16 ca và các đường log riêng. [Log verify](../logs/app.log) có thể đã được ca song song ghi lại; log/build là file cục bộ bị Git bỏ qua. Khi chuyển máy phải dùng commit và tái chạy, không giả định log cũ còn nguyên hoặc luôn tồn tại.
- [Bộ thử Studio][suite] thực thi module nguồn với Roblox giả lập, có hướng dẫn ở [tests/README](../tests/README.md). Nó không kiểm khóa phiên/lưu cuối, Engine thật hay UI. [Verify][verify] kiểm dòng/API/LSP/lint/build, chưa gọi suite này.

## Các mâu thuẫn đã biết và cách dùng tài liệu

| Mâu thuẫn trước lần đồng bộ này | Bằng chứng thực tế | Cách xử lý tài liệu / việc còn lại |
|---|---|---|
| PLAN ghi nền 62 file “đang chạy ổn định”. | 62 thuộc v1 `118e101`; bàn giao `45dd21a` ghi 88 file trong `src/`. | Giữ 62 như lịch sử, ghi rõ 88 là mốc đối chiếu; không gọi bản hiện tại đã ổn định về runtime. |
| PLAN đánh dấu A1–D3 `[x]`, D3 nói PASS 6/6 là sẵn sàng phát hành. | [V3][audit] còn 23/44 mục một phần; [blueprint][v3] và PROGRESS ghi chưa duyệt phát hành. | Đổi 12 mục thành `[~]`; nghiệm thu theo các dòng dưới và điều kiện ký của blueprint. |
| AGENTS ghi “xử lý 100%” và “commit mới nhất 8227545”. | `45dd21a` mới hơn; V3 bác kết luận hoàn tất của tên commit cũ. | Thay bằng mốc đã đối chiếu, trạng thái chưa duyệt; đọc Git/PROGRESS khi nhận ca, không coi số commit cố định là HEAD mãi mãi. |
| PROGRESS có cả ghi chép lịch sử “100%” và các mục mới đang chờ sửa/nghiệm thu. | Đầu ca ghi Studio chờ review; cập nhật song song 17:45 ghi code Studio được duyệt, mục 1.1 qua mô phỏng/chờ review, chưa làm 1.2, chưa duyệt phát hành. | Đầu file là bàn giao hiện hành; phần dưới là lịch sử. Không sửa lịch sử để tạo cảm giác các phép thử đã chạy hoặc bỏ qua cập nhật mới. |
| PLAN mô tả `activeSessionId == SERVER_JOB_ID`, `saveInFlight[player]`, `loadFailedPlayers`. | Mã dùng token riêng theo lượt vào, `WithUserLock(UserId)` và `readOnlyPlayers`. | Giữ yêu cầu độc quyền/tuần tự; không đổi mã về tên biến cũ. Đối chiếu thiết kế thực hiện tại [V3 mục 1.1–1.2][v3]. |
| PLAN ưu tiên Trophy theo giá gốc; mã ưu tiên soulbound trước rồi giá gốc/cân/UID. | [TrophyHelper][trophy] và V3 Codex P1-05 xác nhận cách bảo vệ Trophy cũ. | Ghi rõ sai khác diễn đạt; chưa tự đổi thuật toán hoặc chuẩn hóa câu chữ thành quyết định gameplay mới. Bảo vệ 21 mục đã đạt theo [điều kiện ký V3][v3]. |
| Mục tiêu HudPanel <230, BagPanel <250 khác trần cam kết <310. | Bàn giao ghi 268 và 307 dòng: đạt <310, chưa đạt hai mục tiêu nhỏ hơn. | Giữ riêng hai mức; mục kiến trúc dưới ghi thiếu mục tiêu. Blueprint yêu cầu <310, không giao tách thêm chỉ để đạt <230/<250. |
| Quyết định cân nặng không Titan nằm ngoài PLAN. | Mã đang kẹp 1,15 tải cần và làm tròn xuống; blueprint yêu cầu khôi phục trần/rounding cũ. | Theo [Đợt 2, quyết định cân bằng][v3]; không sửa PLAN để hợp thức hóa hồi quy. |

PLAN là nguồn yêu cầu gameplay; matrix là bảng đối chiếu; PROGRESS đầu file là bàn giao; blueprint V3 là chỉ thị sửa và điều kiện ký. Các liên kết ghi “V3 mục x.y” trỏ tới đúng file blueprint, số mục nằm trong bảng của đợt tương ứng. Các dòng lộ trình ở cuối tham chiếu lại quy tắc chi tiết, không cộng thêm tính năng.

## 1. Mười quyết định O1–O10 của PLAN

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| O1 · Ẩn Backpack; hotbar 1..5, cần ô 1, bốn cá ghim ô 2..5; cầm cá hai tay, kích thước/đột biến. | [Hotbar][hotbar], [CastController][cast], [ShopItems][items], [FishVisuals][fishvis], [Animation][anim]. | Dự kiến: rút/cất 1..5, ghim đủ bốn UID, bán/đổi/Rebirth cá đang cầm; xem từ client khác. | **Chưa nghiệm thu** — có mã hotbar/ghim/mô hình; hoạt ảnh hai phía còn liên quan [V3 mục 3.4][v3]. |
| O2 · Giữ/thả chuột hoặc chạm; quỹ đạo phao; điểm chạm đầu tiên, nước mở lượt câu, đất/cầu/đá nảy 1–2 nhịp không mất mồi. | [CastController][cast], [Roller][roller], [Fishing][fishing], [RodVisuals][rodvis]. | Dự kiến: bốn chế độ ở năm đảo, cầu có nước dưới, đất/đá, ngắm trời, ngoài tầm, tường biên. | **Đang chờ sửa** — Auto chưa dùng cùng kiểm mặt nước; hiệu ứng nảy còn tin điểm client; [V3 mục 2.1][v3], Codex P1-08 / Argon P1-4. |
| O3 · Tay thường 0/0; Perfect [0,78;0,95] +25%/+15%; Free 1,10s; Pro 0,45s và quyền pass cũ. | [GameConfig][game], [Fishing][fishing], [Roller][roller], [Perk][perk], [FishingController][fc]. | Dự kiến: biên Perfect và ngoài biên, tay thường khi có pass, OFF→ON trong hồi, timeout. | **Đang chờ sửa** — dung sai Perfect và hồi server 1,02/0,39s chưa đúng thiết kế; [V3 mục 2.2][v3], Codex P1-09/P1-11 / Argon P1-5. |
| O4 · 1/2/3 vòng, hạn 7,5/9,5/11,5s; ân hạn nhận +0,40s; đóng và quăng lại đúng một lần. | [Session][session], [Minigame][mini], [FishingController][fc], [Fishing][fishing]. | Dự kiến: sát hạn trừ 0,05s, ping 200ms, yêu cầu trùng, thắng/thua/timeout và hủy. | **Đang chờ sửa** — client vẫn nhận bấm sau hạn và Auto có thể ON nhưng đứng im; [V3 mục 2.2–2.3][v3]. |
| O5 · Mồi góc dưới phải, xổ ngược và hiện số lượng; hai nút pill Auto ngay trên hotbar. | [Hotbar][hotbar], [Hud][hud]. | Dự kiến: đổi mồi nhanh, hết mồi, thay kích thước màn hình, chuột/chạm. | **Chưa nghiệm thu** — bố cục đã có mã, chưa có bằng chứng ảnh/cảm ứng trên bản ứng viên. |
| O6 · Bag/Shop/Pets/Index là lưới 3D, nhãn cân/giá; Lock/Auto-Lock, Multi-Select, Sell Held và Sell All Unlocked. | [Bag][bag], [Shop][shop], [PetsPanel][petui], [Index][index], [Pool][pool], [Currency][currency]. | Dự kiến: túi đầy, hồ sơ mới rỗng, từng đường bán với UID khóa/Trophy, mở/đóng 50 lần. | **Đang chờ sửa** — Index lần đầu và thẻ ngoài vùng nhìn còn lỗi; phần bán đã đạt theo mã V3, chưa nghiệm thu tích hợp; [V3 mục 2.5][v3]. |
| O7 · Bốn NPC R15 có thở/vẫy tay, thoại đa lựa chọn; mở/đóng Merchant không tự bán cá. | [Npc][npc], [Dialogue][dialogue], [Prompt][prompt], [EnchantBounty][eb], [Gym][gym]. | Dự kiến: từng NPC, đóng thoại không thay túi, đi xa sau khi mở bảng, rig thay thế nếu bật. | **Đang chờ sửa** — phạm vi giao dịch và camera khi chồng thoại/minigame; [V3 mục 2.4, Camera và cảm ứng][v3]. Rig mặc định đạt theo mã V3 P1-17, rig Toolbox cần thử riêng. |
| O8 · Năm chỉ số, sáu cần thường không Enchant; ba Exclusive scale 115/122/130%, giữ qua Rebirth và được Enchant. | [Rods][rods], [EnchantConfig][ench], [EnchantBounty][eb], [Progression][prog], [Shop][shop]. | Dự kiến: từng cần, nền tốt nhất trước/sau Rebirth, quyền nhận riêng, so thẻ Shop với server. | **Đang chờ sửa** — thông số Shop/đường công bố trước mua chưa đầy đủ; [V3 mục 3.2–3.3][v3]. Cấu hình từng cần đối chiếu ở 2.1. |
| O9 · Nước Terrain cục bộ, năm đảo đa tầng, xoáy nước, Rank/Aura và tạ hai tay. | [Terrain][terrain], [World][world], [Whirlpool][whirl], [PlayerVisuals][pv], [Ranks][ranks]. | Dự kiến: năm đảo, vùng ngoài biển còn nguyên; xem Rank/Aura/tạ từ hai client R6/R15. | **Đang chờ sửa** — hoạt ảnh/tư thế tạ còn V3 P1-16; [V3 mục 3.4][v3]. Nước/địa hình có mã, chưa nghiệm thu đủ năm đảo. |
| O10 · Chín quà online UTC, cutscene trứng, dấu !/uốn cần/zoom, Settings, xác suất gốc/thực tế và Policy. | [GameConfig][game], [Progression][prog], [GiftsSettings][gifts], [EggCutscene][egg], [Odds][odds], [Perk][perk]. | Dự kiến: qua ngày UTC/đăng nhập lại, nhận hai lần, SKIP, Low GFX; đối chiếu xác suất và chính sách. | **Đang chờ sửa** — [V3 mục 1.3, 3.1–3.2, 3.5, Camera và cảm ứng][v3]; quà/cutscene không có bằng chứng Engine mới. |

## 2.1.A. Cần thường, dải cân năm đảo và cổng kép

Thứ tự số của sáu dòng cần: **Gold / Strength / Power / Max kg / Lure / Luck / Control / Steadiness**. Đã đối chiếu cấu hình tĩnh; chưa coi mua/trang bị/chạy thật đã đạt.

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| A-R1 · Twig: 0 / 0 / 1 / 15 / 0% / 0% / 0% / 0%. | [Rods][rods] `NormalList.Twig`. | Đã đọc đủ tám giá trị cấu hình. | **Đã xong (cấu hình)** — khớp bảng PLAN. |
| A-R2 · Bamboo: 500 / 1.500 / 2 / 65 / 10% / 15% / 4% / 5%. | [Rods][rods] `NormalList.Bamboo`. | Đã đọc đủ tám giá trị cấu hình. | **Đã xong (cấu hình)** — khớp bảng PLAN. |
| A-R3 · Carbon: 5.000 / 12.000 / 3 / 220 / 22% / 35% / 8% / 12%. | [Rods][rods] `NormalList.Carbon`. | Đã đọc đủ tám giá trị cấu hình. | **Đã xong (cấu hình)** — khớp bảng PLAN. |
| A-R4 · MysticVine: 45.000 / 90.000 / 4 / 650 / 35% / 65% / 13% / 20%. | [Rods][rods] `NormalList.MysticVine`. | Đã đọc đủ tám giá trị cấu hình. | **Đã xong (cấu hình)** — khớp bảng PLAN. |
| A-R5 · MagmaCore: 350.000 / 650.000 / 5 / 1.600 / 50% / 110% / 18% / 30%. | [Rods][rods] `NormalList.MagmaCore`. | Đã đọc đủ tám giá trị cấu hình. | **Đã xong (cấu hình)** — khớp bảng PLAN. |
| A-R6 · Celestial: 2.500.000 / 4.500.000 / 6 / 5.000 / 70% / 180% / 25% / 42%. | [Rods][rods] `NormalList.Celestial`. | Đã đọc đủ tám giá trị cấu hình. | **Đã xong (cấu hình)** — khớp bảng PLAN. |
| A-I1 · Đảo 1: thường 0,5–48kg; Boss 52–110kg, Power ≥2/Bamboo. | [Đảo 1][i1], [Roller][roller]. | Dự kiến: đọc từng loài và thử hai biên/cần yếu. | **Chưa nghiệm thu** — có dải cấu hình; cân cá thực nhận còn phụ thuộc cap, xem quyết định cân bằng [Đợt 2 V3][v3]. |
| A-I2 · Đảo 2: thường 4–175kg; Boss 185–360kg, Power ≥3/Carbon. | [Đảo 2][i2], [Roller][roller]. | Dự kiến: đọc từng loài và thử hai biên/cần yếu. | **Chưa nghiệm thu** — có cấu hình; chưa có bộ thử cân toàn đảo và Engine. |
| A-I3 · Đảo 3: thường 18–540kg; Boss 560–1.050kg, Power ≥4/MysticVine. | [Đảo 3][i3], [Roller][roller]. | Dự kiến: đọc từng loài và thử hai biên/cần yếu. | **Chưa nghiệm thu** — có cấu hình; chưa có bộ thử cân toàn đảo và Engine. |
| A-I4 · Đảo 4: thường 75–1.420kg; Boss 1.480–2.800kg, Power ≥5/MagmaCore. | [Đảo 4][i4], [Roller][roller]. | Dự kiến: đọc từng loài và thử hai biên/cần yếu. | **Chưa nghiệm thu** — có cấu hình; chưa có bộ thử cân toàn đảo và Engine. |
| A-I5 · Đảo 5: thường 260–4.300kg; Boss 4.500–9.500kg, Power ≥6/Celestial. | [Đảo 5][i5], [Roller][roller]. | Dự kiến: đọc từng loài và thử hai biên/cần yếu. | **Chưa nghiệm thu** — có cấu hình; chưa có bộ thử cân toàn đảo và Engine. |
| A-GATE · Chỉ loài đủ Power và minWeight ≤ tải cần; rổ rỗng từ chối trước chờ cá/trừ mồi, báo cần quá yếu. | [Roller][roller] `GetEligibleCandidates`, [Fishing][fishing] `StartCast`. | Dự kiến: Twig trên đảo 5, kiểm 0 phiên/0 mồi bị trừ; đối chiếu rổ UI/server. | **Chưa nghiệm thu** — có bộ lọc, nhưng UI xác suất phải dùng cùng rổ theo [V3 mục 3.2][v3]. |

## 2.1.B–C. Exclusive và Enchant

Với Exclusive, `B` là cần thường có `order` cao nhất đang sở hữu; `E` là cấu hình Exclusive.

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| B-BASE · Chọn B theo order trong ownedRods; cầm Exclusive không yêu cầu Strength, Power bằng B, masteryBaselineStrength bằng B.strengthReq. | [Rods][rods] `GetBestNormalRod/GetEffectiveStats`. | Đã đọc công thức; dự kiến kiểm đổi nền và sau Rebirth. | **Đã xong (công thức tĩnh)** — đúng hàm hiện có; trải nghiệm sau Rebirth chưa nghiệm thu. |
| B-WEIGHT · MaxWeight = floor(B.maxWeight × E.scaleFactor). | [Rods][rods] `GetEffectiveStats`. | Đã đọc; ví dụ Trident nền Twig = floor(15×1,15) = 17kg. | **Đã xong (công thức tĩnh)** — V3 Codex P2-02 đối chiếu cùng ví dụ. |
| B-LURE · LureSpeed = B.lureSpeed × scaleFactor + flatLure. | [Rods][rods] `GetEffectiveStats`. | Đã đọc biểu thức. | **Đã xong (công thức tĩnh)** — khớp PLAN. |
| B-LUCK · Luck = B.luckBonus × scaleFactor + flatLuck. | [Rods][rods] `GetEffectiveStats`. | Đã đọc biểu thức. | **Đã xong (công thức tĩnh)** — khớp PLAN. |
| B-CONTROL · Control = B.controlBonus + flatControl, kẹp cuối ở tính vùng minigame. | [Rods][rods], [Buff][buff], [Session][session]. | Đã đọc cộng Control và clamp; dự kiến so HUD/Shop ở Strength thấp/cao. | **Đang chờ sửa** — thẻ Shop thiếu tăng theo Strength, [V3 mục 3.3][v3] Codex P2-02. |
| B-STEADY · Steadiness = min(0,65; B.steadiness + flatSteadiness). | [Rods][rods] `GetEffectiveStats`. | Đã đọc biểu thức. | **Đã xong (công thức tĩnh)** — khớp PLAN. |
| B-TRIDENT · Scale 1,15; flat Lure/Luck/Control/Steady = 5/15/2/5%; giá 800 Gems + đúng một Boss đảo ≥3. | [Rods][rods], [BountyConfig][bounty], [EnchantBounty][eb]. | Dự kiến: chọn UID thường mở khóa; từ chối Trophy/locked/sai đảo; trừ đúng một cá và 800 Gems. | **Đang chờ sửa** — chọn UID đạt theo mã V3 P0-03, nhưng phạm vi NPC còn [V3 mục 2.4][v3]. |
| B-VOID · Scale 1,22; flat 8/25/4/8%; 2.200 Gems hoặc 0,2% xoáy đảo 4–5; trùng đổi 350 Gems +2 Relics. | [Rods][rods], [BountyConfig][bounty], [EnchantBounty][eb], [Fishing][fishing] `checkVoidScytheWhirlpoolDrop`. | Dự kiến: ép random sát 0,002, đảo 3/4/5, ngoài xoáy, đã sở hữu/chưa sở hữu. | **Chưa nghiệm thu** — hằng số và nhánh đổi trùng có mã; chưa có phép thử tự động riêng. |
| B-DRAGON · Scale 1,30; flat 12/40/6/12%; chỉ mở qua quyền ExclusiveDragonRod. | [Rods][rods], [Perk][perk], [Passes][passes], [EnchantBounty][eb]. | Dự kiến: giả lập quyền pass, từ chối không quyền, kiểm mọi đường vào prompt mua. | **Đang chờ sửa** — tab Exclusive thiếu công bố xác suất trước mua, [V3 mục 3.2][v3]. |
| B-NOGOLD · Không bán Exclusive qua BuyRod bằng Gold; cần thường không được Enchant. | [Rods][rods] `List = NormalList`, [ShopItems][items], [EnchantBounty][eb]. | Dự kiến: gọi trực tiếp BuyRod Exclusive và RollEnchant cần thường. | **Chưa nghiệm thu** — rổ cần/kiểm isExclusive có mã, thiếu ca giao dịch lặp được. |
| C-COST · Enchant chỉ cho Exclusive đã sở hữu, trả 1 Relic hoặc 75 Gems. | [EnchantConfig][ench], [EnchantBounty][eb] `handleRollEnchant`. | Dự kiến: thiếu tiền/Relic, không sở hữu, gửi trùng; chặn Gems khi policy chưa cho phép. | **Đang chờ sửa** — kiểm quyền/giá có mã; policy thiếu boolean còn [V3 mục 3.1][v3]. |
| C-SWIFT · 28%, Rare, +35% Lure. | [EnchantConfig][ench], [Buff][buff]. | Đã đọc chance/rarity/lureBonus; dự kiến kiểm buff thực nhận. | **Đã xong (cấu hình)** — đúng 0,28/Rare/0,35; không xác nhận phân phối chạy thật. |
| C-IRON · 26%, Rare, +10% Control và +20% Steadiness. | [EnchantConfig][ench], [Buff][buff]. | Đã đọc chance/rarity/controlBonus/steadinessBonus. | **Đã xong (cấu hình)** — khớp PLAN; hiển thị Control còn dòng B-CONTROL. |
| C-SEA · 20%, Epic, +65% Luck. | [EnchantConfig][ench], [Buff][buff]. | Đã đọc chance/rarity/luckBonus. | **Đã xong (cấu hình)** — đúng 0,20/Epic/0,65. |
| C-TITAN · 13%, Legendary; ×2,5 trọng số bậc lớn, ×1,45 cân, cap 1,25 tải cần; giữ nhãn/hệ số giá. | [EnchantConfig][ench], [Roller][roller] `RollSizeTierAndWeight`, [Fishing][fishing]. | Dự kiến: ép bậc/cân chạm trần, cần tải 5.750kg → trần 7.187,5kg; so nhãn/giá. | **Chưa nghiệm thu** — V3 P1-07 đạt theo mã; phải bảo vệ khi sửa nhánh không Titan theo [Đợt 2 V3][v3]. |
| C-ABYSS · 9%, Legendary, +85% Mutation Chance. | [EnchantConfig][ench], [Buff][buff], [Roller][roller]. | Đã đọc cấu hình; dự kiến đối chiếu hệ số và xác suất UI. | **Đã xong (cấu hình)** — đúng 0,09/Legendary/0,85; UI còn dòng F-ODDS. |
| C-MIDAS · 4%, Mythic, +40% Luck; lưu midasBonus 1,30 trên cá, chỉ nhân giá một lần; 20% nâng None/Shiny lên Golden, giữ Golden/Cosmic. | [EnchantConfig][ench], [Roller][roller] `RollMutation`, [Fishing][fishing], [EnchantBounty][eb], [Currency][currency]. | Dự kiến: ép bốn đột biến, đổi cần trước bán/Appraise, kiểm giá không nhân hai lần. | **Chưa nghiệm thu** — có cấu hình/nhánh xử lý, chưa có suite Midas riêng. |
| C-ODDS · Sáu % là trọng số gốc; loại dòng cũ rồi chuẩn hóa xác suất kết quả trước khi xoay. | [EnchantConfig][ench] `RollEnchant`, [EnchantModal][em], [Odds][odds]. | Dự kiến: đang có Swift → Swift 0%, Midas 4/72 ≈5,56%, tổng 100%. | **Chưa nghiệm thu** — V3 P1-12 xác nhận ví dụ theo mã; bảo vệ khi làm [V3 mục 3.2][v3]. |
| C-NONTITAN · Quyết định tương thích bổ sung: trần max(cân tối đa loài; 1,15 tải cần), làm tròn gần nhất 0,1kg khi không Titan. | [Roller][roller] `RollSizeTierAndWeight`. | Dự kiến: Sunset Barracuda cùng đầu vào, Twig thường/Trident thường đạt 22,0kg; Trident Titan đạt 21,2kg. | **Đang chờ sửa** — hiện cap chỉ 1,15 tải cần và làm tròn xuống; [Đợt 2, quyết định cân bằng V3][v3]. |

## 2.2. Buff, xoáy nước, minigame, Appraise và xác suất

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| F-LUCK · (1+rod+enchant+cast Luck) ×(1+bait+potion Luck) ×(1+pet Luck) ×(1+event Luck) ×2 nếu trong xoáy. | [Buff][buff], [PotionBait][pb], [PetsService][pets], [LiveOps][live], [Fishing][fishing], [Roller][roller]. | Dự kiến: từng nguồn rồi tổ hợp, trong/ngoài xoáy; so rổ server với UI. | **Chưa nghiệm thu** — có đường tổng hợp provider và xoáy; chưa có suite tổ hợp công thức. |
| F-BOSS · Trọng số Boss = baseBossWeight ×bossChanceMult ×(2 nếu xoáy) ×(1+0,25×(luckMult−1)), rồi chuẩn hóa. | [Roller][roller] `RollFishSpecies`, [Odds][odds]. | Dự kiến: dùng cùng rổ ứng viên, đối chiếu từng trọng số và xác suất, không suy từ ít lượt quay. | **Đang chờ sửa** — UI còn thiếu từng kết quả/nhóm Rare+ và cột xoáy; [V3 mục 3.2][v3]. |
| F-BITE · (1+rodLure+enchantLure+castLure+strengthSpeed) ×(1+potionSpeed) ×(1+eventSpeed); chờ cá không dưới 0,55s. | [Buff][buff], [Fishing][fishing], [PotionBait][pb], [LiveOps][live]. | Dự kiến: buff tối đa và không buff; kiểm biteDelay ≥0,55s. | **Chưa nghiệm thu** — có biểu thức/sàn trong StartCast, chưa có ca thời gian thực. |
| F-WIDTH · clamp(baseZone+rodControl+enchantControl+strengthWidth; 0,20;0,68), HUD/Shop hiện % sau clamp. | [Buff][buff], [Session][session], [Hud][hud], [Shop][shop]. | Dự kiến: Rare nền 28%, Boss 22%; Strength thấp/cao, trần 68%. | **Đang chờ sửa** — server có clamp, Shop thiếu phần Strength; [V3 mục 3.3][v3], Codex P2-02. |
| F-SPEED · Tốc độ kim = baseSpeed/(1+rodSteadiness+enchantSteadiness). | [Buff][buff], [Session][session] `BeginMinigame`. | Dự kiến: so số với server/client ở từng buff. | **Chưa nghiệm thu** — mã còn sàn speed 0,48 và divisor ≥1; PLAN không nêu sàn này, chưa có quyết định thay thiết kế. Ghi sai khác để review cùng [V3 mục 2.3][v3]. |
| M-SNAPSHOT · Chốt rodId, mồi, inWhirlpool ở điểm phao, castMode và mults khi chạm nước; không đổi thưởng/trừ nhầm mồi giữa lượt. | [Fishing][fishing] `StartCast/finalizeFishAward`, [Session][session], [ShopItems][items]. | Dự kiến: đổi cần/mồi/buff khi chờ cá và minigame; so vật phẩm/Strength chỉ cộng một lần. | **Chưa nghiệm thu** — V3 P2-03 xác nhận Strength theo snapshot không nhân hai lần; cần ca tích hợp. |
| M-ROUNDS · Rare một vòng, Epic/Legendary hai, Boss ba; tâm mỗi vòng [0,30;0,82]. | [Session][session] `BeginMinigame`. | Đã đọc rounds và tâm; dự kiến thử các hạng và biên random. | **Đã xong (công thức tĩnh)** — biểu thức khớp PLAN, V3 P2-02 xác nhận miền tâm. |
| M-TIME · timeout =5,5+2×rounds; promptSentClock/currentRound; server đóng sau timeout+0,40. | [Session][session], [Minigame][mini]. | Dự kiến: ba hạn bấm, gói sát hạn đến muộn hợp lệ ở ping 200ms. | **Đang chờ sửa** — server có hai hạn, client còn nhận bấm +0,45s; [V3 mục 2.3][v3], Codex P1-10. |
| M-STRIKE · Mỗi vòng gửi sessionId/round/clientElapsed; server kiểm số hữu hạn, đúng phiên/thứ tự, 0<t≤timeout. | [Net][net], [Session][session] `HandleStrike`, [Minigame][mini]. | Dự kiến: NaN/∞, sai phiên, sai vòng, lặp/đảo thời gian và packet cuối. | **Chưa nghiệm thu** — V3 P1-10 đạt phần kiểm server theo mã; chưa có suite gói lỗi. |
| M-CLOCK · clientElapsed≤serverElapsed+0,08 và serverElapsed−clientElapsed≤0,45. | [Session][session] `HandleStrike`. | Đã đọc hai biên; dự kiến thử đúng biên, ngay ngoài biên và ping 200ms. | **Đã xong (công thức tĩnh)** — khớp hai điều kiện PLAN; trải nghiệm mạng còn nghiệm thu [V3 mục 2.3][v3]. |
| M-WAVE · Client vẽ sóng tam giác 60FPS, server dùng triangleBounce(0,08,speed,t), dung sai zoneWidth×0,52+0,05. | [Util][util], [Session][session], [Minigame][mini]. | Dự kiến: cùng thời điểm cho cùng vị trí; đo độ mượt trên điện thoại. | **Chưa nghiệm thu** — công thức server có mã, chưa có phép đo 60FPS trên thiết bị. |
| M-CLOSE · Timeout/thắng/trượt/đổi đảo/cất cần/chết/Rebirth qua CloseSessionOnce; chỉ FishingController điều phối quăng lại một lần. | [Session][session], [Fishing][fishing], [FishingController][fc], [IslandService][iservice], [Progression][prog]. | Dự kiến: chồng timeout/thắng/hủy; bật Auto trong hồi; không cá hoặc lịch quăng trùng. | **Đang chờ sửa** — đường timeout thiếu đặt hồi, Auto có thể kẹt; [V3 mục 2.2][v3]. |
| AP-COST · Appraise giá max(100,floor(baseValue×0,35)); kiểm UID và đúng phạm vi NPC. | [EnchantBounty][eb] `handleAppraise`, [Npc][npc]. | Dự kiến: thiếu Gold, UID người khác, sát trong/ngoài bán kính 3D/độ cao, đi xa sau mở UI. | **Đang chờ sửa** — phạm vi hiện rộng hơn prompt; [V3 mục 2.4][v3], Codex P1-06 / Argon P1-3. |
| AP-IDENTITY · Appraise giữ uid/locked/midasBonus; chỉ nâng đột biến, không hạ bậc kích thước. | [EnchantBounty][eb] `handleAppraise`. | Dự kiến: bốn đột biến và bốn size, khóa bật/tắt, kiểm giá từ hệ số bậc giữ lại. | **Chưa nghiệm thu** — Argon P1-2 đạt theo mã V3; chưa có bằng chứng chơi ca này trên bản ứng viên. |
| AP-FLOOR · Cân mới ≥85% cân cũ; cập nhật best Index ngay khi tăng. | [EnchantBounty][eb], [ClientState][state], [ProgressPanel][progress]. | Dự kiến: cá 10,4kg có sàn 8,9kg, phá kỷ lục rồi mở Index không cần vào lại. | **Chưa nghiệm thu** — V3 Codex P2-01 đạt theo mã; cần bảo vệ cùng sửa Index [V3 mục 2.5][v3]. |
| AP-TROPHY · Cho Appraise soulbound, giữ soulbound=true/sellValue=0; chỉ đổi originalValue và best Index. | [EnchantBounty][eb], [Currency][currency]. | Dự kiến: Appraise Trophy rồi thử bốn luồng bán, ghim và Rebirth lần nữa. | **Chưa nghiệm thu** — có nhánh giữ cờ/giá 0; thuộc 21 mục cần kiểm lại theo [điều kiện ký V3][v3]. |
| F-ODDS · Công bố % gốc/thực tế từng kết quả với cần/mồi/thuốc/pet/sự kiện/xoáy/bốn chế độ; trước mọi đường mua Auto Pro/Dragon. | [Odds][odds], [Hud][hud], [ClientState][state], [Shop][shop], [PetsPanel][petui], [EnchantModal][em], [Prompt][prompt]. | Dự kiến: tổng 100% mỗi rổ, loại loài 0%, Rare+ gồm Boss; Tiki Spirit riêng → Shiny 5,5% so gốc 5%. | **Đang chờ sửa** — thiếu Perfect tay/pet/từng kết quả và đường mua; [V3 mục 3.2, ca đột biến][v3], Codex P1-12 / Argon P1-6. |
| F-POLICY · Kiểm ArePaidRandomItemsRestricted trước Gems cho trứng/Enchant, chặn khi chưa xác nhận được phép. | [Perk][perk], [PetsService][pets], [EnchantBounty][eb], [PetsPanel][petui]. | Dự kiến: Loading/lỗi API/thiếu trường/sai kiểu/true/false; năm ca đầu giữ tiền/vật phẩm, kiểm Gold/Relic riêng. | **Đang chờ sửa** — hiện giá trị khác true có thể thành Allowed; chỉ boolean false mới được phép theo [V3 mục 3.1][v3], Codex P1-13. |

## 2.3. Khóa phiên, migration, UTC và Trophy

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| D-ID · JobId hoặc UID khi Studio; metadata activeSessionId/lockTimestamp/saveSeq; tuần tự theo người chơi. | [Data][data], [Lock][lock], [Types][types]. | Đọc mốc nguồn; dự kiến hai lượt vào cùng UserId và lệnh nhả muộn. | **Chưa nghiệm thu** — dùng token JobId+UID mỗi lượt và hàng chờ UserId thay tên biến PLAN; không đổi ngược. [V3 mục 1.1][v3]. |
| D-LOAD · UpdateAsync chỉ nhận khóa trống/cùng chủ/quá 120s; tối đa ba lần cách 1,5s; lỗi thì cấm giao dịch/ghi bền. | [Lock][lock] `AcquireLockWithRetries/WithUserLock`, [Data][data] `acquireSessionAndLoad`; ca song song thêm `tests/session_acquisition.luau` và `tests/session_fixture.luau`. | Bàn giao 17:45 **báo đã chạy** 16/16 ca, gồm A/B tranh khóa, ngoại lệ, pending, nhả lỗi tạm/muộn, mất phản hồi và rời lúc quarantine; ca tài liệu không chạy lại. | **Chưa nghiệm thu** — lỗi gốc tại `45dd21a` là chưa fail-closed mọi ngoại lệ và chưa theo dõi nhả; bản vá 1.1 song song đã qua mô phỏng theo PROGRESS, chờ review commit riêng/Engine. [V3 mục 1.1][v3], Codex P0-01/P1-01. |
| D-RENEW · Gia hạn mỗi 60s kể cả không dirty; quyền ghi hết hạn 120s theo dấu giờ kho xác nhận. | [GameConfig][game], [Data][data], [Lock][lock]. | Dự kiến: hồ sơ đứng yên, phản hồi chậm/đã ghi mất phản hồi, A quá hạn rồi B nhận khóa. | **Đang chờ sửa** — dấu giờ cục bộ lấy lúc nhận phản hồi lệch kho, lịch lưu dồn nhịp; [V3 mục 1.2][v3], Codex P0-02. |
| D-WRITE · Chỉ ghi đúng token, oldData khác nil, saveSeq không mới hơn hồ sơ; xác nhận nonce; tuần tự mọi lần ghi. | [Lock][lock] `WriteSnapshotVerified`, [Data][data] `SaveProfile`. | Dự kiến: oldData nil/sai chủ/seq cao, callback lặp, lỗi trước/sau kho ghi. | **Chưa nghiệm thu** — V3 ghi kiểm token/nonce/seq đã có; cần suite mất phản hồi và hai server [V3 mục 1.1–1.2][v3]. |
| D-DIRTY · Chụp dirtyRevision trước lưu; tăng saveSeq khi xác nhận; chỉ xóa cần lưu nếu revision không đổi. | [Data][data] `SaveProfile`, [Lock][lock]. | Dự kiến: sửa hồ sơ trong lúc UpdateAsync chờ; lần sau vẫn lưu phần mới. | **Chưa nghiệm thu** — có revision/seq, chưa có bằng chứng ca cạnh tranh. |
| D-CLOSE · Rời/đóng server phải đợi lưu đang chạy, lưu mới nhất và nhả đúng chủ; hai đường đóng cùng chờ kết quả cuối. | [Data][data] `closePlayerSessionOnce/BindToClose`, [Lock][lock]. | Dự kiến: tiêu UID Bounty rồi chuyển server; chồng hai đường đóng; retry tới hết hạn; kiểm closingPlayers về mức đầu. | **Đang chờ sửa** — đóng trùng trả sớm, bỏ kết quả retry và giữ tham chiếu Player; [V3 mục 1.2][v3], Codex P0-02 / Argon P0-3. |
| D-SAFEUI · Khi chưa tải/mất quyền ghi phải khóa giao dịch; init đầy đủ một lần kể cả tải sau 8s; HUD hiện safeReadOnly. | [Data][data], [ClientState][state], [Hud][hud]. | Dự kiến: tải trước/sát/sau 8s, snapshot đúng một, thử tiêu tiền và ghi bảng điểm ở chế độ chỉ đọc. | **Đang chờ sửa** — V3 P1-04: HUD chưa phản ánh cờ, có thể gửi hai snapshot; [V3 mục 1.5][v3]. |
| D-RESET · Reset DEV phải giữ thứ tự ghi và cùng hàng chờ autosave; báo riêng RAM/lưu bền. | [Data][data] `ResetProfile`, [DevService][dev], [DevPanel][devui]. | Dự kiến: Reset khi autosave đợi; vào lại sau xác nhận, lỗi API và RAM-only. | **Đang chờ sửa** — thay profile ngoài hàng chờ tại mốc nguồn; [V3 mục 1.4][v3], Codex P2-06 / Argon P0-3. |
| D-ISOLATE · Studio không mở/ghi tên kho sản xuất cho hồ sơ và hai bảng điểm; server thử trực tuyến dùng experience thử riêng. | [Lock][lock], [LiveOps][live], [suite Studio][suite]. | **Đã lưu:** Studio PlaceId 0/123456, production giả lập, lỗi từng kho, refresh đầu/định kỳ, 0 yêu cầu tên sản xuất trong Studio. | **Chưa nghiệm thu (Engine)** — mô phỏng PASS tại `45dd21a`, [PROGRESS](../PROGRESS.md) và log; Studio thật/hai server còn chờ. [V3 mở đầu Đợt 1][v3]. |
| D-RECORD · Chỉ hồ sơ có quyền ghi được cập nhật điểm; điểm 0 bỏ qua, kỷ lục dùng max qua UpdateAsync. | [LiveOps][live] `refreshLeaderboards`, [Data][data] `CanWritePersistent`, [suite Studio][suite]. | **Đã lưu:** 125,9/250,8 →125/250; điểm thấp không hạ, điểm cao nâng, 0 không ghi; read-only/chưa tải không ghi. | **Đã xong (mô phỏng LiveOps)** — suite PASS theo bàn giao; CanWritePersistent là đầu vào giả lập, không chứng minh khóa phiên đúng. |
| D-SCHEMA · Migration v2 idempotent, bảo vệ bản gốc; từ chối cấu trúc hỏng/phiên bản mới hơn; lỗi một người không dừng tự lưu người khác. | [Migrator][migrator], [Data][data], [Util][util]. | Dự kiến: v1 hai lần, v2 tốt, playTimeSec=false, túi sai kiểu, cá thiếu fishId, version>2 cùng hồ sơ tốt. | **Đang chờ sửa** — có thể làm rỗng túi/bỏ cá hoặc cho sai kiểu vào vòng lưu; [V3 mục 1.3][v3], Codex P1-03. |
| D-MIGRATE · Giữ uid/weight/sellValue; bổ sung originalValue, sizeTier Normal, midas 1, soulbound boolean; chỉ tự khóa hiếm/đột biến khi locked chưa có. | [Migrator][migrator] `MigrateProfileToV2`. | Dự kiến: bảng hồ sơ cũ gồm cá mở khóa chủ động/thiếu trường; chạy hai lần, so từng UID/giá/cân. | **Đang chờ sửa** — nhánh mặc định có mã, nhưng khâu làm sạch chưa bảo vệ đủ cấu trúc; [V3 mục 1.3][v3]. |
| D-UTC · Lưu playtimeDay/giây/mốc đã nhận; reset theo ngày UTC, nâng dataVersion=2; chín mốc nhận một lần/ngày. | [Migrator][migrator], [GameConfig][game], [Data][data], [Progression][prog], [GiftsSettings][gifts]. | Dự kiến: sát 00:00 UTC, reconnect, giữ nguyên mốc cùng ngày, claim trùng và thiếu giây. | **Chưa nghiệm thu** — có RefreshUtcPlaytimeIfNewDay và chín quà; tính bền phụ thuộc sửa [V3 mục 1.2–1.3][v3]. |
| R-KEEP · Rebirth giữ Gems, pets/equippedPetUids, potions/activePotions, Index/các reward/achievement đã claim, rodEnchants/Relics, ba trường UTC và Exclusive ownedRods. | [Progression][prog] `handleDoRebirth`. | Dự kiến: điền tất cả trường, Rebirth hai lần, so giữ nguyên trừ thưởng được thiết kế. | **Chưa nghiệm thu** — có nhánh giữ dữ liệu/Exclusive, chưa có suite đầy đủ trường. |
| R-TOP12 · Tối đa 12 cá khóa, PLAN nêu originalValue giảm dần; mã còn ưu tiên soulbound trước, rồi giá/cân/UID. | [TrophyHelper][trophy], [Progression][prog]. | Dự kiến: >12 cá, Trophy cũ giá thấp và cá khóa mới giá cao, nhiều giá bằng nhau, Rebirth nhiều lần. | **Chưa nghiệm thu** — V3 P1-05 đạt theo mã, khác diễn đạt PLAN đã ghi ở bảng mâu thuẫn; giữ cách hiện hành khi bảo vệ 21 mục [V3 ký cuối][v3]. |
| R-FLAGS · Cá giữ có soulbound=true, sellValue=0; pinnedFishUids chỉ còn UID trong nhóm giữ. | [Progression][prog], [ShopItems][items]. | Dự kiến: ghim cá giữ/cá bị loại, Rebirth rồi xem hotbar và mô hình cả hai client. | **Chưa nghiệm thu** — V3 P1-05 xác nhận cờ/ghim theo mã, chưa thử tích hợp bản ứng viên. |
| R-PREVIEW · Trước xác nhận hiển thị tên tối đa 12 Trophy, ô ghim còn hiệu lực và số cá mất. | [ProgressPanel][progress], [TrophyHelper][trophy]. | Dự kiến: 0/12/>12 cá, tên trùng UID khác; preview khớp kết quả server. | **Chưa nghiệm thu** — preview có danh sách/overflow theo V3 P1-05; chưa có ảnh/chơi thử. |
| R-SELLALL · SellAllUnlocked bỏ qua locked hoặc soulbound ngay trước xóa. | [Currency][currency] `SellAllFish`. | Dự kiến: trộn cá thường/locked/Trophy, giả mở khóa Trophy, so Gold/túi. | **Chưa nghiệm thu** — kiểm chặn đạt theo mã V3; phải bảo vệ trên bản ứng viên [V3 ký cuối][v3]. |
| R-SELLSELECT · SellSelectedFish bỏ qua locked hoặc soulbound ngay trước xóa. | [Currency][currency] `SellSelectedFish`. | Dự kiến: UID trùng/không có/locked/Trophy trong cùng yêu cầu. | **Chưa nghiệm thu** — kiểm chặn có mã, chưa có suite các tổ hợp UID. |
| R-SELLONE · SellSingleFish bỏ qua locked hoặc soulbound ngay trước xóa. | [Currency][currency] `SellSingleFish`. | Dự kiến: gửi trực tiếp UID Trophy sau Appraise hoặc giả mở khóa. | **Chưa nghiệm thu** — kiểm chặn có mã; ToggleLock còn từ chối mở khóa Trophy. |
| R-SELLHELD · SellHeldFish giữ cùng bảo vệ và dọn ghim/mô hình khi cá thường được bán. | [Currency][currency] `SellHeldFish/SellSingleFish`, [ShopItems][items]. | Dự kiến: giữ cá ô 2..5, bán thường/Trophy; xác nhận không còn cá ma. | **Chưa nghiệm thu** — gọi lại SellSingleFish và hook túi/visual có mã; cần hai client. |
| R-BOUNTY · Chỉ chủ động nộp Trophy tại Bounty; kiểm UID sở hữu/đảo đã mở; xóa một lần trước thưởng Gems/Relic, dọn ghim/mô hình. | [EnchantBounty][eb] `handleClaimBounty`, [EnchantModal][em], [Currency][currency], [ShopItems][items]. | Dự kiến: UID đúng/sai/trùng, chưa mở đảo, Trophy có cảnh báo, hai yêu cầu và chuyển server sau thưởng. | **Đang chờ sửa** — chọn UID/cảnh báo đạt theo mã V3, nhưng vị trí và lưu bền còn [V3 mục 2.4, 1.2][v3]. |

## 3. Kiến trúc, giới hạn file và hiệu năng

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| K-AUTH · Server quyết định tiền, Strength, vật phẩm/giao dịch; client gửi hành động; manifest Net và BuffAggregator tập trung. | [Net][net], [Buff][buff], [Server init][server], các Services. | Dự kiến: yêu cầu giả giá/quyền/UID/thời gian, kiểm từng dịch vụ không tin số thưởng client. | **Đang chờ sửa** — cấu trúc đã có; còn nhận khóa/Perfect/điểm nảy cần [V3 mục 1.1, 2.1–2.2][v3], không tuyên bố bảo mật 100%. |
| K-SIZE · Mỗi file mã game ≤350 dòng; năm file cam kết <310. | [Verify][verify], [Hud][hud], [PetsService][pets], [ProgressPanel][progress], [Bag][bag], [Fishing][fishing]. | **Đã lưu:** 88/88, max Currency 342; năm file 268/298/268/307/282 tại `45dd21a`. | **Đã xong (mốc nguồn)** — PROGRESS ghi đếm độc lập/PASS; phải đếm lại khi nhận bản sửa, không áp số này cho sửa dở. |
| K-HUD · Tách Hotbar/Auto/Mồi sang HotbarAndBaitUi; mục tiêu HudPanel <230 dòng. | [Hud][hud], [Hotbar][hotbar]. | Đã đối chiếu tên module và số dòng bàn giao. | **Đang chờ sửa (mục tiêu PLAN)** — 268 chưa <230; đã đạt trần <310 của [V3 điều kiện bàn giao][v3]. Blueprint chưa giao tách tiếp; cần chốt mục tiêu trước khi thi công. |
| K-PETS · Chuyển dựng/diễn hoạt Pet khỏi PetsService sang ClientPetRenderer, giữ PetsService <310. | [PetsService][pets], [PetRenderer][renderer]. | Đã đọc ranh giới module; dự kiến thử danh sách trang bị và hiển thị hai phía. | **Đã xong (tách module)** — có renderer Client, PetsService 298 ở bàn giao; runtime/perf chưa nghiệm thu. |
| K-INDEX · Tách Index 3D từ ProgressPanel sang IndexGridSection, ProgressPanel <310. | [ProgressPanel][progress], [Index][index]. | Đã đối chiếu module; dự kiến mở Index hồ sơ rỗng. | **Đang chờ sửa** — đã tách, 268 dòng, nhưng lần vẽ đầu/vùng nhìn sai; [V3 mục 2.5][v3]. |
| K-BAG · Tách thẻ sang ViewportCard/Pool; mục tiêu BagPanel <250 dòng. | [Bag][bag], [Card][card], [Pool][pool]. | Đã đối chiếu module và số dòng bàn giao. | **Đang chờ sửa (mục tiêu PLAN)** — 307 chưa <250; đã đạt <310. [V3 điều kiện bàn giao][v3] chưa giao tách thêm chỉ để giảm dòng. |
| K-SESSION · Tách quản lý phiên/minigame khỏi FishingService sang FishingSessionManager, FishingService <310. | [Fishing][fishing], [Session][session]. | Đã đối chiếu module/số dòng; dự kiến ca đóng phiên/timeout trùng. | **Đã xong (tách module)** — FishingService 282 ở bàn giao; hành vi đóng/hồi còn dòng M-CLOSE. |
| K-PETPERF · Server chỉ đồng bộ ID trang bị; client nội suy; giảm nhịp xa >85 studs/Low GFX, thu hồi khi xa. | [PetsService][pets], [PetRenderer][renderer], [Fx][fx]. | Dự kiến: hai client, chủ đổi đảo >160 studs rồi về; đo frame median/p95 trên cùng điện thoại. | **Đang chờ sửa** — pet xa còn đứng lại vị trí cuối; hạt cá cầm tay chưa lọc đủ; [V3 mục 3.5][v3], Codex P2-05 và hồi quy pet. |
| K-POOL · Chỉ cấp thẻ trong vùng nhìn +hàng đệm, tái dùng UID, không dựng lại khi tiền đổi, xoay một thẻ, dừng khi đóng. | [Pool][pool], [Card][card], [Index][index], [ProgressPanel][progress]. | Dự kiến: túi đầy/cuộn/resize/ẩn tab/mở đóng 50 lần; thẻ ẩn xoay=0, kết nối không tăng. | **Đang chờ sửa** — vẫn dựng thẻ lưới khuất và có thể khởi động xoay khi tab ẩn; [V3 mục 2.5][v3], Codex P1-14 / Argon P1-1. |
| K-VERIFY · Sau mỗi bước PASS 6/6; không xóa file tùy tiện; commit nhỏ và dừng sau hai vòng sửa thất bại. | [Verify][verify], [AGENTS](../AGENTS.md), [PROGRESS](../PROGRESS.md). | Đọc script/quy trình; kết quả game gần nhất là bằng chứng đã lưu; ca tài liệu kiểm diff/liên kết riêng. | **Đã xong (quy trình có văn bản)** — không suy ra mọi ca đều tuân thủ hoặc game đã đạt runtime; [V3 điều kiện bàn giao][v3]. |

## 4. Lộ trình A1–D3 và ca nghiệm thu bắt buộc

| Quy tắc | Module thực hiện | Phép thử kiểm chứng | Trạng thái thực tế và bằng chứng |
|---|---|---|---|
| A1 · Scanner cho FillBlock/so sánh Water, cấm gán Water lên Part; nước cục bộ không Clear toàn map; FishingWater đúng Island_id, mặt khớp và không chặn tia; cảnh quan/nền bệ. | [Verify][verify], [Terrain][terrain], [World][world], [Scenery1_2][sc12], [Scenery3_5][sc35]. | Dự kiến: câu đủ năm đảo ngay sau thay nước, địa hình ngoài hộp còn nguyên; kiểm bounds và mặt nước. | **Chưa nghiệm thu** — có FillBlock Air/Water cục bộ và bounds CanQuery=false; chưa có Engine bằng chứng đủ năm đảo, tia câu còn [V3 mục 2.1][v3]. |
| A2 · Xoáy ngẫu nhiên có bọt/cột sáng/bóng cá; quăng đúng vùng nhân đôi Luck tổng và trọng số Boss trước chuẩn hóa. | [Whirlpool][whirl], [Roller][roller], [Fishing][fishing]. | Dự kiến: trong/ngoài biên xoáy, số liệu F-LUCK/F-BOSS và quan sát hiệu ứng. | **Chưa nghiệm thu** — mã vùng/hiệu ứng có; xác suất UI liên quan [V3 mục 3.2][v3]. |
| A3 · Bốn NPC R15 thở/vẫy tay, thoại an toàn; nghiệm thu Chặng A gồm cả câu năm đảo và địa hình ngoài biển. | [Npc][npc], [Dialogue][dialogue], [Prompt][prompt], [PetRenderer][renderer]. | Dự kiến: túi trước/sau đóng mở Merchant; NPC rig mặc định/override; thoại chồng minigame. | **Đang chờ sửa** — rig mặc định đạt theo mã V3 P1-17; phạm vi/camera còn [V3 mục 2.4, Camera và cảm ứng][v3]. |
| B1 · Session Lock/migration/Trophy và tách SessionManager; nộp Bounty rồi chuyển server vẫn đúng một UID/thưởng, tải lỗi chặn giao dịch. | [Data][data], [Lock][lock], [Migrator][migrator], [Session][session], [Progression][prog]. | Dự kiến: toàn bộ D-LOAD/D-RENEW/D-CLOSE/D-SCHEMA và Bounty hai server kho thử. | **Đang chờ sửa** — [V3 Đợt 1 mục 1.1–1.5][v3]; bản vá cách ly chỉ mở đầu, không nghiệm thu B1. |
| B2 · Hotbar/ghim/mồi/Auto, parabol/nảy, !/cong cần/zoom, bốn chế độ và minigame từng vòng ở ping 200ms. | [Hotbar][hotbar], [CastController][cast], [FishingController][fc], [Fishing][fishing], [Session][session], [RodVisuals][rodvis]. | Dự kiến: O1–O5, các dòng M-*, hai client và thao tác hai ngón trên điện thoại. | **Đang chờ sửa** — [V3 mục 2.1–2.3, 3.4, Camera và cảm ứng][v3]; camera phải 62° khi còn thoại, 64° chỉ minigame, 70° đóng cả hai. |
| B3 · Năm chỉ số/chín cần, cân năm đảo, ba nguồn Exclusive, sáu Enchant, % công khai và Policy. | [Rods][rods], [Đảo 1][i1]–[Đảo 5][i5], [EnchantConfig][ench], [EnchantBounty][eb], [Odds][odds]. | Dự kiến: 2.1.A/B/C, F-ODDS/F-POLICY; kiểm mua và quyền pass mô phỏng trước ID thật. | **Đang chờ sửa** — [V3 Đợt 2 quyết định cân bằng; mục 2.4, 3.1–3.3][v3]. |
| C1 · Lưới Bag/Shop/Pets/Index, mô hình lớn giữa ô, nhãn size/mutation góc trên, cân/giá đáy; mượt mobile, không rebuild theo tiền. | [Bag][bag], [Shop][shop], [PetsPanel][petui], [Index][index], [Card][card], [Pool][pool]. | Dự kiến: hồ sơ mới 0/35 cá, 0/30 pet; túi đầy, cuộn, resize, cập nhật tiền, đo thiết bị. | **Đang chờ sửa** — [V3 mục 2.5][v3]; chưa có phép đo mobile để gọi “mượt”. |
| C2 · Lock/Auto-Lock, Multi-Select, Sell Held, bảo vệ locked/soulbound và đồng bộ ghim/mô hình ngay. | [Currency][currency], [Fishing][fishing], [Bag][bag], [ShopItems][items]. | Dự kiến: từng đường bán R-SELL*, cá hiếm/đột biến/Titanic; nhận cập nhật cả hai client. | **Chưa nghiệm thu** — bảo vệ bán đạt theo mã V3, cần kiểm lại trên bản ứng viên theo [V3 điều kiện ký][v3]. |
| C3 · Appraise, ba hợp đồng Bounty tiêu UID một lần, chín quà UTC; Settings Auto-Lock/Low GFX/Mute. | [EnchantBounty][eb], [BountyConfig][bounty], [Progression][prog], [GiftsSettings][gifts], [Fx][fx]. | Dự kiến: AP-*, R-BOUNTY, D-UTC; bật/tắt/lưu Settings và thử sau vào lại. | **Đang chờ sửa** — vị trí, lưu dữ liệu và Low GFX còn [V3 mục 1.2–1.3, 2.4, 3.5][v3]. |
| D1 · Năm họ cá, sáu dòng Pet Chibi; chuyển toàn bộ diễn hoạt Pet sang Client. | [FishBuilder][fishbuild], [PetBuilder][petbuild], [RodWeightBuilder][rwbuild], [PetRenderer][renderer]. | Dự kiến: xem từng họ/biến thể trong lưới và thế giới, chủ đi xa rồi trở về. | **Đang chờ sửa** — thư viện/model có; pet xa còn hồi quy [V3 mục 3.5][v3], chất lượng nhìn chưa nghiệm thu. |
| D2 · Trứng nứt/nổ sáng có SKIP; Rank/Aura theo Strength/Rebirth; tạ đơn/đòn gắn tay đúng. | [EggCutscene][egg], [Ranks][ranks], [PlayerVisuals][pv], [RodWeightBuilder][rwbuild]. | Dự kiến: hatch/SKIP/trứng lỗi, từng mốc Rank; hai client R6/R15 lúc tập và hồi sinh. | **Đang chờ sửa** — tạ/hoạt ảnh chưa đủ ca, [V3 mục 3.4][v3]; cutscene và Rank/Aura chưa có bằng chứng Engine mới. |
| D3 · Diễn hoạt toàn thân, nhạc/SFX, hiệu năng túi đầy/nhiều Pet, kiểm định tổng thể và quyết định phát hành. | [Animation][anim], [SoundConfig][sound], [Fx][fx], [PetRenderer][renderer], [Verify][verify]. | Dự kiến: hai client, ping 200ms, điện thoại; median/p95; build khớp nguồn và SHA-256; đóng đủ 23 mã, giữ 21 mục cũ. | **Đang chờ sửa** — [V3 mục 3.4–3.5 và điều kiện ký][v3]. PASS 6/6 đã lưu không đủ ký; hiện **chưa duyệt phát hành**. |

## Bàn giao cập nhật matrix

Mỗi lần đóng quy tắc, ghi commit nguồn, lệnh/ca đã chạy, mong đợi/thực tế, loại môi trường và vị trí bằng chứng. Chỉ đổi trạng thái đúng phạm vi đã kiểm; giữ riêng kết quả mô phỏng, đọc mã và Engine. Sau khi bản vá song song được commit/review, đối chiếu lại D-LOAD/D-ID và số dòng, không tự nâng các mục Đợt 1 còn lại. Không có dòng nào ở đây cấp phép mở API sản xuất hoặc phát hành.

[audit]: CODEX_CODE_AUDIT_V3.md
[v3]: superpowers/plans/2026-11-18-action-blueprint-v3.md
[suite]: ../tests/studio_data_isolation.luau
[verify]: ../tools/verify_project.ps1
[game]: ../src/shared/Config/GameConfig.luau
[rods]: ../src/shared/Config/RodsConfig.luau
[ench]: ../src/shared/Config/EnchantsConfig.luau
[bounty]: ../src/shared/Config/BountiesConfig.luau
[passes]: ../src/shared/Config/GamepassesConfig.luau
[ranks]: ../src/shared/Config/RanksConfig.luau
[sound]: ../src/shared/Config/SoundConfig.luau
[i1]: ../src/shared/Config/Islands/Island1_SunnyShores.luau
[i2]: ../src/shared/Config/Islands/Island2_CoralDepths.luau
[i3]: ../src/shared/Config/Islands/Island3_MysticSwamp.luau
[i4]: ../src/shared/Config/Islands/Island4_EmberIsle.luau
[i5]: ../src/shared/Config/Islands/Island5_CelestialDeep.luau
[types]: ../src/shared/Types.luau
[util]: ../src/shared/Util.luau
[net]: ../src/shared/Net.luau
[trophy]: ../src/shared/TrophyHelper.luau
[odds]: ../src/shared/OddsCalculator.luau
[fishbuild]: ../src/shared/ModelBuilders/FishModelBuilder.luau
[petbuild]: ../src/shared/ModelBuilders/PetModelBuilder.luau
[rwbuild]: ../src/shared/ModelBuilders/RodAndWeightBuilder.luau
[server]: ../src/server/init.server.luau
[data]: ../src/server/Services/DataService.luau
[lock]: ../src/server/Services/DataStoreLockHelper.luau
[migrator]: ../src/server/Services/ProfileMigrator.luau
[fishing]: ../src/server/Services/FishingService.luau
[roller]: ../src/server/Services/FishingRoller.luau
[session]: ../src/server/Services/FishingSessionManager.luau
[buff]: ../src/server/Services/BuffAggregator.luau
[currency]: ../src/server/Services/CurrencyService.luau
[items]: ../src/server/Services/ShopAndItemsService.luau
[prog]: ../src/server/Services/ProgressionService.luau
[eb]: ../src/server/Services/EnchantAndBountyService.luau
[perk]: ../src/server/Services/PerkService.luau
[pets]: ../src/server/Services/PetsService.luau
[live]: ../src/server/Services/LiveOpsService.luau
[gym]: ../src/server/Services/GymService.luau
[iservice]: ../src/server/Services/IslandService.luau
[pb]: ../src/server/Services/PotionAndBaitHelper.luau
[dev]: ../src/server/Services/DevTestService.luau
[world]: ../src/server/World/WorldBuilder.luau
[terrain]: ../src/server/World/TerrainWaterBuilder.luau
[whirl]: ../src/server/World/WhirlpoolManager.luau
[npc]: ../src/server/World/NpcBuilder.luau
[sc12]: ../src/server/World/IslandScenery1_2.luau
[sc35]: ../src/server/World/IslandScenery3_5.luau
[pv]: ../src/server/World/PlayerVisuals.luau
[fishvis]: ../src/server/World/PetAndFishVisuals.luau
[rodvis]: ../src/server/World/RodVisuals.luau
[hotbar]: ../src/client/UI/Components/HotbarAndBaitUi.luau
[dialogue]: ../src/client/UI/Components/NpcDialogueModal.luau
[index]: ../src/client/UI/Components/IndexGridSection.luau
[pool]: ../src/client/UI/Components/ViewportPool.luau
[card]: ../src/client/UI/Components/ViewportCard.luau
[hud]: ../src/client/UI/Panels/HudPanel.luau
[bag]: ../src/client/UI/Panels/BagPanel.luau
[shop]: ../src/client/UI/Panels/ShopPanel.luau
[petui]: ../src/client/UI/Panels/PetsPanel.luau
[progress]: ../src/client/UI/Panels/ProgressPanel.luau
[mini]: ../src/client/UI/Panels/MinigameBar.luau
[em]: ../src/client/UI/Panels/EnchantAndBountyModal.luau
[gifts]: ../src/client/UI/Panels/PlaytimeAndSettingsModal.luau
[devui]: ../src/client/UI/Panels/DevTestPanel.luau
[cast]: ../src/client/Controllers/HotbarAndCastController.luau
[fc]: ../src/client/Controllers/FishingController.luau
[state]: ../src/client/Controllers/ClientStateController.luau
[renderer]: ../src/client/Controllers/ClientPetRenderer.luau
[anim]: ../src/client/Controllers/AnimationController.luau
[egg]: ../src/client/Controllers/EggHatchCutscene.luau
[fx]: ../src/client/Controllers/SoundAndFxController.luau
[prompt]: ../src/client/Controllers/PromptController.luau
