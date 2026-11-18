# PROGRESS.md — Tiến độ & Bàn giao ca (Mighty Angler v2)

- **Cập nhật lần cuối:** 2026-11-18 18:55 bởi Codex (thi công)
- **Trạng thái hiện tại:** Mục 1.3 và vá slot 0 đã commit; mục **1.4** đạt 8/8 Reset, persistence 7/7. Toàn bộ bộ hồi quy và verify 6/6 đều **exit 0**. Đang tiếp ngay 1.5 theo chỉ đạo liên tục. Code 1.2 đã được chấp nhận; 1.3/1.4 chờ review. **Chưa phát hành; Studio/hai server/điện thoại chờ nghiệm thu.** [Kế hoạch V3](docs/superpowers/plans/2026-11-18-action-blueprint-v3.md) · [Biên bản V3](docs/CODEX_CODE_AUDIT_V3.md)

## Mục 1.4 — Reset cùng hàng đợi, kết quả RAM và lưu bền

- [x] Nền gồm `bbce374` và vá review `d139bbf`; tiếp tục không dừng theo giao việc. Tái hiện 6 ca Reset đỏ trước sửa (`logs/phase14-red.log`).
- [x] Persistence.Reset khóa giao dịch và chặn Reset đồng thời; trong hàng đợi UserId, xác nhận pending write trước khi đổi đối tượng, lấy seq mới nhất rồi chụp bản mặc định thành một thao tác ghi cố định. Không xác nhận được thao tác trước thì không đổi RAM. Đóng phiên trong lúc đợi thì hủy Reset, không cài lại người đã rời.
- [x] Mỗi bước xác nhận/ghi Reset thử tối đa ba lần; giữ pending thao tác chưa chắc chắn để tự lưu tiếp khi API hồi phục. RAM-only không mở kho; phản hồi Saved/RAMOnly/Unconfirmed/Busy/NotApplied tách khỏi cờ ramApplied, không báo Success nếu chỉ đổi RAM hoặc chưa xác nhận ghi.
- [x] DataService trả cả profile và trạng thái; DevTestService bỏ lần SaveProfile dư, phát kết quả riêng qua payload Toast hiện có. Bảng DEV thêm hai dòng RAM/Persistent, không tạo Remote ngoài manifest. Hình thức/bố trí thật trong Studio vẫn chờ nghiệm thu; test client kiểm handler và thuộc tính Text của module thật ở biên UI giả lập.
- [x] `dev_reset` **8/8**: autosave chờ trước thay đối tượng, lỗi ghi sau thay RAM, RAM-only, pending cũ chưa rõ thì không thay, Reset đồng thời, trạng thái bảng DEV, rời lúc chờ và mất phản hồi. `data_persistence` **7/7**, ca Reset chuyển xanh; 19/19 acquisition, 12/12 lifecycle, 29/29 schema và cách ly đều đạt. Bộ chung **exit 0** (`logs/phase14-final.log`).
- [x] Verify **6/6, exit 0** (`logs/phase14-verify.log`). Một lỗi nullable candidate được LSP phát hiện và sửa một lần bằng biến candidate không optional; log đầu `logs/phase14-verify-first.log`. Không có lỗi quá hai vòng. Mọi file mã game ≤350; năm file cam kết không đổi, <310.
- [x] Sửa Persistence/DataService/DevTestService/DevTestPanel, thêm fixture client/test Reset và runner. Không sửa bản copy nguồn trong build, không API thật/publish. Studio/hai server/điện thoại/staging **chờ nghiệm thu**.
- [x] 91/91 file mã game ≤350; build SHA-256 `44E6116E651E1A5DCADCA1EB7FD5090EEFB837D5B8D733360F28FC8559A1AFD8` sinh bằng verify, chưa Play Studio.
- [~] Commit riêng mục này chứa bàn giao; tiếp ngay 1.5. Phần code Reset của Argon P0-3 nay có bằng chứng mô phỏng cùng mục 1.2; vẫn cần review và Engine trước ký nghiệm thu.

## Mục 1.3 — Xác thực hồ sơ và cô lập scheduler

- [x] **Vá review sentinel slot 0:** ShopAndItemsService.SetHotbarSlot thực tế dùng 0 để cất cần. Đã tái hiện validator từ chối lưu hồ sơ hợp lệ, sửa miền 0..5; ca nguồn thật SetHotbarSlot → SpendGold → Save/Close → server B giữ slot 0, Gold 75 và UID túi. V1 slot 0 cũng giữ nguyên; -1/6 vẫn bị cách ly. Schema **29/29**, verify **6/6 exit 0** (`logs/schema-slot0-final.log`, `logs/schema-slot0-verify.log`). Đối chiếu các giá trị ghi thực cho activeBait=nil, gymGear=0, sellValue≥1/Trophy=0, midas≥1 và cấu trúc v1 tại 118e101; không phát hiện sentinel cần sửa thêm. Commit vá chỉ chứa Validator/test schema/PROGRESS. Phép thử Reset 1.4 đang đỏ được giữ ngoài commit vá, tiếp tục ngay theo chỉ đạo.

- [x] Tiếp nhận chỉ đạo Kỹ sư trưởng đã chấp nhận code `0ded6d4` và cho thi công liên tục 1.3–1.5. Nền sạch tại `0ded6d4`; không sửa bản copy trong build. Mỗi mục vẫn commit riêng, nghiệm thu Engine chưa thực hiện.
- [x] Lỗi gốc: reconcile/migration giữ giá trị sai kiểu, dùng ipairs bỏ mục sau lỗ hoặc làm rỗng túi hỏng rồi cho ghi; lỗi một profile dừng vòng scheduler. Đã tái hiện 21 ca đỏ trong `logs/phase13-red.log` trước bản sửa.
- [x] Thêm `ProfileValidator`: kiểm root/version, scalar hữu hạn/không âm, trường hiện diện sai kiểu kể cả v1, map string đúng kiểu, stats/potions/quests/receipt lồng, UID và mảng đặc qua pairs (không bỏ dữ liệu sau lỗ). v1 được thiếu trường mới có mặc định hợp lệ; v2 phải đủ trường; version tương lai cách ly. Không sửa input, không loại vật phẩm lỗi.
- [x] Validate trước reconcile, trước claim chỉnh metadata và trước snapshot ghi. Hồ sơ lỗi/future bị từ chối mà kho nguyên trạng cả nghiệp vụ; rejected callback chỉ dùng báo cách ly khi kho hủy ghi, không làm bằng chứng cấp quyền. Receipt nhả của 1.2 được bảo toàn.
- [x] Scheduler xử lý từng profile bằng pcall và chuyển riêng người lỗi sang chỉ đọc, có cảnh báo. Test lỗi dữ liệu và lỗi biên gửi thông báo của một người vẫn cho người khác gia hạn/lưu/vào lại đúng Gold 81.
- [x] `profile_schema`: **26/26**, gồm v1 di trú hai lần giữ UID/cân/ghim/mở khóa, v2 tốt giữ receipt, v2 sai kiểu/cá thiếu trường, map lồng, mảng thưa/trộn, version tương lai, UTC cùng/ngày mới và scheduler độc lập. **19/19 acquisition**, **12/12 lifecycle** còn đạt. Persistence **6/7**; ca hỏng schema đã xanh, chỉ `dev_reset_during_autosave` (1.4) còn đỏ.
- [x] Lệnh `powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1`: **PASS 6/6, exit 0** (`logs/phase13-verify.log`). Lệnh `powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1`: **exit 1** do duy nhất Reset 1.4 (`logs/phase13-final.log`), không bỏ assertion hoặc che lỗi CI. Mục 1.3 được sửa trong một vòng chức năng, không có lỗi quá hai vòng.
- [x] Sửa DataService/LockHelper/Migrator/Persistence, thêm Validator và test schema; cập nhật fixture/runner. Fixture Bounty nay có đủ cấu trúc CaughtFish như dữ liệu game thật; ca quarantine-yield của 1.1 dùng v1 hợp lệ rồi gây lỗi tạo UID để tiếp tục kiểm đường nhả bất đồng bộ, thay vì nhận khóa một v2 hỏng.
- [x] **91/91** file mã game ≤350, lớn nhất CurrencyService 342; năm file cam kết không đổi, đều <310. Build SHA-256 `2E504438F62DA840172FA1C0F06BD3F71DE4E502A3F569DC5DCD746FFA933355`. Không mở API thật; Studio/Server & Clients/hai server/điện thoại/staging **chờ nghiệm thu**.
- [~] Commit của mục này là commit chứa bàn giao; Kỹ sư trưởng sẽ review sau chuỗi 1.3–1.5. Tiếp ngay 1.4 theo chỉ đạo, rồi 1.5. Không coi mô phỏng là quyết định phát hành.

## Bản vá mục 1.2 — Hạn quyền ghi, gia hạn và lần lưu cuối

### Đã hoàn thành [x]

- [x] Nhận ca trên `codex/studio-data-isolation` tại `0a90644`, cây làm việc sạch. Đọc AGENTS/PLAN/PROGRESS/matrix/blueprint và hai commit `916e5d9` (bộ persistence), `0a90644` (CI). Trong lúc thi công xuất hiện commit tài liệu **`9282aa6`** của ca khác, chỉ sửa AGENTS; đã đọc quy trình kiểm hai tầng/staging mới và giữ nguyên, không đưa vào bản vá này.
- [x] **Lỗi gốc — đọc mã và mô phỏng nền:** thời điểm nhận phản hồi được dùng để kéo dài quyền ghi thay cho dấu giờ lưu trong kho; đóng trùng trả sớm, bỏ kết quả retry và giữ `closingPlayers`; chưa có mã thao tác cố định cho kết quả mơ hồ; autosave dồn cả server cùng nhịp. Bộ nền có 4 ca persistence lỗi: hai lỗi 1.2 và hai lỗi còn lại thuộc 1.3/1.4.
- [x] **Tách module nội bộ, giữ điểm vào gameplay:** `DataService` tiếp tục cung cấp Get/Wait/Save/MarkDirty/Reset/snapshot; `ProfilePersistenceService` giữ trạng thái theo phiên, lease, hàng chờ ghi và đóng; `ProfileWriteHelper` giữ snapshot/nonce bất biến và xác nhận từ kho. Chuyển phần `WriteSnapshotVerified` cũ khỏi LockHelper sang helper mới, không còn caller dùng hàm cũ. Không đổi Remote, gamepass, luật thưởng hay schemaVersion.
- [x] **Hạn quyền ghi:** lấy `lockTimestamp` từ tài liệu claim/ghi được kho xác nhận, không lấy thời điểm trả phản hồi. Giao dịch bị khóa khi tới hạn 120 giây theo dấu giờ đó, kể cả phản hồi chậm. Ghi vẫn kiểm đúng token và saveSeq hiện hành tại UpdateAsync; queued writer kiểm lại trạng thái chỉ đọc sau khi đợi UserId.
- [x] **Kết quả mơ hồ:** mỗi thao tác giữ nguyên snapshot, token, nonce và nextSeq qua các lần retry. UpdateAsync không ghi lại thao tác đã áp dụng. GetAsync với `UseCache=false` đối chiếu token/seq/nonce; không đủ bằng chứng thì TransientError hoặc LostLock, không báo Saved giả. Receipt nhả cuối được giữ để xác nhận A kể cả B đã claim/lưu; không ghi đè B để xác nhận A.
- [x] **Lần lưu cuối:** đặt cờ đóng trước khi chụp snapshot; PlayerRemoving và BindToClose cùng chờ tác vụ theo phiên, kể cả người đã rời Players. Kết quả Saved/Skipped/RAMOnly/Unconfirmed là chung và bất biến; báo cáo shutdown theo token chứa cùng kết quả, không chứa Player. Hạn 25 giây dùng chung, retry lỗi tạm trong hạn; hết hạn ghi cảnh báo gồm UserId/token/seq/nonce/lý do. API trả muộn không cài lại RAM.
- [x] **Đóng nhiều hồ sơ và dọn tham chiếu:** shutdown khóa mọi giao dịch trước khi khởi chạy các tác vụ song song. Một hồ sơ treo không chặn hồ sơ khác. Hoàn tất/hết hạn xóa phiên khỏi registry và nhả player/profile/pending; 30 lượt rời/vào đưa Count về 0 sau mỗi lượt. BindToClose chờ các phiên đang đóng thay vì chỉ đếm người hiện diện.
- [x] **Gia hạn:** chia pha theo UserId trên chu kỳ 60 giây, kể cả hồ sơ không có giao dịch; không tạo nhiều lượt chờ tự lưu cho cùng phiên. Lỗi tạm lên lịch đối chiếu/thử lại sớm, quyền giao dịch vẫn chịu dấu giờ đã xác nhận. Giữ RAM-only chưa publish và `_StudioDev` của mục trước.

| Ca nghiệm thu | Loại bằng chứng | Kết quả thực tế |
|---|---|---|
| Claim/lưu đã ghi, phản hồi chậm 100 giây; kiểm sau giây 120 | Mô phỏng nguồn thật | Không được kéo dài lease từ lúc nhận phản hồi; A không còn quyền ghi sau hạn lưu trong kho. |
| PlayerRemoving đang lưu thì BindToClose chạy | Mô phỏng điểm vào thật | Cả hai chờ; cùng nhận Saved theo token; đúng một snapshot cuối và một lần tăng seq. |
| Lưu cuối lỗi tạm trước ghi rồi thành công | Mô phỏng persistence | Retry snapshot cố định, lưu Gold 731, nhả chủ và seq=2. |
| Đã ghi nhưng mất phản hồi, lần đọc xác nhận đầu cũng lỗi | Mô phỏng lifecycle | Retry cùng thao tác; chỉ đọc để chứng minh, không ghi snapshot lần hai; seq=2, tổng commit=2 kể cả claim. |
| A mất phản hồi nhả, B vào và lưu trước khi A đối chiếu | Hai máy chủ mô phỏng, chung kho RAM | Receipt xác nhận A đã lưu, Gold/owner B giữ nguyên; A không ghi đè B. |
| Autosave trước Bounty đang đợi; tiêu UID, rồi chồng cả hai đường đóng/mất phản hồi cuối | Handler Bounty + DataService thật trong mô phỏng | Autosave rồi đúng một snapshot cuối (seq=3); vào B thấy Gems 45, Relic từ 3→4, một Lucky Elixir; UID tiêu biến mất, UID khác giữ, ô ghim dọn; nộp lại không nhận thêm thưởng. |
| Lỗi đến hết hạn đóng / API treo | Mô phỏng | Trong 25 giây trả Unconfirmed chung cho các đường chờ; có cảnh báo, không báo đã lưu số dư chưa ghi; registry về 0. |
| Hai hồ sơ đóng, một API treo; sau hạn API trả | Mô phỏng nhiều khóa RAM | Hồ sơ kia vẫn lưu song song; hết hạn dọn registry, phản hồi muộn không cài lại profile. |
| Hồ sơ đứng yên / ba UserId vào cùng lúc | Mô phỏng lịch coroutine thật tại biên Engine | Cả ba gia hạn ở pha khác nhau, sau 125 giây vẫn giữ quyền và đã tăng seq ít nhất hai lần. |
| Save cũ chờ API, B nhận khóa; queued writer chạy sau | Mô phỏng | A nhận LostLock, queued writer không gọi kho thêm; B giữ token và quyền ghi. |
| Studio chưa publish / ba đích dữ liệu Studio đã publish | Mô phỏng hồi quy | RAM-only giữ hành vi cũ, 0 lần mở/ghi kho; Studio đã publish không yêu cầu tên sản xuất. |
| Play Solo / Server & Clients / hai server Roblox / điện thoại / staging | Chưa chạy | **Chờ nghiệm thu**, không có phiên experience thử kết nối để thực thi và ghi bằng chứng; không bật API sản xuất, không publish. |

**Lệnh và kết quả cuối:**

```powershell
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1 -Suite session_lifecycle
# LIFECYCLE_SUITE passed=12 failed=0; exit 0
powershell -ExecutionPolicy Bypass -File tools\test_studio_data_isolation.ps1
# Studio PASS; session_acquisition 19/19; session_lifecycle 12/12;
# data_persistence 5/7; exit 1 do hai ca 1.3/1.4 ben duoi
powershell -ExecutionPolicy Bypass -File tools\verify_project.ps1
# PASS 6/6, exit 0; chi xac nhan bo kiem dinh tu dong
```

- [x] **Hai ca vẫn FAIL, không bỏ qua:** `malformed_profile_is_quarantined` (1.3: hồ sơ sai kiểu vẫn mở ghi, túi sai kiểu bị thay bảng); `dev_reset_during_autosave` (1.4: Gold vẫn 505 thay vì 0). Các assertion giữ nguyên. CI gọi bộ chung mặc định nên hiện vẫn đỏ vì hai ca này; không coi kết quả chọn riêng lifecycle là toàn bộ CI xanh. Argon P0-3 còn cần ca Reset 1.4 trước khi ký toàn mã.
- [x] **Bằng chứng RED→GREEN:** `logs/phase12-baseline.log`, `logs/phase12-red.log`; mở rộng kiểm hàng đợi và kết quả hai đường đóng có red riêng `logs/phase12-queued-red.log`, `logs/phase12-outcome-red.log`, sau sửa đều đạt. Lỗi khai báo kiểu đã lưu ở `logs/phase12-verify-first.log`/`phase12-verify-second.log`: weak table sửa một lần; arity của pcall worker cần hai lượt chỉnh, lượt hai đạt bằng return boolean ở mọi nhánh. Không còn lỗi cùng loại chưa giải quyết sau hai vòng.
- [x] Log cuối: `logs/phase12-lifecycle-final.log`, `logs/phase12-regressions-final.log`, `logs/phase12-verify-final.log`, `logs/app.log`. Fixture mở rộng lịch coroutine/đa khóa/GetAsync, không thay kết quả của các dịch vụ gameplay cần kiểm.
- [x] **90/90 file mã game ≤350 dòng**, lớn nhất CurrencyService 342. DataService 191, LockHelper 143, Persistence 186, WriteHelper 62. HudPanel 268 / PetsService 298 / ProgressPanel 268 / BagPanel 307 / FishingService 282, đều <310. `git diff --check` đạt.
- [x] Build `build/mighty-angler-dev.rbxlx`, SHA-256 **`563AE53ABDB1181330E7324453DE604537AA2C865088B2D64E849FD8CA91D9B1`**. Đối chiếu Source bốn module dữ liệu **4/4 khớp** sau chuẩn hóa xuống dòng; chưa Play build này trong Studio.

### Đang làm dở [~]

- [~] Chờ Kỹ sư trưởng review commit riêng chứa mục bàn giao này. Chưa đóng nghiệm thu Engine của Codex P0-02; Argon P0-3 còn phụ thuộc mục 1.4. Không tự chuyển sang 1.3 trước review theo giao việc hiện hành.

### Bước tiếp theo [ ]

- [ ] Review bản vá và tái chạy lệnh; nghiệm thu Studio/Server & Clients/hai server trên experience thử có sẵn và staging theo AGENTS. Không mở API sản xuất để kiểm.
- [ ] Sau giao việc tiếp: sửa schema/cách ly ở 1.3 và Reset theo hàng chờ ở 1.4 để đóng hai test còn đỏ; xử lý HUD/snapshot 1.5 ở mục riêng.

### Quyết định kỹ thuật & Lưu ý cho AI ca sau

- Thêm duy nhất trường tùy chọn `lastReleaseReceipt = {token, nonce, saveSeq}` vào tài liệu khi lưu cuối; không tăng dataVersion. Claim mới bảo toàn receipt, ghi thường giữ receipt mới nhất từ kho thay vì snapshot cũ; receipt chỉ một mục nên không tăng dần theo lượt vào. Writer giữ UserIds/metadata khi keyInfo có sẵn. Khi làm schema 1.3 cần bảo toàn receipt này và các dữ liệu nghiệp vụ, không coi thiếu receipt ở hồ sơ cũ là lỗi.
- Nếu receipt cũ đã bị một lần đóng mới thay thế và không còn bằng chứng đủ cho thao tác đang chờ, báo Unconfirmed/LostLock một cách bảo thủ; không suy ra Saved chỉ từ số seq lớn hơn. Hết deadline chỉ báo chưa xác nhận tại hạn đó, không cam kết API đang treo đã bị Engine hủy.
- `SaveProfile(player, true)` đi qua tác vụ đóng chung để không còn cửa giao dịch sau nhả khóa. Reset vẫn giữ điểm vào cũ và còn lỗi 1.4 có test; không đổi tiền/thưởng hay tự sửa các mục ngoài phạm vi.
- Bản vá gồm DataService/LockHelper, hai helper mới, fixture/lifecycle/persistence tests, hai runner, README test và PROGRESS. Không sửa AGENTS/PLAN/matrix/CI của ca khác; commit `9282aa6` được giữ riêng. Tất cả ghi thử ở kho RAM giả lập, không có thao tác DataStore thật hoặc phát hành.

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
