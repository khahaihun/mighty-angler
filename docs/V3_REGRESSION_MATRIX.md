# V3_REGRESSION_MATRIX — bảo vệ 21 mục đã đạt theo mã

> **Ứng viên hợp nhất cuối:** code kiểm sạch `dd53d3a`, đã nhập dữ liệu đến1.5 `8699970`. Tất cả13 runner mặc định exit0 +verify6/6; init14/14 (13gốc+1giao thoa LiveOdds/readOnly), schema29/29, Reset12/12, persistence7/7; Source101/101, hash `9BD66C58AD037E8D5AAE3841841E315EC0B727465FC98CB56699A35A1D52EDE5`. Các phần kết quả nền9282aa6/ghép sơ bộ bên dưới là **lịch sử**, lỗi/pending cũ không còn là kết quả hiện tại. [Bàn giao23mã và checklist cuối](V3_BAN_GIAO_NGHIEM_THU.md). **Studio chưa chạy vì quyền ứng dụng; toàn bộ ca Engine vẫn chờ, chưa duyệt phát hành.**

- Nền chạy: `9282aa6`, nhánh riêng `codex/v3-regression`, ngày 18/11/2026, Codex (công nhân kiểm thử).
- Nguồn 21 ID: các dòng **Đạt** trong `docs/CODEX_CODE_AUDIT_V3.md`: 12 Argon + 9 Codex. Đây là 21 nhận định kiểm toán theo mã, **không phải 21 ca Studio đã đạt**.
- Không sửa `src/`, suite dữ liệu cũ, hoặc checkout chính. Suite mới dùng nguồn production nguyên văn nhúng vào Luau VM; chỉ giả lập Net, DataService, vị trí NPC, biểu diễn, cấu hình thành tựu và biên dịch vụ liên quan.
- Ký hiệu: **VM** = đường production đã chạy với biên giả lập; **Đọc mã** = đã đối chiếu mã, chưa chạy Engine; **Studio chờ** = phải thử trên bản tích hợp/staging. Không dùng kết quả VM để đóng nghiệm thu visual, mobile, DataStore thật hoặc phát hành.

## Kết quả trên nền độc lập

| Lệnh | Kết quả quan sát |
|---|---|
| `powershell -ExecutionPolicy Bypass -File tools/test_v3_regression.ps1` | **23/23 PASS, exit 0**. Trident, Bounty, bốn đường bán + đối chứng bán được cá thường, Appraise, công thức Trident, Titan, partition + hai lần Rebirth thật, trao cá/Strength. |
| Cùng lệnh với `-ProbeMutation AppraiseFloor` | **exit 1 như mong đợi**, sàn sai 8,8 bị bắt thay vì 8,9. |
| `-ProbeMutation StrengthTwice` | **exit 1 như mong đợi**, Strength thành 325 thay vì 125 bị bắt. |
| `-ProbeMutation TridentTrophy` | **exit 1 như mong đợi**, mất 800 Gems khi đổi Trophy bị bắt. |
| `-ProbeMutation RebirthCap` | **exit 1 như mong đợi**, giữ 13 thay vì 12 bị bắt. |
| `powershell -ExecutionPolicy Bypass -File tools/verify_project.ps1` | **PASS 6/6, exit 0** sau khi copy `roblox.yml` cache từ nguồn. Lần đầu thiếu cache, Selene không tải được API dump; không đổi luật lint. |
| `powershell -ExecutionPolicy Bypass -File tools/test_studio_data_isolation.ps1` | **exit 1**: Studio isolation PASS; session acquisition **19/19**; persistence **3 PASS/4 FAIL** thuộc baseline Đợt 1. Không chỉnh/nới assertions: `late_save_response_cannot_extend_ownership`, `both_close_paths_wait_for_final_save`, `malformed_profile_is_quarantined`, `dev_reset_during_autosave`. |

Các probe chỉ sửa chuỗi được nhúng vào runner trong `build/`, không viết vào mã game. Sau probe, chạy lại suite không tham số phải đạt 23/23. Log cục bộ bỏ qua bởi Git ở `logs/v3-probe-*.log`; kết quả có thể tái tạo từ commit, không phụ thuộc log có sẵn.

## Theo dõi đủ 21 ID

| # | ID V3 | Phạm vi đã đối chiếu / bằng chứng chạy thật trong VM | Ca bắt buộc còn chờ trên bản tích hợp |
|---|---|---|---|
| 1 | Argon P0-1 | **VM suite có sẵn** `studio_data_isolation`: chỉ hồ sơ có quyền ghi được lưu TopStr/TopGold, giữ max, không ghi điểm 0. | Hai server staging: hồ sơ không quyền ghi không đổi cả hai bảng; kho Studio riêng. Đây không đóng lỗi TTL/lưu cuối. |
| 2 | Argon P0-2 | **Đọc mã** `PetsService` chặn Gems khi policy loading/restricted trước SpendGems; `PetsPanel` phản ánh policy. Không có VM mới cho mục này. | Studio/mock policy loading/restricted/allowed: Gems không giảm khi chặn, Gold vẫn ấp được, trạng thái nút đúng; thiếu boolean thuộc bản vá riêng. |
| 3 | Argon P0-4 | **Đọc mã** `FishingRoller.IsFiniteVector3`, `ValidateAimedWaterPoint`, `IsWithinLandBounceRange`, `FishingService.StartCast`. | Studio: NaN/inf/xa/đất/trời từ chối, không thưởng cá hoặc dịch chuyển ra cầu; nước mở phiên. Nhánh Auto/điểm nảy còn mục sửa riêng, không suy ra đã đạt. |
| 4 | Argon P1-2 | **VM** Appraise thấp hơn bậc/đột biến cũ vẫn giữ Titanic/Golden, giá gốc dùng 3×5, Trophy giá bán 0. | F5: nhãn bậc/đột biến, giá, cân trên Bag và cá cầm khớp sau Appraise; nâng bậc đúng khi quay tốt hơn. |
| 5 | Argon P1-7 | **VM** Trident tiêu đúng UID, chặn locked/Trophy/sai đảo/UID, thiếu Gems không mất cá; Bounty nhận Trophy được chỉ định, thưởng một lần, replay không thưởng. **Đọc mã** modal sắp cá thường/cảnh báo GIVE TROPHY. | F5: có 2 Boss thường + Trophy, đổi đúng cá đang xem; Bounty cho đổi ứng viên và cảnh báo Trophy rõ trước nộp. |
| 6 | Argon P1-8 | **Đọc mã** `ClientPetRenderer` kiểm thế hệ/người/nhân vật sau chờ, dọn kết nối khi rời. | Hai client: respawn/rời giữa callback chờ, không mọc pet ma/duplicate, không giữ connection cũ. Lỗi xa >160 studs theo V3 vẫn riêng. |
| 7 | Argon P1-9 | **Đọc mã** `PlayerVisuals`: offset R6 -0,95, BenchPress neo thân. | Hai client R6/R15: quả tạ nằm trong tay, đòn ngang giữa hai tay/thân khi đứng và tập. Không coi vị trí tĩnh là nghiệm thu animation. |
| 8 | Argon P1-10 | **Đọc mã** `ClientPetRenderer`, `NpcBuilder`, `WhirlpoolManager`: server dựng/quản vòng đời; client cập nhật gần 135/185 studs và Low GFX. | Hai client gần/xa, bật Low GFX: NPC/bóng cá ngừng đúng; profiler xác nhận server không có vòng Heartbeat diễn hoạt. |
| 9 | Argon P2-1 | **VM** shared `TrophyHelper` partition, server `DoRebirth` giữ đúng 12 từ preview, overflow 2, giữ/xóa pin đúng, qua 2 Rebirth; **Đọc mã** `ProgressPanel` khung tăng chiều cao. | Mobile/F5: preview 14 cá khóa hiện đủ 12 giữ + 2 mất và slot ghim, không cắt nội dung. |
| 10 | Argon P2-2 | **VM** `FishingRoller` trọng số Titanic nhân 2,5; cap 5.750×1,25=7.187,5; tier Titanic và valueMult 3 không đổi; award giữ tier/giá. | F5: bắt cá Titan ở trần, UI/cá thật ghi đúng tier, cân không vượt cap; không ký nhánh non-Titan đang được sửa riêng. |
| 11 | Argon P2-3 | **Đọc mã** `TutorialController`, `PropsBuilder`: lời hướng dẫn ô 1/giữ thả/cách bán. | Hồ sơ mới F5/mobile: hoàn thành hướng dẫn theo đúng nút thực tế, biển cầu đọc được. |
| 12 | Argon P2-4 | **Đọc mã** `SoundAndFxController` góc rung trả 60%+40%; `NpcDialogueModal` đóng thoại khi đang minigame giữ FOV 64. | F5: rung lặp 50 lần không nghiêng camera; mở rồi đóng thoại trong minigame giữ 64. Chiều mở thoại trong minigame còn bản vá riêng. |
| 13 | Codex P0-03 | **VM** các ca Trident qua callback Net thật; UID thường hợp lệ mất đúng một cá +800 Gems; Trophy không mở khóa được; bốn đường Gold giữ cá bảo vệ và đối chứng cá thường bán được. | F5: UI gửi UID đang chọn, nếu chỉ Trophy không có ứng viên đổi Trident. |
| 14 | Codex P1-02 | **VM có sẵn** cùng suite bảng điểm tại #1. Không đếm là một suite độc lập mới. | Hai server staging: max điểm bền vững; bảng đang trong phòng chỉ hiển thị người hiện diện theo thiết kế. |
| 15 | Codex P1-05 | **VM** ưu tiên soulbound trước giá gốc/cân/UID; cap/overflow; server giữ pin; Trophy không mở khóa; hai Rebirth giữ 12. | F5/mobile: preview đúng danh sách bị mất; cá giữ vẫn cầm khoe được sau đổi server. |
| 16 | Codex P1-07 | **VM** cùng Titan roll/award tại #10; nhãn và 3× giá vẫn theo lượt quay. | F5: award/client hiển thị đúng cá khổng lồ tại cap. |
| 17 | Codex P1-15 | **Đọc mã** `ClientPetRenderer`: callback thế hệ, `PivotTo` cả model. | Hai client với pet mặc định và Toolbox nhiều Part: respawn/rời không nhân đôi; mọi part cùng di chuyển. Không đóng hồi quy chủ pet >160 studs. |
| 18 | Codex P1-17 | **Đọc mã** `NpcBuilder` mặc định tạo Humanoid R15/Animator/15 phần/Motor6D/weld; diễn hoạt trên client. | F5/hai client kiểm bốn NPC default đủ rig và thở/vẫy gần; Toolbox kiểm riêng cờ Anchored và animation, không suy từ default. |
| 19 | Codex P2-01 | **VM** sàn 10,4→8,9, AppraiseResult gửi indexFish ngay khi phá kỷ lục, lần không phá không gửi giả. **Đọc mã** ClientStateController chuyển payload vào ProgressPanel; SyncPayload giữ các phần vắng mặt. | F5: mở Index, Appraise phá kỷ lục, cân cập nhật tức thời; pet/quest/achievement không bị xóa. Chưa tự động chạy client UI trong VM. |
| 20 | Codex P2-03 | **VM** `FishingService` award dùng snap strength 2,5, buff hiện tại 9 bị bỏ qua; `CurrencyService` thật chỉ cộng 25 từ gốc 10, totalStrength/catch payload đều đúng. **Đọc mã** `StartCast` lấy snapshot lúc quăng. | F5: quăng lúc potion active rồi hết potion/đổi buff khi chờ; thưởng theo lúc quăng, không nhân đôi. VM mock session nên chưa chứng minh quá trình hẹn giờ/capture của SessionManager thật. |
| 21 | Codex P2-04 | **Đọc mã** `HotbarAndCastController`: theo InputObject bắt đầu và vị trí lúc thả; `FishingController`/Hotbar ẩn REEL IN trong minigame. | Điện thoại thật: giữ quăng bằng ngón A, chạm B không hủy/đổi đích; A thả lấy đích cuối; REEL IN ẩn khi minigame. |

## Tái chạy trên bản tích hợp

1. Cherry-pick commit test này vào bản ứng viên có code Đợt 1/2/3/4 đã review; giữ runner `test_v3_regression.ps1` riêng, không thay suite của người khác. Xem diff để bảo đảm chỉ test/tài liệu được đưa sang.
2. Chuẩn bị công cụ cục bộ `tools/luau.exe`, `rojo.exe`, `luau-lsp.exe`, `selene.exe`, `globalTypes.d.luau` và cache `roblox.yml`. Không cần API Roblox hay key để chạy suite VM.
3. Chạy ba lệnh ở bảng đầu; lưu stdout/stderr + exit code gắn SHA ứng viên. Sau khi tích hợp Đợt 1, bốn lỗi baseline persistence phải chuyển PASS bằng bản vá thật, không miễn trừ trong nghiệm thu.
4. Chạy bốn probe; mỗi probe phải exit 1 vì assertion tương ứng. Nếu target source đã đổi, lỗi `Probe target changed` chỉ cho biết probe cần cập nhật sau review; không phải bằng chứng chốt hồi quy bắt được. Chạy không probe lần cuối phải exit 0.
5. Chạy các ca Studio F5, Server & Clients, ping 200ms và điện thoại theo bảng trên; ghi phiên bản place/SHA, thiết bị, ảnh/video hoặc Output, kết quả và lỗi còn lại. Tất cả ca Engine trong bản này hiện **chờ nghiệm thu**, không có ảnh/video chạy game.
6. Kỹ sư trưởng quyết định sign-off theo blueprint: 23/23 VM mới + bảng mã 21 dòng chưa đủ cho phát hành. Suite này không kiểm phân phối random thống kê, network thật, xác suất Gems, vòng đời pet Engine hay ổn định DataStore thật.

## Cập nhật hợp nhất sơ bộ (18/11/2026)

Bản ứng viên `codex/v3-combined` đã merge giữ lịch sử dữ liệu `0ded6d4`,
regression `3132629`, fishing `db2387a`, UI `a7bcfc7`. Nội dung bảng nền ở trên
là lịch sử lần chạy độc lập, không ghi đè bằng kết quả bản hợp nhất.

- Regression **23/23 PASS** sau cập nhật mock biên `WorldPromptAccess.IsNear` (đứng hợp lệ tại prompt); không đổi/nới assertion. Phạm vi prompt thật kiểm ở suite fishing riêng.
- Chạy sơ bộ chín `tools/test*.ps1`: tám exit 0; runner dữ liệu chung exit 1,
  persistence **5/7**, còn đúng 1.3 và 1.4 đỏ trên nền `0ded6d4`;
  acquisition **19/19**, lifecycle **12/12**. Verify **PASS 6/6 exit 0**.
- **1.5 chưa xong**; còn chờ các tip cuối đã review, sau đó phải chạy lại mọi runner
  từ checkout sạch và đối chiếu toàn bộ Source place. Kết quả sơ bộ này không
  thay thế việc kiểm bản ứng viên cuối hoặc nghiệm thu hai server/Studio/mobile.

## Tích hợp gameplay + UI odds (18/11/2026, chưa có tip Đợt 1 cuối)

- Đã merge lịch sử fishing `3f43d35`, UI `0ca67fe` và odds `ad013c4`; FishingRoller giữ đủ first-hit ray/Auto validator, chấm thời gian giữ server và OddsCalculator chung, kèm cap/rounding thường–Titan đúng từng nhánh.
- `test_combined_integration.ps1` chạy **FishingCastState + FishingController + CameraFocusController thật** trong cùng VM: đồng hồ server khác os.clock, đổi đảo/Rebirth/hồi sinh giữ ON và quăng lại đúng một lần, trùng reset không nhân lịch, hủy tay chặn timer chuyển trạng thái, camera thoại/minigame trả đúng 62/64/70. Cùng runner so trọng số RollFishSpecies thật và % UI ComputeFishOdds thật ở nước thường/xoáy.
- Minigame widget, tween/nhân vật và mạng vẫn là biên giả. Phép thử mới không phải kết quả Engine, ping thật hoặc ảnh mobile; bài odds đầy đủ vẫn do suite 19.200 rổ kiểm riêng.
- Sơ bộ **12 runner**: 11 exit 0; data chung exit 1, đúng 1.3/1.4 (persistence 5/7), 1.5 chưa xong. Verify PASS 6/6. Chờ tip dữ liệu rồi kiểm lại mọi runner trên SHA ứng viên sạch và so toàn bộ Source place.

### Kiểm bổ sung UI Live Odds và thao tác pet

Đã merge `9c93901`. Suite live odds chạy 19.200 rổ và controller bảng thật với tài khoản
sở hữu AutoPro/Dragon: vẫn xem được Base/Live từng loài, cập nhật mode/buff, đóng không phát
prompt mua. Các handler thật của PetsService được kiểm: đủ 2/4 slot không tự thay pet cũ;
UnequipPet rồi EquipPet mới thành công; Unequip All và Equip Best vẫn hoạt động, pet mạnh nhất
được giữ và không trùng UID. Đọc PetsPanel xác nhận card đang đeo gửi UnequipPet,
vẫn có nút Unequip All/Equip Best. VM PASS; hình ảnh/cảm ứng thật chờ nghiệm thu.
Verify6/6 và suite scoreboard cách ly/quyền ghi/giữ max PASS; dữ liệu baseline vẫn 1.3/1.4 đỏ.
Sau tip dữ liệu cuối còn phải kiểm Live Odds cùng HUD safeReadOnly và chạy sạch lại toàn bộ.

## Bản dữ liệu 99216b5 đã hợp nhất (chờ 1.5)

Merge lịch sử `053a393` nhập validation/slot0/Reset lease. Kiểm lại mọi test script
liệt kê bằng `rg --files tools`: 12 runner cũ đều exit0; dữ liệu nay schema29/29,
reset12/12, persistence7/7 (hết hai lỗi baseline trên ứng viên này), acquisition19/19,
lifecycle12/12. Verify6/6 exit0. Thêm runner `test_place_sources.ps1` đạt100/100 Source,
class/path khớp sourcemap và nguồn đĩa; hash và checklist23 mã có ở
[V3_BAN_GIAO_NGHIEM_THU](V3_BAN_GIAO_NGHIEM_THU.md).
**1.5 vẫn chờ tip; Studio chưa chạy vì quyền ứng dụng.** Mọi kết quả Engine của bảng21
vẫn chờ; không ghi kết luận đã sạch lỗi hoặc phát hành. Hash hiện tại cần tính lại sau1.5.
