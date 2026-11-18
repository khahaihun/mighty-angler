# Kiểm hồi quy dữ liệu

Chạy từ gốc dự án:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
```

Cần `tools/luau.exe`. Ca này dùng **Luau CLI 0.747** từ [bản phát hành chính thức](https://github.com/luau-lang/luau/releases/tag/0.747), gói `luau-windows.zip`. Chỉ giải nén `luau.exe` vào `tools/`; không cài hệ thống. SHA-256 của executable đã dùng: `FF0ACF7D2DF9D38E30C85EE9FE698EFD756A920496C84EA848B74D0E2082E958`. Binary được Git bỏ qua theo quy tắc có sẵn. Có thể truyền đường dẫn CLI bằng `-LuauExe`.

Lệnh trên chạy cả ba bộ `studio_data_isolation`, `session_acquisition` và `data_persistence`. Các bộ còn lại vẫn chạy nếu một bộ lỗi. Cuối cùng lệnh trả mã lỗi nếu bất kỳ bộ nào FAIL.

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

Chưa nghiệm thu Studio/hai máy chủ Roblox thật. Chưa kiểm hoàn chỉnh hạn quyền ghi, gia hạn, gộp đóng/lưu cuối của mục 1.2, dữ liệu hỏng của 1.3, Reset 1.4 hoặc HUD 1.5. Không dùng kết quả bộ này để ký các mục đó.

## Lưu hồ sơ và giao dịch đổi cá

`data_persistence.luau` dùng lại kho RAM và lịch coroutine của `session_fixture.luau`. Bảy ca kiểm hai phiên tranh khóa, thử lại lưu cuối khi lỗi tạm, phản hồi lưu muộn, hai đường đóng đồng thời, hồ sơ sai kiểu, nút Reset DEV trong lúc autosave và nộp lại cùng UID cá trước/sau đổi máy chủ.

Ca Reset đi qua handler DEV và lịch autosave thật. Ca đổi cá đi qua handler Bounty thật, dùng cấu hình đảo/hợp đồng và kiểm Gems, Relic, thuốc, túi cùng ô ghim. Mỗi ca in `PASS persistence` hoặc `FAIL persistence` kèm giá trị sai. Lỗi hiện có ở mã game vẫn được tính FAIL. Toàn bộ giao dịch và máy chủ trong các ca này chạy trong mô phỏng.

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
