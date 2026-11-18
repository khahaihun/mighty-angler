# Kiểm hồi quy dữ liệu

Chạy từ gốc dự án:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
```

Cần `tools/luau.exe`. Ca này dùng **Luau CLI 0.747** từ [bản phát hành chính thức](https://github.com/luau-lang/luau/releases/tag/0.747), gói `luau-windows.zip`. Chỉ giải nén `luau.exe` vào `tools/`; không cài hệ thống. SHA-256 của executable đã dùng: `FF0ACF7D2DF9D38E30C85EE9FE698EFD756A920496C84EA848B74D0E2082E958`. Binary được Git bỏ qua theo quy tắc có sẵn. Có thể truyền đường dẫn CLI bằng `-LuauExe`.

Lệnh trên chạy `studio_data_isolation`, `session_acquisition`, `session_lifecycle`, `profile_schema`, `dev_reset` và `data_persistence`. Các bộ còn lại vẫn chạy nếu một bộ lỗi. Cuối cùng lệnh trả mã lỗi nếu bất kỳ bộ nào FAIL. CI vẫn chạy toàn bộ bằng lệnh mặc định; có thể chạy riêng một bộ bằng `-Suite <tên bộ>` để khoanh vùng khi sửa.

## Reset DEV — mục 1.4

`-Suite dev_reset` chạy 12 ca qua handler thật, gồm giữ đối tượng cũ đến khi pending write được xác nhận, báo riêng RAM/lưu bền, lỗi API, RAM-only, Reset đồng thời, rời lúc chờ và bốn ca hết lease trước/trong hàng đợi có/không chủ B. `client_fixture` giả lập các biên Instance/Theme/Net để kiểm module DevTestPanel nhận kết quả và đổi Text; không chứng minh bố cục/render hay input của Roblox Engine.

Sau 1.4, toàn bộ bộ hồi quy mặc định đạt exit 0: 19 acquisition, 12 lifecycle, 29 schema, 8 Reset, 7 persistence và cách ly Studio. Các kết quả đỏ ở mục lịch sử bên dưới được giữ để truy vết.

## Xác thực hồ sơ — mục 1.3

`-Suite profile_schema` chạy 26 ca schema/migration/UTC/scheduler qua module thật. Kiểm đủ kiểu và cấu trúc trước reconcile, claim và ghi; mảng đặc được kiểm bằng toàn bộ key, không dựa vào ipairs. V1 có thể thiếu trường mới, v2 không tự bù trường bị mất, giá trị sai kiểu không bị thay bằng mặc định. Schema hỏng/future giữ nguyên kho. Một hồ sơ lỗi hoặc lỗi gửi thông báo riêng không dừng lịch gia hạn của người khác.

Sau mục 1.3: schema 26/26, persistence 6/7; còn đúng Reset 1.4 đỏ, bộ chung vẫn exit 1. Kết quả mục 1.2 bên dưới là mốc lịch sử.

## Cách ly dữ liệu Studio

PowerShell nhúng nguyên văn nguồn `DataStoreLockHelper`, `LiveOpsService`, `GameConfig`, `Types`, `Util` vào runner trong `build/`. Luau VM thực thi các module đó với dịch vụ Roblox giả lập; không dịch lại logic sang ngôn ngữ khác. Bộ thử ghi từng lời gọi tại `GetDataStore` và `GetOrderedDataStore`, chạy refresh đầu tiên và nhịp refresh định kỳ thật của `LiveOpsService.Init()`.

Các ca gồm Studio chưa publish, Studio đã publish, máy chủ thật mô phỏng, lỗi mở lần lượt từng kho, hồ sơ chỉ đọc/chưa tải, điểm thấp hơn/cao hơn và điểm 0. Toàn bộ kho chỉ là bảng trong RAM; phép thử không gọi Roblox API hoặc mạng và không cần bật API Services.

`DataService.Get/CanWritePersistent` là đầu vào điều khiển của phép thử để kiểm **LiveOps có tuân thủ quyền ghi hay không**. Bộ thử chưa xác nhận tính đúng của khóa phiên, tải/lưu cuối, DataStore Roblox thật, giao diện hoặc lịch chạy của Roblox Engine. Những ca đó cần nghiệm thu riêng trong Studio/máy chủ thử.

Kết quả `verify_project.ps1` là bộ kiểm định tĩnh/build riêng, không thay thế bộ mô phỏng này hoặc nghiệm thu Studio.

## Nhận khóa và nhả khóa khi rời lúc tải — mục 1.1

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_session_acquisition.ps1
```

Dùng cùng Luau CLI, chạy nguyên văn `DataService`, `DataStoreLockHelper`, `ProfileMigrator`, `GameConfig`, `Types`, `Util`. `tests/session_fixture.luau` giả lập dịch vụ Roblox, tín hiệu người chơi, đồng hồ và kho RAM chung cho hai máy chủ độc lập. `DataService.Init()` đăng ký các đường load/save thật; không thay `Get`, `CanWritePersistent`, `IsTransactionLocked` hoặc các hàm khóa phiên bằng mock.

`tests/session_acquisition.luau` có 19 ca: ngoại lệ nonce và hàng chờ trước yêu cầu nhận khóa, tải đang chờ, phản hồi sai token/nonce, API nhận khóa lỗi, chủ A đang giữ khóa, hai lượt vào cùng UserId, rời lúc tải với nhả lỗi tạm/hết lượt thử, nhả đã ghi nhưng mất phản hồi, nhả A bị chậm trước/sau commit trong lúc B đã giữ khóa, claim đã ghi nhưng mất phản hồi rồi A rời (có/không B), rời ngay sau tải thất bại với cả ba phản hồi claim bị mất, nonce lỗi sau một claim chưa chắc chắn, rời trong lúc nhả hồ sơ bị cách ly, và RAM-only. Các ca thành công còn kiểm lưu số dư và tăng `saveSeq` qua `SaveProfile` thật. Kiểm ngân sách riêng: không gửi nhả khi chưa từng gửi claim hoặc đã biết kho từ chối do chủ khác; lỗi phản hồi chưa chắc chắn có tối đa 3 lần dọn token, tách khỏi 3 lần xin khóa.

Kho giả sao chép giá trị qua biên API và chạy lại callback nếu máy chủ khác ghi trong lúc yêu cầu bị treo, theo [quy tắc UpdateAsync của Roblox](https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/GlobalDataStore.yaml#L351). Việc tạm dừng nằm ở biên API, không nằm trong callback. Đồng hồ và lịch coroutine do phép thử điều khiển; đây là mô phỏng, không phải hành vi mạng/Engine đã được chứng nhận.

Chưa nghiệm thu Studio/hai máy chủ Roblox thật. Bộ nhận khóa không thay phép kiểm đóng/lưu cuối ở bộ bên dưới, dữ liệu hỏng của 1.3, Reset 1.4 hoặc HUD 1.5.

## Quyền ghi, gia hạn và đóng phiên — mục 1.2

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1 -Suite session_lifecycle
```

`session_lifecycle.luau` có 12 ca: dấu giờ claim và lưu muộn; khóa giao dịch trước snapshot cuối; hai đường đóng cùng nhận một kết quả; mất phản hồi ghi lẫn đọc xác nhận; bảo toàn chủ B khi xác nhận lần nhả A; hết hạn đóng có kết quả Unconfirmed; retry cùng nonce rồi lưu tiến độ mới; mất quyền khi chờ API/hàng đợi; gia hạn hồ sơ đứng yên theo các pha khác nhau; đóng song song khi một hồ sơ treo; đường SaveProfile(release=true); và 30 lượt rời/vào không tích lũy phiên trong registry.

Nguồn thật bổ sung `ProfileWriteHelper` và `ProfilePersistenceService`; bộ nhận khóa riêng cũng tải hai module này. Fixture chạy lịch coroutine có hạn, nhiều khóa UserId trong cùng kho RAM, GetAsync không cache và retry callback khi xung đột. Get/Save/Close/BindToClose vẫn đi qua module và điểm vào thật; không giả kết quả quyền ghi hoặc kết quả đóng.

Kết quả cuối mục 1.2: 12/12 và 19/19 đạt; `data_persistence` đạt 5/7, còn đỏ **malformed_profile_is_quarantined (1.3)** và **dev_reset_during_autosave (1.4)**. Bộ chung vẫn trả **exit 1**, các assertion lỗi được giữ nguyên. Đây không phải CI xanh hay nghiệm thu Engine; xem PROGRESS cho SHA và kết quả của bản cụ thể.

## Lưu hồ sơ và giao dịch đổi cá

`data_persistence.luau` dùng lại kho RAM và lịch coroutine của `session_fixture.luau`. Bảy ca kiểm hai phiên tranh khóa, thử lại lưu cuối khi lỗi tạm, phản hồi lưu muộn, hai đường đóng đồng thời, hồ sơ sai kiểu, nút Reset DEV trong lúc autosave và nộp lại cùng UID cá trước/sau đổi máy chủ.

Ca Reset đi qua handler DEV và lịch autosave thật. Ca đổi cá đi qua handler Bounty thật, dùng cấu hình đảo/hợp đồng và kiểm Gems, Relic, thuốc, túi cùng ô ghim; chồng autosave trước giao dịch với cả hai đường đóng, làm mất phản hồi cuối và giữ lần đọc xác nhận trước khi vào máy chủ B. Mỗi ca in `PASS persistence` hoặc `FAIL persistence` kèm giá trị sai. Lỗi hiện có ở mã game vẫn được tính FAIL. Toàn bộ giao dịch và máy chủ trong các ca này chạy trong mô phỏng.
## Suite bảo vệ các mục V3 đã đạt theo mã

Chạy `powershell -ExecutionPolicy Bypass -File tools/test_v3_regression.ps1` (Luau CLI).
Suite riêng thực thi nguồn production không sửa: Trident/Bounty, bốn đường bán Gold,
Appraise, công thức Trident, Titan, TrophyHelper + Rebirth server, trao Strength.
Các biên Roblox/DataService/Net được giả lập; không có API request thật.
Xem `docs/V3_REGRESSION_MATRIX.md` để phân biệt 23 ca VM với 21 ID kiểm toán và ca Studio chờ.

Đối chứng âm tùy chọn: thêm `-ProbeMutation AppraiseFloor`, `StrengthTwice`,
`TridentTrophy` hoặc `RebirthCap`. Mỗi lệnh phải **exit 1** vì assertion tương ứng;
chỉ chuỗi nhúng trong build runner bị thay, không sửa nguồn game.
Sau đó chạy không probe phải **exit 0**. Không đưa probe âm vào lệnh CI bắt buộc.

## Hồi quy Đợt 2 (logic thật, biên Engine giả)
Chạy `powershell -ExecutionPolicy Bypass -File tools\test_fishing_wave.ps1`.
Bốn bộ thử kiểm cân thường/Titan, biên Perfect server, MinigameBar Mount/nút/chuột trước-sau hạn và ack trễ;
phạm vi prompt 3D/override và vùng hàng lưới; tia đầu tiên/Auto; SessionManager 1–3 vòng với gói trễ 200ms,
đóng một lần và cooldown; FishingController bật lại Auto trong hồi, gói trùng, hủy/cất cần/chết.
Các phép thử này không thay nghiệm thu Studio, điện thoại, số kết nối/thẻ thực tế hoặc hai client.

## Hồi quy Đợt 3 (không truy cập kho Roblox)

Chạy cùng `tools/luau.exe` như trên:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_paid_random_policy.ps1
powershell -ExecutionPolicy Bypass -File tools\test_paid_random_transactions.ps1
powershell -ExecutionPolicy Bypass -File tools\test_live_odds.ps1
powershell -ExecutionPolicy Bypass -File tools\test_catch_control.ps1
powershell -ExecutionPolicy Bypass -File tools\test_camera_focus.ps1
powershell -ExecutionPolicy Bypass -File tools\test_particle_budget.ps1
powershell -ExecutionPolicy Bypass -File tools\test_animation_pose.ps1
```

Các runner tự tạo `build/`, nhúng nguồn thật, giả lập các biên Engine rồi trả exit khác 0 nếu lỗi. Policy transactions chạy nguyên hàm tải policy và handler HatchEgg/RollEnchant; biên tiền, vị trí, cấp pet và roll được giả lập. Live odds tải cấu hình, OddsCalculator, FishingRoller, BuffAggregator, provider pet và vật phẩm thật; 19.200 rổ gồm năm đảo, cần thường/Exclusive, phù phép, mồi, thuốc, pet Tiki, mọi sự kiện, bốn chế độ và hai loại nước. Bộ này đối chiếu callback trọng số đi qua RollFishSpecies, tổng rổ, loài bị loại, Swift/Midas, trứng và biên Shiny của RollMutation. Thời gian, quyền gamepass và chọn số ngẫu nhiên là biên điều khiển.

Pose dùng đại số CFrame giản lược để kiểm vòng đời và thứ tự cập nhật, không kiểm hướng khớp hay hình học trên Engine. Camera/particle cũng là mô phỏng. Nghiệm thu hai client R6/R15, hai thứ tự đóng thoại, đa cảm ứng, ảnh/video và frame time median/p95 trên điện thoại vẫn cần chạy riêng; PASS không thay các ca đó.


## Kiểm giao thoa các nhánh

`powershell -ExecutionPolicy Bypass -File tools/test_combined_integration.ps1` nạp nguyên
FishingCastState/FishingController/CameraFocusController và OddsCalculator/FishingRoller.
Kiểm Auto qua đổi đảo/Rebirth/hồi sinh, hủy tay trong cửa sổ chờ, đồng hồ server,
trùng gói đóng/reset, thoại chồng minigame và trọng số roll bằng xác suất UI.
Biên UI widget/tween/nhân vật/mạng được giả lập; Engine/mobile vẫn chờ nghiệm thu.
Bổ sung review HUD: `test_live_odds.ps1` còn chạy controller bảng thật với UI giả lập để kiểm tài khoản có cả hai pass mở xem, đổi cast/buff và đóng không phát prompt mua. Nó cũng đăng ký handler EquipPet thật và kiểm slot 2→4, từ chối con thứ 3/5 mà không thay pet cũ. Không thay phép thử bấm/chạm trên Engine.
