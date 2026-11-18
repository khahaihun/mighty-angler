# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 17:49 bởi Codex (thi công)
- **Trạng thái hiện tại:** Kỹ sư trưởng đã duyệt code `45dd21a` và giao mục **1.1 — Codex P0-01/P1-01**. Bản vá 1.1 đã qua **19/19 ca mô phỏng**, test cách ly Studio và **PASS 6/6, exit 0**; đang chờ review commit riêng. **Chưa làm mục 1.2, chưa duyệt phát hành; Studio/hai server thật chờ nghiệm thu.** [Kế hoạch V3](docs/superpowers/plans/2026-11-18-action-blueprint-v3.md) · [Biên bản V3](docs/CODEX_CODE_AUDIT_V3.md)

## Bản vá mục 1.1 — Xác nhận quyền ghi và nhả phiên rời lúc tải

### Đã hoàn thành [x]

- [x] Nhận chỉ đạo tiếp tục trên `codex/studio-data-isolation`, nền `45dd21a`, cây làm việc sạch lúc nhận ca; đọc lại AGENTS/PROGRESS/blueprint và DataService/LockHelper. Trong lúc thi công phát hiện tài liệu AGENTS/PLAN và `docs/SPEC_CODE_MATRIX.md` được ca khác sửa/tạo; đã đọc phần quy định mới, giữ nguyên và không đưa các thay đổi đó vào commit của mục 1.1.
- [x] **Codex P0-01 — lỗi trước vá, đọc mã + mô phỏng:** ngoại lệ tạo nonce trong callback hàng chờ bị `WithUserLock` bắt/cảnh báo nhưng `lockFailed` vẫn false; hồ sơ mặc định được cấp quyền ghi mà chưa xác nhận claim. Ngoài ra, kiểm giao dịch trong lúc tải có thể đặt cờ chỉ đọc rồi không gỡ dù claim sau đó thành công. Nay khóa mặc định từ đầu tải, chặn khi chưa có hồ sơ, chỉ mở lại khi claim xác nhận đúng token/nonce hoặc ở chế độ RAM-only hiện có; không cấp token và thời điểm xác nhận cho phiên chưa xác nhận claim.
- [x] **Codex P1-01 — lỗi trước vá, đọc mã + mô phỏng:** nhả khóa chỉ gọi một lần và bỏ kết quả; lỗi tạm để token cũ nằm lại tới TTL. `ReleaseToken` nay trả `Released`, `NotOwner` hoặc `TransientError`, thử tối đa **3 lần**, nghỉ **0,5 giây** giữa lần lỗi, kiểm giá trị trả về và cảnh báo khóa hồ sơ/token nếu hết lượt chưa xác nhận. Callback chỉ sửa tài liệu có đúng token; gặp chủ khác thì hủy cập nhật.
- [x] **Hai tình huống từ review sớm:** (1) claim đã ghi nhưng mất phản hồi, A rời lúc chờ thử lại; nay DataService nhả đúng token lượt vào ngay cả khi chưa nhận xác nhận claim. Việc dọn token rời lúc tải được tập trung tại DataService và chạy qua hàng chờ UserId, không dọn lặp ở Helper. (2) nhả hồ sơ bị cách ly có thể yield; nay kiểm lại người chơi/cờ đóng sau bước đó trước khi cài hồ sơ vào RAM hoặc phát callback.
- [x] **Ca biên từ review tiếp:** A vẫn online sau cả 3 claim đã ghi nhưng mất phản hồi, tải kết thúc chỉ đọc rồi A rời. Đã tái hiện token A còn giữ kho và sửa bằng kết quả thứ ba `claimMayBeOwned` của Helper: DataService dọn đúng token chưa chắc chắn ngay trong hàng chờ trước khi kết thúc tải thất bại, không đợi PlayerRemoving. Kết quả từ chối đã biết/chưa từng gửi claim không phát sinh yêu cầu nhả. Lỗi tạo nonce sau một claim chưa chắc chắn cũng giữ thông tin cần dọn thay vì để ngoại lệ làm mất dấu token. Không thay lịch gia hạn/lưu cuối của 1.2.
- [x] **File thay đổi của mục này:** `src/server/Services/DataService.luau`, `src/server/Services/DataStoreLockHelper.luau`, `tools/test_session_acquisition.ps1`, `tests/session_fixture.luau`, `tests/session_acquisition.luau`, `tests/README.md`, `PROGRESS.md`.
- [x] **RED → GREEN:** nền trước sửa có 4/8 ca lỗi (mở quyền sau ngoại lệ, không mở lại sau pending, không retry nhả, không báo hết lượt). Sau sửa đầu tiên 8/8 đạt; bổ sung đối chiếu token/nonce/quyền chủ và trạng thái nhả đạt 13/13. Hai lỗi review sớm tái hiện trong `logs/session-acquisition-review-red.log`, sửa đạt 16/16. Ca rời sau tải thất bại và nonce lỗi sau claim chưa chắc chắn tái hiện trong `logs/session-acquisition-rejoin-red.log`, sửa và bổ sung kiểm ngoại lệ hàng chờ đạt **19/19, exit 0**. Test API lỗi liên tục nay đếm riêng tối đa 3 lần nhận và 3 lần dọn token chưa chắc chắn; không nới trần mỗi thao tác. Không còn lỗi chưa giải quyết vượt giới hạn hai vòng.

| Ca | Bằng chứng | Kết quả thực tế |
|---|---|---|
| Ngoại lệ nonce trong hàng chờ nhận khóa | Mô phỏng đường thật DataService/LockHelper | Cảnh báo được ghi, giao dịch khóa, `CanWritePersistent=false`, `SaveProfile=Skipped`; lượt vào tiếp cùng UserId vẫn tải được. |
| Đang chờ claim và hồ sơ xác nhận hợp lệ | Mô phỏng | Đang chờ không có quyền ghi; khi xác nhận mở đúng quyền, lưu Gold 321 và `saveSeq=2`. |
| Lỗi API nhận khóa / phản hồi sai token / sai nonce | Mô phỏng | Nhận khóa dừng sau 3 lượt; hồ sơ giữ chỉ đọc, không lưu đè. |
| A đang giữ khóa, B xin cùng hồ sơ | Hai máy chủ độc lập mô phỏng, chung kho RAM | A còn quyền và lưu Gold 999; B bị chặn, không đổi token A. |
| Hai lượt vào cùng UserId trong một máy chủ, A rời lúc tải | Mô phỏng | B chờ hàng đợi; lần nhả đầu lỗi, lần hai thành công rồi B nhận token khác và lưu Gold 456. |
| Nhả A chậm trước commit hoặc sau commit/đang chờ phản hồi | Hai máy chủ mô phỏng | Sau B nhận khóa và lưu, nhả muộn giữ nguyên token B, `saveSeq=2`, Gold 789; không có commit ghi đè B. Ca trước commit kiểm callback chạy lại trên phiên B. |
| Nhả hết lỗi tạm / đã nhả nhưng mất phản hồi | Mô phỏng | Hết 3 lần trả `TransientError` và cảnh báo có key/token; nếu đã ghi nhưng mất phản hồi, retry xác nhận `NotOwner`, không ghi lần hai. |
| Claim đã ghi nhưng mất phản hồi rồi A rời | Mô phỏng, hai nhánh có/không chủ B | Dọn đúng token A thay vì đợi TTL; nếu B đã giữ khóa, vẫn gọi kiểm token và hủy ghi, giữ token/seq/Gold 975 của B. |
| A còn online khi cả 3 claim mất phản hồi, sau đó rời/vào ngay | Mô phỏng | Giữ chỉ đọc, dọn token trước khi kết thúc tải thất bại (3 claim + 1 nhả); lượt vào lại có quyền ghi và lưu Gold 642 mà không đợi TTL. |
| Ngoại lệ trước gửi claim / ngoại lệ nonce sau claim chưa chắc chắn | Mô phỏng | Chưa gửi claim: 0 yêu cầu kho/nhả, hàng chờ dùng lại được. Đã có claim chưa chắc chắn: chỉ đọc và dọn đúng token (1 claim + 1 nhả). Chủ khác đã được xác định: 3 lần xin khóa, 0 lần nhả thừa. |
| Rời trong lúc retry nhả hồ sơ bị cách ly | Mô phỏng DataService + ProfileMigrator thật | Nhả lần hai thành công; người đã rời không được cài lại vào `profiles`, callback tải xong phát 0 lần. |
| Studio chưa publish | Mô phỏng | RAM vẫn chơi/lưu RAM theo chế độ cũ, mở kho 0 lần, gọi DataStore 0 lần. |
| Studio/hai server Roblox thật | Chưa chạy | **Chờ nghiệm thu**; không bật API sản xuất và không ghi dữ liệu thật. |

**Lệnh tái chạy và kết quả cuối:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_session_acquisition.ps1
# SESSION_SUITE passed=19 failed=0; exit 0
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# PASS; exit 0; Studio yêu cầu tên kho sản xuất = 0
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# PASS 6/6; exit 0 — chỉ là bộ kiểm định tự động
```

- [x] Log cục bộ: `logs/session-acquisition-red.log`, `logs/session-acquisition-review-red.log`, `logs/session-acquisition.log`, `logs/studio-data-isolation.log`, `logs/app.log`. Lần verify đầu phát hiện cách gán biểu thức `number?` vào map thời điểm; sửa một lần thành nhánh `if confirmedLock`, lần verify sau và lần cuối đều đạt. Log lỗi kiểu được giữ ở `logs/session-acquisition-verify-first.log`.
- [x] Đếm độc lập: **88/88** file mã game ≤350; lớn nhất CurrencyService **342**. DataService **327**, DataStoreLockHelper **182**. HudPanel **268**, PetsService **298**, ProgressPanel **268**, BagPanel **307**, FishingService **282**, đều <310. `git diff --check` đạt.
- [x] Build `build/mighty-angler-dev.rbxlx` đối chiếu Source hai module dữ liệu **2/2 khớp**. SHA-256: **`4E4494E36988A6A453A8942D3E0DF732A22858AD63652FA3F18D1D9EB53AF25A`**. Chưa Play bản này trong Studio.

### Đang làm dở [~]

- [~] Chờ Kỹ sư trưởng review commit riêng chứa mục bàn giao này (`git log` trên nhánh hiện tại); chưa coi hai mã V3 đã được nghiệm thu Engine.

### Bước tiếp theo [ ]

- [ ] Nghiệm thu các ca trên trong Studio và hai server Roblox trên experience thử/kho thử theo blueprint; ghi đủ trace và kiểm không yêu cầu kho sản xuất.
- [ ] Dừng tại đây để review. **Chưa chuyển sang 1.2**: thời hạn quyền ghi từ dấu giờ kho, gia hạn rải nhịp, gộp hai đường đóng và bảo đảm lần lưu cuối vẫn chờ bản vá sau.

### Quyết định kỹ thuật & Lưu ý cho AI ca sau

- Bộ mới chạy nguồn thật DataService/Helper/Migrator, không mock `Get`, `CanWritePersistent`, `IsTransactionLocked` hoặc logic khóa. Chỉ giả lập biên Engine (dịch vụ, tín hiệu, đồng hồ, Instance leaderstats, kho RAM); hai server có bộ module/hàng chờ độc lập. Không suy ra đây là kết quả mạng/Roblox Engine thật.
- Giữ `_StudioDev` và chế độ RAM-only của `45dd21a`; không sửa LiveOps ở mục này. Không đổi quy tắc gia hạn/lưu cuối, schema, Reset hay HUD. Cảnh báo `Release unconfirmed` có nghĩa chưa chứng minh nhả xong sau 3 lần, không được báo thành công; token khi đó vẫn phải chờ hết hạn hoặc một lần dọn có xác nhận sau này.

## Bản vá mở đầu Đợt 1 — Cách ly dữ liệu Studio (2026-11-18)

### Đã hoàn thành [x]

- [x] Nhận ca ở `51c020c`, `git status --short` và `git diff` rỗng, đọc 5 commit gần nhất cùng AGENTS/PROGRESS/V3/blueprint và phần dữ liệu của PLAN. Không có commit mới hơn hoặc thay đổi người dùng cần giữ lại. Thi công tại đường dẫn được giao, trên nhánh cục bộ `codex/studio-data-isolation`.
- [x] **Lỗi gốc — đọc mã + tái hiện bằng mô phỏng:** `DataStoreLockHelper.TryGetStore()` đã tách `MightyAngler_Profile_v2_StudioDev`; `LiveOpsService.refreshLeaderboards()` chỉ kiểm `PlaceId > 0`, mở `MightyAngler_TopStr_v2` và `MightyAngler_TopGold_v2` ngay cả khi Studio đang chạy place đã publish. Điểm DEV có thể thành kỷ lục bền ở kho thật nếu API được bật. Đây là phát hiện bổ sung về kho điểm trong V3, bảo vệ hai mục đã đạt **Codex P1-02 / Argon P0-1**; chưa đóng các mã khóa phiên/lưu cuối của Đợt 1.
- [x] **Bản vá:** `src/server/Services/LiveOpsService.luau` thêm `RunService:IsStudio()` khi mở cả hai OrderedDataStore: Studio dùng hậu tố `_StudioDev`, máy chủ thật giữ tên cũ. Giữ nguyên `PlaceId > 0`, điều kiện `DataService.CanWritePersistent`, bỏ điểm 0 và `UpdateAsync` lấy `math.max`. `DataStoreLockHelper` không cần sửa vì đường hồ sơ đã chọn đúng kho và đã được thực thi trong phép thử.
- [x] **Phép thử mới:** `tools/test_studio_data_isolation.ps1`, `tests/studio_data_isolation.luau`, `tests/README.md`. Chạy nguyên văn 5 module nguồn trong Luau CLI 0.747, thay dịch vụ Roblox bằng kho RAM; spy ghi tên ngay tại lời gọi mở kho. Chạy cả refresh đầu tiên và refresh định kỳ. Không gọi Roblox API, không bật API Services, không ghi dữ liệu sản xuất. Binary Luau và runner sinh ra chỉ nằm trong `tools/` và `build/` đã được Git bỏ qua.
- [x] **RED → GREEN:** trước bản vá, lệnh mô phỏng exit **1**, lỗi `expected MightyAngler_TopStr_v2_StudioDev, got MightyAngler_TopStr_v2`; trace cũng ghi Gold dùng tên sản xuất. Sau một vòng sửa, lệnh dưới exit **0**, toàn bộ ca mô phỏng đạt. Không có lỗi tồn đọng sau hai vòng sửa.

| Ca | Loại bằng chứng | Kết quả thực tế |
|---|---|---|
| Studio, `PlaceId = 0` | Chạy mô phỏng | 0 lời gọi mở kho, 0 ghi bền; hồ sơ báo RAM-Only Fallback. |
| Studio, `PlaceId = 123456` (đã publish) | Chạy mô phỏng | Cả hồ sơ, Top Strength, Top Gold dùng `_StudioDev`; **0 yêu cầu tên kho sản xuất**, kể cả refresh định kỳ và các ca kỷ lục. |
| Máy chủ thật, `IsStudio = false`, `PlaceId = 123456` | Chạy mô phỏng, kho RAM | Mở đúng 3 tên sản xuất cũ. Trace routing có 5 lời gọi (1 hồ sơ + 2 bảng × 2 refresh); không có kết nối dữ liệu thật. |
| Lỗi API khi mở lần lượt hồ sơ/Strength/Gold Studio | Chạy mô phỏng | Vẫn chỉ yêu cầu kho `_StudioDev`, không thử chuyển sang tên sản xuất. |
| Hồ sơ chỉ đọc hoặc chưa tải | Chạy mô phỏng đầu vào quyền ghi của LiveOps | Không cập nhật điểm của các hồ sơ này. `DataService.Get/CanWritePersistent` là đầu vào điều khiển; chưa kiểm tính đúng của khóa phiên. |
| Kỷ lục hai bảng | Chạy mô phỏng | 125,9/250,8 → 125/250; gửi 5/10 vẫn giữ 125/250; gửi 400/800 nâng đúng; điểm 0 không tạo lượt UpdateAsync. |
| Studio thật: place cục bộ và place đã publish, API tắt/bật trên kho thử | Chưa chạy trong Studio | **Chờ nghiệm thu**: ca này không có phiên Studio kết nối để thực thi/ghi bằng chứng Engine. Không bật API sản xuất để thử. |

**Lệnh và kiểm định thực tế:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# exit 0; trace ở logs/studio-data-isolation.log của ca thi công
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# exit 0; PASS 6/6; logs/app.log; build/mighty-angler-dev.rbxlx
```

- [x] Bộ verify cũng đã đạt trên nền trước sửa. Lần kiểm sau sửa đạt 6/6 (dòng/API/sourcemap/Luau-LSP/Selene/build). **PASS 6/6 chỉ xác nhận bộ kiểm định tự động**, không phải ký nghiệm thu Studio hay phát hành.
- [x] Đếm độc lập bằng `[IO.File]::ReadAllLines`: **88/88** file mã game ≤ 350, lớn nhất `CurrencyService` **342**. `HudPanel` **268**, `PetsService` **298**, `ProgressPanel` **268**, `BagPanel` **307**, `FishingService` **282**, đều < 310; `LiveOpsService` **259**. `git diff --check` đạt.
- [x] Đọc XML bản build, đối chiếu nguyên văn `Source` của `LiveOpsService` với file nguồn: **1/1 khớp** sau chuẩn hóa xuống dòng. Place: `build/mighty-angler-dev.rbxlx`, SHA-256 **`4F186A6D7D2DFA82971B270EDD1FE712CC98BD5C673C5B34736EEED9AEA99874`**. Đây là bản build tự động, chưa được mở Play trong Studio ở ca này.

### Đang làm dở [~]

- [~] Bản vá đang chờ Kỹ sư trưởng ở chat riêng review diff/commit và quyết định nghiệm thu. Commit của bản vá là commit chứa mục bàn giao này; tra bằng `git log -n 1 --oneline` trên nhánh trên.

### Bước tiếp theo [ ]

- [ ] Nghiệm thu hai chế độ Studio thật trên đúng bản build, ghi trace mở kho với số yêu cầu tên sản xuất bằng 0; kiểm API bị chặn trên kho thử. Không tự bật API sản xuất.
- [ ] Sau khi Kỹ sư trưởng duyệt, mới tiếp tục khóa phiên và lưu cuối theo 1.1/1.2. Hai server trực tuyến trong experience thử riêng còn **chờ nghiệm thu**; chưa cấu hình hay chạy các server đó ở bản vá này.

### Quyết định kỹ thuật & Lưu ý cho AI ca sau

- Giới hạn ca này ở phần mở đầu Đợt 1 theo yêu cầu trực tiếp; không thực hiện toàn bộ blueprint, không thay session lock/Reset/migration và không gọi Gemini. Quyền review/phát hành thuộc Kỹ sư trưởng, khác vai trò thi công của Codex ở ca này.
- Giữ quy tắc đặt tên `_StudioDev` hiện có, không đổi kiến trúc kho dữ liệu. Việc cách ly này chỉ dựa vào Studio; server trực tuyến cần experience thử riêng theo blueprint trước khi thử ghi. Không suy diễn rằng bản vá đã cách ly một server thử chạy trong experience sản xuất.
- Phép thử là VM Luau với biên Roblox giả lập, không phải Play trong Studio; không dùng kết quả này để ký các lỗi khóa phiên hoặc lưu cuối. Giữ các phần bàn giao cũ bên dưới làm lịch sử; trạng thái mới nhất là mục đầu file này.

## Bàn giao chỉ đạo thi công sau V3

- [x] Đối chiếu mốc bổ nhiệm `76916a6` với mã game đã kiểm toán ở `8227545`. Ban hành bảng giao việc cho 6 mã Argon và 17 mã Codex, kèm phép thử và người ký. Tài liệu của ca gồm kế hoạch chỉ đạo V3 và `PROGRESS.md`.
- [x] Chốt tách kho hồ sơ và cả hai bảng điểm trước khi thử ghi. Với cân nặng, giao khôi phục cách tính trước hotfix cho lượt không có Titan Line và giữ trần theo `PLAN.md` cho lượt có Titan.
- [x] Đối chiếu bằng danh sách mã trong biên bản V3, đủ 23/23 mã và mỗi mã có một đầu việc chính. Kiểm các liên kết bàn giao. Chạy lại `tools/verify_project.ps1` trên bản sao của nguồn và cấu hình hiện tại, **PASS 6/6, exit 0**. Đếm độc lập 88 file mã game, dài nhất 342 dòng, cả năm file cam kết đều < 310 dòng.
- [ ] Antigravity bắt đầu Đợt 1 (7 mã) với kho thử riêng. Nộp kết quả hai server và bằng chứng vào lại đúng tiến độ sau Bounty. Đợt 2 (10 mã) kiểm vòng câu và Index. Đợt 3 (6 mã) kiểm quyền mua, xác suất và hiển thị.
- [ ] Chờ kết quả chạy thực tế của bản vá trong Studio, trên hai server và trên điện thoại. Codex duyệt từng đợt và ký đúng bản place có đủ bằng chứng.

## Bàn giao tái kiểm toán V3

- [x] Chạy độc lập `tools/verify_project.ps1` đạt 6/6. Đếm 88/88 file nguồn ≤ 350 dòng, năm file cam kết đều < 310. Đối chiếu 88/88 script trong place đã build với nội dung `src/`.
- [x] Đối chiếu đủ 18 mục Argon và 26 mục Codex với mã tại `8227545`, ghi kết quả và bằng chứng vào `docs/CODEX_CODE_AUDIT_V3.md`. Hai tài liệu của ca này là biên bản V3 và `PROGRESS.md`.
- [ ] Ưu tiên bảo vệ lần lưu cuối, thống nhất thời hạn khóa và cách ly hồ sơ sai kiểu. Kiểm tiếp Auto bị kẹt, Index của người mới, xác suất hiển thị và quyền lợi gói Pet theo danh sách V3.
- [ ] Sau bản sửa, thử hai server trên kho dữ liệu riêng, rồi kiểm Roblox Studio với hai client, ping 200 ms và thiết bị cảm ứng. Kết quả chạy thực tế các trường hợp này còn chờ nghiệm thu.

## Bàn giao Hotfix Vòng Cuối (Xử lý 100% Audit Codex + Argon) [x]

- [x] **Nhóm P0 — Toàn vẹn dữ liệu DataStore, Bảo vệ Trophy, PolicyService & Chống Exploit Tọa độ:**
  - `DataStoreLockHelper.luau` + `DataService.luau` (`Codex P0-01, P0-02, P1-01, P1-04, P2-06` + `Argon P0-3`): Hàng chờ tuần tự theo `UserId` (`WithUserLock`), mã phiên độc nhất từng lượt vào (`SERVER_JOB_ID .. "_" .. uid`), đối chiếu `lastWriteNonce` từ giá trị trả về của `UpdateAsync` (tuyệt đối không gán cờ ngoài trong callback), kiểm tra chặt `type(oldData) == "table" and oldData.activeSessionId == myToken and saveSeq <= expectedSeq`, tự động nhả khóa nếu người chơi thoát giữa lúc tải, chuyển sang `readOnlyPlayers` ngay khi `LostLock` hoặc quá hạn khóa, khóa giao dịch trước `BindToClose` song song (có gộp chung `closingPlayers` với `PlayerRemoving` + retry lỗi tạm), gửi bù `PushFullSnapshot` khi tải trễ `> 8s` (`clientRequestedInit`), giữ nguyên `saveSeq` khi `[DEV] Reset Save` và tách kho `_StudioDev` khi test Studio.
  - `LiveOpsService.luau` (`Codex P1-02` + `Argon P0-1`): Chặn tuyệt đối ghi điểm lên `OrderedDataStore` khi `!DataService.CanWritePersistent(p)`, đồng thời dùng `UpdateAsync` với `math.max` để không bao giờ ghi đè `0` điểm lên kỷ lục Bảng Xếp Hạng Toàn Cầu.
  - `PerkService.luau` + `PetsService.luau` (`Codex P1-13` + `Argon P0-2`): Chuyển `PolicyService` sang 3 trạng thái fail-closed (`"Loading" | "Allowed" | "Restricted"`), chặn quay ngẫu nhiên trả phí cả khi đang tải lẫn khi bị hạn chế ở **cả 2 luồng** `RollEnchant` (Gems) và `HatchEgg` (Trứng Gems), phản ánh rõ trạng thái lên nút UI.
  - `EnchantAndBountyService.luau` + `EnchantAndBountyModal.luau` (`Codex P0-03, P1-06` + `Argon P1-3, P1-7`): Bắt buộc chọn đích danh `bossFishUid` khi đổi `RelicTrident` và từ chối tuyệt đối cá `locked` hoặc `soulbound`; kiểm tra khoảng cách thực tế (`<= 28` studs) tới đúng tọa độ NPC *Old Man Finn*, *Master Kaito* hoặc Bệ *Enchant Altar*; bảng Bounty ưu tiên cá thường mở khóa giá thấp nhất trước, có nút xoay chọn từng `uid` và cảnh báo cam `⚠️ CONSUMES TROPHY`.
  - `FishingRoller.luau` + `FishingService.luau` + `WorldBuilder.luau` (`Codex P1-08, P1-09` + `Argon P0-4, P1-4`): Đặt `CanQuery = false` cho 3 tường vô hình `OceanBoundS/W/E`; kiểm tra `IsFiniteVector3` + cự ly hợp lệ khi nảy đất; Raycast 3D đường quăng + tia thẳng đứng trên Server chặn xuyên mặt cầu gỗ; bỏ hoàn toàn tự động `PivotTo` dịch chuyển nhân vật khi quăng hụt; xác thực thời gian giữ chuột (`FishingChargeStart` >= `0.55s`) và hồi chiêu quăng lại phía Server (`nextAllowedAutoCastAt` + `autoFishActive`).

- [x] **Nhóm P1 & P2 — Minh bạch Xác suất, Virtualized `ViewportPool`, R15 NPC/Rig, `Appraise` & Polish:**
  - `ProfileMigrator.luau` (`Codex P1-03`): Kiểm tra cấu trúc dữ liệu & cách ly an toàn bản lưu hỏng hoặc `dataVersion > 2` (nhả khóa mà không ghi đè), tách riêng hàm sang ngày UTC `RefreshUtcPlaytimeIfNewDay`.
  - `TrophyHelper.luau` + `ProgressPanel.luau` + `CurrencyService.luau` (`Codex P1-05` + `Argon P2-1`): Dùng chung một thuật toán chọn 12 cá `Soulbound Trophy` (`soulbound` ưu tiên trước -> `originalValue DESC -> weight DESC -> uid ASC`) cho cả Server và UI Rebirth, khóa cứng cá `soulbound` không bị bỏ khóa nhầm, khung xem trước `AutomaticSize.Y` kèm dòng cảnh báo rõ các cá khóa vượt mốc 12 sẽ bị xóa.
  - `EnchantAndBountyService.luau` + `ClientStateController.luau` + `FishingRoller.luau` + `RodsConfig.luau` (`Argon P1-2, P2-2` + `Codex P1-07, P2-01, P2-02, P2-03`): Giữ nguyên không bao giờ hạ bậc `sizeTier` khi `Appraise`, tính sàn `85%` làm tròn lên (`math.ceil`), đồng bộ ngay `indexFish` qua `AppraiseResult`; kẹp đúng trần cân `effMaxWeight * 1.25` làm tròn xuống `0.1 kg` cho `titan_line`; công thức `RelicTrident` trên nền `Twig` ra đúng `17 kg`; chụp cứng `strengthMult` tại thời điểm quăng cần.
  - `FishingSessionManager.luau` + `MinigameBar.luau` + `FishingController.luau` (`Codex P1-10, P1-11` + `Argon P1-5`): Kẹp tâm vạch xanh `[0.30, 0.82]`, khớp hằng số `PLAN.md` (`0.08s / 0.45s` & biên `0.05`), kiểm hạn tuyệt đối `serverDeadlineClock` ngay trong `HandleStrike`, Client chờ xác nhận vòng/kết quả từ Server thay vì tự đóng sớm, ẩn nút `✖ REEL IN` khi đang mở Minigame, và tự động tiếp nối nhịp `Auto-Fish` sau khi Đổi đảo / Rebirth / Hồi sinh (tắt sạch khi cất cần hoặc bấm hủy tay).
  - `OddsCalculator.luau` + `HudPanel.luau` + `ShopPanel.luau` + `PetsPanel.luau` + `PromptController.luau` (`Codex P1-12` + `Argon P1-6`): Hiển thị trực tiếp dòng `Base % → Live %` (Rare+, Boss, Xoáy nước `2x`, Đột biến & độ rộng thanh Bar `Rare 28% / Boss 22%`) trên HUD; hiển thị `Base % → Effective %` sau khi loại dòng đang có trên Bệ Enchant; hiển thị đầy đủ tên/bậc/chỉ số/`%` từng Pet trên `PetsPanel` và mở bảng xem trước khi bấm `[E]` ở trụ Trứng ngoài đảo; hộp xem trước đầy đủ 5 chỉ số Cần & `Before vs After` cho cả 5 Gamepass trong `ShopPanel`.
  - `ViewportPool.luau` + `IndexGridSection.luau` (`Codex P1-14` + `Argon P1-1`): Giữ cố định khung `PersistentIndexContainer` xuyên suốt các lần `ProgressionUpdated` và bổ sung **Scroll-Window Virtualization (`+1` hàng đệm)** vào `ViewportPool` để các túi lớn (60 cá, 80 pet, 65 mục Index) luôn chỉ dựng các ô nằm trong khung nhìn.
  - `NpcBuilder.luau` + `WhirlpoolManager.luau` + `ClientPetRenderer.luau` + `PlayerVisuals.luau` + `AnimationController.luau` + `SoundAndFxController.luau` + `NpcDialogueModal.luau` + `HotbarAndCastController.luau` + `TutorialController.luau` (`Codex P1-15, P1-16, P1-17, P2-04, P2-05` + `Argon P1-8, P1-9, P1-10, P2-3, P2-4`): Dựng NPC bằng rig R15 chuẩn (`Humanoid + Animator + Motor6D + WeldConstraint`), bỏ hoàn toàn vòng lặp `Heartbeat` trên Server và chuyển diễn hoạt thở/vẫy tay NPC + bóng cá Whirlpool sang Client theo khoảng cách; chống rò rỉ Pet bằng `charGenByPlayer` + dịch chuyển bằng `PivotTo`; gắn ngang đòn tạ `BenchPress` vào thân & chuẩn hóa tay R6 `-0.95`; hỗ trợ cả `Motor6D`, `AnimationConstraint` và `Animator` track; theo dõi riêng đối tượng `InputObject` khi cảm ứng đa điểm; cân bằng góc `PunchCamera` về `0°`, giữ FOV Minigame khi đóng thoại NPC, tắt hạt ở xa/khi bật `Low GFX`, và cập nhật lời nhắc tân thủ + biển báo cầu cảng khớp cơ chế 2.0.

- [ ] **Chờ tái kiểm toán từ Argon (`docs/ARGON_CODE_AUDIT_V3.md`):** Sau khi Argon ghi biên bản kiểm tra lại bản vá, lịch hẹn tự động sẽ thức dậy kiểm tra và xử lý dứt điểm mọi ghi chú còn lại (nếu có).

---

## Tiến Độ Đại Tu 2.0 (Phase 2 Overhaul) [x]
- [x] **Chặng A (`A1–A3`) — Nước Biển Sóng Thật, Xoáy Nước & Dàn 4 NPC R15 Hội Thoại:**
  - `TerrainWaterBuilder.luau`: Đổ `Terrain:FillBlock` cục bộ từng đảo (không xóa địa hình chung), giữ hộp neo `FishingWater` vô hình (`CanQuery = false`), bổ sung đồi vách đa tầng, ngọn hải đăng Đảo 1, lửa trại, hàng rào dây thừng và Bệ `Enchant Altar`.
  - `WhirlpoolManager.luau`: Xoáy nước sủi bọt + cột sáng + bóng cá bơi vòng, nhân `×2` tổng Luck và `×2` trọng số rớt Boss khi quăng trúng vùng xoáy.
  - `NpcBuilder.luau` & `NpcDialogueModal.luau`: 4 NPC R15 cử động thở/vẫy tay (*Captain Barnaby*, *Master Kaito*, *Old Man Finn*, *Coach Atlas*) + hộp thoại đa lựa chọn an toàn (mở rồi đóng thoại Merchant giữ nguyên 100% túi cá).
- [x] **Chặng B (`B1–B3`) — Session Lock `v2`, Hotbar Cầm Đồ/Khoe Cá, Vật Lý Nảy Đất, 5 Chỉ Số Cần & Exclusive Rod:**
  - `DataService.luau` + `ProfileMigrator.luau`: Khóa độc quyền `activeSessionId == SERVER_JOB_ID`, gia hạn khóa mỗi `60s`, tuần tự `saveInFlight`, chặn giao dịch khi `loadFailedPlayers` + `MigrateProfileToV2` & giữ tối đa 12 `Soulbound Trophies` + Exclusive Rods qua Rebirth (hiện danh sách xem trước trên `ProgressPanel`).
  - `HotbarAndBaitUi.luau` + `HotbarAndCastController.luau` + `FishingSessionManager.luau`: Ẩn Backpack mặc định, Hotbar `1..5` rút cần / cầm cá khoe, chọn mồi nhanh góc dưới phải, nút Auto ngay trên Hotbar, nạp thanh `Cast Power` (4 chế độ Manual / Perfect / Auto Free / Auto Pro), Raycast nảy đất/cầu gỗ, dấu `❗` + Camera zoom nhẹ & chấm điểm Minigame `FishingMinigameStrike` đối chiếu đồng hồ Server (`+0.40s` ân hạn mạng).
  - `RodsConfig.luau` + `EnchantsConfig.luau` + `BountiesConfig.luau` + `EnchantAndBountyService.luau` + `EnchantAndBountyModal.luau`: 5 chỉ số Cần câu, cân bằng lại Kg 5 đảo theo cổng kép (`Power` + `Max Weight`), 3 Cần Exclusive (`115% / 122% / 130%`) & xoay 6 dòng Enchant công khai `%` + `PolicyService`.
- [x] **Chặng C (`C1–C3`) — Lưới Thẻ 3D `ViewportPool`, Khóa Cá, Bán Chọn Lọc, Appraise & Fish Bounty:**
  - `ViewportPool.luau` + `ViewportCard.luau`: Tái sử dụng ô lưới thẻ vuông 3D mượt trên mobile cho toàn bộ `BagPanel`, `ShopPanel`, `PetsPanel` và `IndexGridSection` (bóng đen Silhouette cho loài chưa mở, chỉ xoay 1 thẻ đang chọn, dừng 100% khi đóng cửa sổ).
  - `BagPanel.luau` + `CurrencyService.luau`: Hỗ trợ `🔒 Lock/Unlock`, thanh ghim nhanh Hotbar `Slot 2..5`, chế độ `☑️ Multi-Select` bán nhiều cá một lúc, `Sell Held Fish`, và bảo vệ tuyệt đối cá `Soulbound Trophy` ở cả 4 luồng bán Gold.
  - `PlaytimeAndSettingsModal.luau` + `EnchantAndBountyService.luau`: Quà Online 9 mốc cộng dồn theo ngày UTC, `Appraise` nâng bậc kích thước/đột biến (sàn cân `0.85x`), `Fish Bounty` tiêu `uid` nguyên tử và bảng `Settings` (`Auto-Lock`, `Low GFX`, `Mute SFX`).
- [x] **Chặng D (`D1–D3`) — Mô Hình 3D Chi Tiết Cao, `ClientPetRenderer`, Đập Trứng, Rank Aura & Âm Thanh:**
  - `FishModelBuilder.luau`, `PetModelBuilder.luau`, `RodAndWeightBuilder.luau`: 5 họ cá 3D giải phẫu riêng (*Sleek, Billfish, Manta, Shark, Leviathan*), 6 dòng Pet Chibi mắt long lanh má hồng, 3 Cần Exclusive phát sáng đặc trưng (*Đinh ba 3 mũi, Lưỡi hái Hư không, Đôi cánh Rồng Seraphim*) và quả tạ đôi / đòn tạ 3D.
  - `ClientPetRenderer.luau`: Chuyển toàn bộ diễn hoạt bay của Pet sang Client (`EquippedPetIds` Attribute), tự động giảm nhịp với người chơi ở xa hoặc khi bật `Low GFX`.
  - `PlayerVisuals.luau`, `RanksConfig.luau` & `EggHatchCutscene.luau`: 10 Danh hiệu Overhead Rank Title + vòng hào quang `Aura` theo mốc Strength/Rebirth, cầm tạ 3D thật trên tay khi tập Gym, và diễn hoạt Đập Trứng nứt vỏ nổ sáng có nút `SKIP`.
  - `AnimationController.luau`, `SoundConfig.luau` & `SoundAndFxController.luau`: Tư thế toàn thân (nghiêng hông lấy đà quăng cần, giật cần, giơ 2 tay bế cá khoe hàng, cuốn tạ/đẩy tạ) + nhạc nền sóng biển nhẹ nhàng & SFX nảy đất/câu cá.
  - Kỷ luật dung lượng file: Cả 5 file từng sát trần đều đã hạ xuống `< 310` dòng (`HudPanel: 260`, `ProgressPanel: 274`, `PetsService: 289`, `FishingService: 301`, `BagPanel: 307`).

---

## Hội Nghị Phản Biện & Chốt Thiết Kế Giữa Antigravity ↔ Codex [x]
- [x] **Vòng 1 (`docs/REVIEW_DAI_TU_2.0.md`):** Codex đối chiếu kế hoạch với 62 file `.luau` thật trong `src/`, chỉ ra 3 điểm nghẽn lớn (giữ câu cá xuyên suốt cả 5 đảo ngay khi thay `Terrain Water` ở A1, tương quan `Max Weight` vs `minRodPower` 5 đảo, và số phận cá khóa + Exclusive Rod khi Rebirth).
- [x] **Vòng 2 & 3 (`docs/DEBATE_ROUND_2.md`, `docs/CODEX_ROUND_2_REPLY.md`, `docs/CODEX_FINAL_VERDICT.md`):** Hai AI tranh luận và chốt hạ giải pháp cho:
  1. **P0 DataStore Session Lock:** Chỉ cho phép ghi khi `activeSessionId == SERVER_JOB_ID`, gia hạn khóa mỗi `60s`, chờ `saveInFlight` trước khi nhả khóa lúc đổi server, khóa giao dịch nếu thử 3 lần không lấy được khóa.
  2. **P1 A (`Soulbound Trophy` qua Rebirth):** Giữ tối đa 12 cá khóa xếp theo `originalValue` (không mất ở các lần Rebirth sau), chặn ở mọi luồng bán Gold ngay trước khi xóa khỏi túi, vẫn cầm khoe trên Hotbar & nộp *Fish Bounty* bình thường; màn hình Rebirth hiện rõ danh sách 12 Trophy & ô ghim.
  3. **P1 B (Minigame chống gian lận không sợ ping cao):** Chấm từng vòng `FishingMinigameStrike` bằng sóng tam giác tất định đối chiếu đồng hồ Server + tách hạn bấm (`7.5s / 9.5s / 11.5s`) khỏi hạn nhận gói (`+0.40s` ân hạn mạng).
  4. **Hiệu năng Mobile & Trần 350 dòng:** `ClientPetRenderer` diễn hoạt Pet trên Client, `ViewportPool` tái sử dụng thẻ 3D không dựng lại toàn lưới khi nhảy tiền, và tách trước 5 file đang sát trần (`331–336` dòng) xuống `< 310` dòng.
- [x] **Vòng 4 (`docs/CODEX_CONSENSUS_STAMP.md`):** Codex xác nhận **`ĐỒNG THUẬN CHỐT PLAN.md`** (0 lỗi P0/P1/P2 tồn đọng).

## Bước đã thực hiện sau hội nghị [x]
- [x] Antigravity đã triển khai **Chặng A → Chặng B → Chặng C → Chặng D**. Công việc tiếp theo được ghi ở phần bàn giao kiểm toán đầu file.

---

## Nhật ký Hotfix sau lần test Studio đầu tiên [x]
- [x] **Fix lỗi treo đơ màn hình khi bấm Câu cá / Train (`BuffAggregator ↔ PetsService` mutual recursion):**
  - *Nguyên nhân gốc:* Provider của `PetsService` gọi `sanitizeEquippedList`, hàm này lại gọi ngược `BuffAggregator.GetMultipliers(player).maxEquippedPets` gây vòng lặp đệ quy vô tận (`C stack overflow`) làm Studio đơ 1–2 giây rồi hủy luồng Server.
  - *Cách khắc phục:* Tách riêng hàm trực tiếp `BuffAggregator.GetMaxEquippedPets(player)` (không đi qua danh sách provider) + khóa chống gọi lồng `evaluatingPlayers` trong `BuffAggregator.luau`.
- [x] **Nâng cấp trải nghiệm bấm 1 chạm:**
  - Nếu đứng xa biển mà bấm **`🎣 CAST ROD`** hoặc bật **`Auto-Fish`**, nhân vật tự động dịch chuyển ra ngay mũi Cầu gỗ câu cá của đảo đang đứng và quăng cần luôn.
  - Khi bật **`Auto-Train`** mà chưa đứng trên máy tập, nhân vật tự động bước vào máy tập mạnh nhất đủ điều kiện trên đảo và tập ngay lập tức.
  - Bỏ qua gọi mạng DataStore khi mở file `.rbxlx` cục bộ chưa publish (`game.PlaceId == 0`) giúp tốc độ phản hồi tức thì `0ms`, đồng thời chuyển tiếp mọi lỗi Server lên Toast trong Studio.

## Đã hoàn thành [x]

### Giai đoạn 0 — Thiết kế & Vũ khí kiểm định tự động
- [x] Chốt `PLAN.md` cho bản Launch 5 Đảo (mở rộng nhanh cho các bản Update sau).
- [x] Trang bị cục bộ `luau-lsp 1.70.1`, `globalTypes.d.luau`, `selene 0.32.0`, `rojo 7.7.1`, `tools/install_tools.ps1` và `tools/verify_project.ps1` (6 chốt chặn tự động).

### Chặng 1 — Đảo 1 Hoàn chỉnh & Cảm giác Chơi Cốt lõi (`M1.1 → M1.6`)
- [x] **M1.1:** `Types.luau`, `Net.luau` (tập trung toàn bộ Remote + rate-limit chống spam), `Util.luau`, `AssetRegistry.luau`, `GameConfig.luau`, `RodsConfig.luau`, `Island1_SunnyShores.luau`, `Islands/init.luau`.
- [x] **M1.2:** `PartFactory.luau`, `PropsBuilder.luau`, `IslandScenery1_2.luau`, `WorldBuilder.luau` — dựng Đảo 1 *Sunny Shores* Low-Poly, cầu gỗ, bãi biển đáy nông chống rơi vực, 3 máy Gym, quầy Sell/Shop, trụ Trứng, cổng Đảo và `Lighting` tươi sáng.
- [x] **M1.3:** `GamepassesConfig.luau`, `DataService.luau` (có Studio memory fallback mượt khi chưa bật API Services), `PerkService.luau` (tách rõ `Auto-Train = Join Group` & `Auto-Fish = Gamepass`), `BuffAggregator.luau`, `CurrencyService.luau`, `ShopAndItemsService.luau`.
- [x] **M1.4:** `RodVisuals.luau` (cần câu gắn tay + dây Beam + phao nổi tránh khuất gầm cầu), `PetAndFishVisuals.luau` (cá 3D văng lên đổi màu theo đột biến), `FishingRoller.luau`, `FishingService.luau`, `AnimationController.luau` (tương thích cả R15 & R6), `MinigameBar.luau`, `FishingController.luau`.
- [x] **M1.5:** `GymService.luau` & `GymController.luau` — tập Gym bằng click chuột có Animation + tia sáng + nút `Auto-Train`.
- [x] **M1.6:** `Theme.luau`, `WindowFrame.luau`, `HudPanel.luau`, `BagPanel.luau`, `ShopPanel.luau`, `DevTestPanel.luau` + `DevTestService.luau` (bảng nút `[DEV]` chỉ hiện trong Studio), `StudioErrorReporter.luau`, `SoundConfig.luau`, `SoundAndFxController.luau`, `PromptController.luau`.

### Chặng 2 — Mở rộng 5 Đảo, Vật phẩm & Hệ thống Pet (`M2.1 → M2.4`)
- [x] **M2.1:** Hoàn thiện `Island2_CoralDepths`, `Island3_MysticSwamp`, `Island4_EmberIsle`, `Island5_CelestialDeep` (kèm cổng *COMING SOON* cuối Đảo 5), `IslandScenery3_5.luau` và `IslandService.luau`.
- [x] **M2.2:** Hoàn thiện `BaitConfig.luau` (4 gói mồi), `GymGearConfig.luau` (4 cấp đồ tập), `PotionsConfig.luau` (10 loại thuốc), `PotionAndBaitHelper.luau` và đồng bộ đếm ngược từng giây trên HUD.
- [x] **M2.3:** Hoàn thiện `PetsConfig.luau` (10 Trứng Gold/Gems, 30 loài Pet), `PetsService.luau` (ấp trứng, Boss drop 3%, trang bị 2–4 Pet bay lượn sau lưng, `Equip Best`), `PetsPanel.luau`.
- [x] **M2.4:** Cân bằng kinh tế mượt mà xuyên suốt 5 Đảo & 6 Cần câu, tách gọn `ClientStateController.luau`.

### Chặng 3 — Endgame, Sự kiện, Bảng xếp hạng & Sẵn sàng Phát hành (`M3.1 → M3.4`)
- [x] **M3.1:** `RebirthConfig.luau` + chức năng Chuyển sinh cuối Đảo 5 & Sổ sưu tập Index (35 Cá + 30 Pet, tự động thưởng `+15 Gems` mỗi loài mở mới).
- [x] **M3.2:** `AchievementsConfig.luau`, `ProgressionService.luau`, `ProgressPanel.luau` & `IslandsModal.luau` (15 mốc Thành tựu, Quà đăng nhập theo chuỗi ngày, 3 Nhiệm vụ đổi mới mỗi ngày).
- [x] **M3.3:** `EventsConfig.luau`, `LiveOpsService.luau` (5 Sự kiện toàn Server mỗi 30 phút tặng kèm Potion + 2 Bảng xếp hạng `SurfaceGui` Top Strength & Top Gold tại Đảo 1), `TutorialController.luau` (hướng dẫn 4 bước tân thủ & báo hiệu đủ tiền mở Đảo mới).
- [x] **M3.4:** Hoàn thiện hiệu ứng âm thanh, tab mua 4 gói Gamepass, bộ chắn chống spam RemoteEvent tại `Net.luau` và kiểm định tổng thể PASS 6/6.

---

## Đang làm dở [~]
- *(Không có — đã hoàn thành trọn gói M1.1 → M3.4 trong ca chạy đêm).*

## Bước tiếp theo dành cho Chủ dự án khi thức dậy [ ]
- [ ] Mở Roblox Studio → **File → Open from File...** → chọn `D:\Projects\mighty-angler\build\mighty-angler-dev.rbxlx` (hoặc chạy `run.bat`) → bấm **Play (F5)** để trải nghiệm & dùng nút **`🛠️ [DEV]`** góc phải trên màn hình test nhanh toàn bộ 5 Đảo, Boss, Pet, Rebirth và Server Event.
- [ ] Trước khi Publish chính thức lên Roblox: điền `ROBLOX_GROUP_ID` thật vào `src/shared/Config/GameConfig.luau` và 4 mã `id` Gamepass thật vào `src/shared/Config/GamepassesConfig.luau`.

## Nhánh thi công riêng Đợt 3 — Codex UI (nền 9282aa6)
- 3.1 / Codex P1-13: PerkService chỉ chấp nhận boolean false; lỗi API và Studio offline không còn tự mở quyền. Hai điểm trừ Gems (PetsService, EnchantAndBountyService) đã có kiểm policy server và giữ nguyên.
- `tools/test_paid_random_policy.ps1`: PASS 7 trạng thái pending/API lỗi/thiếu trường/string/numeric/true/false, thực thi nguyên hàm policy trích từ nguồn; chưa mô phỏng giao dịch đầy đủ.
- Verify PASS 6/6, exit 0. Suite chung: cách ly Studio PASS, session 19/19 PASS; data_persistence 3/7 (4 lỗi có sẵn ở nền 9282aa6 thuộc Đợt 1), không sửa ngoài phạm vi.
- Ca trứng Gold/Relic và giao dịch Gems trên Roblox, hai client/điện thoại: chờ nghiệm thu. Không mở kho thật.
