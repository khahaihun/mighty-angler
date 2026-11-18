# Kiểm cách ly dữ liệu Studio

Chạy từ gốc dự án:

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
```

Cần `tools/luau.exe`. Ca này dùng **Luau CLI 0.747** từ [bản phát hành chính thức](https://github.com/luau-lang/luau/releases/tag/0.747), gói `luau-windows.zip`. Chỉ giải nén `luau.exe` vào `tools/`; không cài hệ thống. SHA-256 của executable đã dùng: `FF0ACF7D2DF9D38E30C85EE9FE698EFD756A920496C84EA848B74D0E2082E958`. Binary được Git bỏ qua theo quy tắc có sẵn. Có thể truyền đường dẫn CLI bằng `-LuauExe`.

PowerShell nhúng nguyên văn nguồn `DataStoreLockHelper`, `LiveOpsService`, `GameConfig`, `Types`, `Util` vào runner trong `build/`. Luau VM thực thi các module đó với dịch vụ Roblox giả lập; không dịch lại logic sang ngôn ngữ khác. Bộ thử ghi từng lời gọi tại `GetDataStore` và `GetOrderedDataStore`, chạy refresh đầu tiên và nhịp refresh định kỳ thật của `LiveOpsService.Init()`.

Các ca gồm Studio chưa publish, Studio đã publish, máy chủ thật mô phỏng, lỗi mở lần lượt từng kho, hồ sơ chỉ đọc/chưa tải, điểm thấp hơn/cao hơn và điểm 0. Toàn bộ kho chỉ là bảng trong RAM; phép thử không gọi Roblox API hoặc mạng và không cần bật API Services.

`DataService.Get/CanWritePersistent` là đầu vào điều khiển của phép thử để kiểm **LiveOps có tuân thủ quyền ghi hay không**. Bộ thử chưa xác nhận tính đúng của khóa phiên, tải/lưu cuối, DataStore Roblox thật, giao diện hoặc lịch chạy của Roblox Engine. Những ca đó cần nghiệm thu riêng trong Studio/máy chủ thử.

Kết quả `verify_project.ps1` là bộ kiểm định tĩnh/build riêng, không thay thế bộ mô phỏng này hoặc nghiệm thu Studio.
