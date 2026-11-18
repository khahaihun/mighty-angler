# V3 — Bàn giao bản ứng viên và nghiệm thu chơi thật

- **Ngày:** 18/11/2026 — Codex, nhánh riêng `codex/v3-combined` trong `build/v3-regression-sol`.
- **Phạm vi hiện tại:** đã ghép dữ liệu `99216b5` (1.1–1.4), gameplay `3f43d35`, UI/odds `ad013c4`, UI Live Odds/pet `9c93901`, cùng bộ hồi quy `3132629` và test giao thoa. Merge dữ liệu hiện tại `053a393`.
- **1.5 vẫn đang thi công**, chờ SHA cuối để ghép và kiểm lại. Các kết quả dưới đây là bản ứng viên tạm này, không phải quyết định phát hành và không gọi “đã sạch lỗi”. Checkout chính được giữ nguyên.
- **Studio chưa chạy vì quyền ứng dụng**; chưa có bằng chứng Play Solo, hai client/server thật hoặc điện thoại. Không dùng mô phỏng để thay thế nghiệm thu đó.
- [Matrix 21 mục đã đạt theo mã trước V3](V3_REGRESSION_MATRIX.md) phân biệt VM/đọc mã/ca Engine chờ; [matrix thiết kế–mã](SPEC_CODE_MATRIX.md); [blueprint 3 đợt](superpowers/plans/2026-11-18-action-blueprint-v3.md).

## Kết quả tự động và bản đóng gói hiện tại

Sau merge dữ liệu `99216b5`, đã tìm script bằng `rg --files tools` và chạy **12/12 runner test, mỗi lệnh exit 0**, cùng `verify_project.ps1` **PASS 6/6, exit 0**. Kết quả suite dữ liệu: acquisition **19/19**, lifecycle **12/12**, schema **29/29**, reset **12/12**, persistence **7/7**; cách ly Studio/bảng điểm PASS. Regression gameplay **23/23**, odds **19.200 rổ**, Equip Best/bỏ pet cũ/trang bị mới, Live Odds khi có cả hai pass và giao thoa Auto–camera–odds PASS trong VM.

Bổ sung `tools/test_place_sources.ps1`: **100/100** Script/LocalScript/ModuleScript khớp đường dẫn, class và toàn bộ Source với sourcemap/đĩa (chuẩn hóa xuống dòng XML); không có script thừa/thiếu. Đây là kiểm nội dung đóng gói, không chạy Roblox Engine.

- Build đã kiểm: `build/mighty-angler-dev.rbxlx` trong clone ứng viên.
- SHA-256: `4951C3D041276553D0DDF0AF4F19B76B549A74CB80B0F05373C296DBB5955014`.
- Hash/SHA và số script **phải cập nhật lại sau tip 1.5**. Build không được coi là cùng ứng viên nếu Source hoặc hash khác.
- Log cục bộ: `logs/data992-test_*.log`, `logs/data992-verify.log`; bị Git bỏ qua, chuyển máy phải chạy lại từ commit.

Cách kiểm cuối: từ cây Git sạch, chạy verify để dựng build mới, dùng `rg --files tools` liệt kê **mọi** `test*.ps1`, chạy từng file bằng PowerShell và ghi exit code; bao gồm `test_place_sources.ps1` mới. Bốn probe âm của regression chạy riêng, mỗi probe cố tình phải exit 1 vì assertion; không trộn vào danh sách runner mặc định phải exit 0. Sau đó chạy regression không probe lại exit 0.

## Đủ 23 mã còn một phần trong V3, theo ba đợt

“Đạt VM/mã” chỉ nói phạm vi tự động hoặc đối chiếu đã thực hiện; cột chơi thật đều chờ. Các mã trùng chủ đề vẫn được theo dõi riêng đúng biên bản gốc.

| # | Đợt / mã | Bằng chứng và trạng thái bản ứng viên | Chơi thật cần thấy |
|---|---|---|---|
| 1 | 1 · Codex P0-01 | Acquisition 19/19; chỉ cấp quyền ghi khi claim đúng token/nonce. | Hai server tranh hồ sơ: tối đa một server có quyền giao dịch. |
| 2 | 1 · Codex P1-01 | Acquisition/release thử lại, phản hồi muộn không đụng chủ mới. | A rời khi tải; B vào; nhả A muộn không xóa khóa B. |
| 3 | 1 · Codex P0-02 | Lifecycle 12/12: lease theo giờ kho, close chung, nonce cố định và deadline. | Giao dịch trước chuyển server không mất/nhân bản khi lưu chậm. |
| 4 | 1 · Argon P0-3 | Lifecycle + persistence7/7 + reset12/12, đóng/lưu cuối/Reset hàng đợi. | Chồng shutdown/rời và Reset khi autosave; vào lại đúng một kết quả. |
| 5 | 1 · Codex P1-03 | Schema29/29, cách ly hồ sơ sai, migration/slot0 hợp lệ; không đè dữ liệu lỗi. | Hồ sơ lỗi chỉ đọc; hồ sơ tốt cùng server vẫn gia hạn/lưu được. |
| 6 | 1 · Codex P2-06 | Reset12/12, RAM/lưu bền tách rõ, lease hết không reset dữ liệu. | Reset DEV rồi vào lại mặc định sau xác nhận; lỗi API/RAM-only báo đúng. |
| 7 | 1 · Codex P1-04 | **1.5 chờ tip**, chưa ký kết quả khởi tạo muộn/safeReadOnly. | Tải trước/sát/sau8s: đúng một snapshot đầy đủ, cảnh báo chỉ đọc, Live Odds vẫn có. |
| 8 | 2 · Argon P1-4 | Ray first-hit thật, chung filter Client/Server; VM ray/Auto PASS. | Cầu/đất/đá/trời/tường/biển: không nhận nước dưới vật cản, không xuyên tường người. |
| 9 | 2 · Codex P1-08 | Auto tìm nước qua cùng validator; bounce dùng hit server. | 4 chế độ câu tại 5 đảo; không mất mồi/thưởng cá khi điểm sai. |
| 10 | 2 · Argon P1-5 | Một lịch Auto, readyAt server; lifecycle/client scheduler PASS. | Win/Miss/Timeout/đổi đảo/Rebirth/hồi sinh tiếp đúng một lượt. |
| 11 | 2 · Codex P1-09 | Hold server kiểm hai biên Perfect; không tin ratio client; đúng hồi Free/Pro. | Perfect0,78–0,95 được buff, ngay ngoài không được; hồi1,10/0,45s. |
| 12 | 2 · Codex P1-11 | Intent có thứ tự/ACK, OFF→ON và stale close không xóa ON mới. | Cất cần/hủy tay dừng lịch cũ; bật lại trong hồi không đứng im/nhân lịch. |
| 13 | 2 · Codex P1-10 | VM 1/2/3 vòng, hạn bấm và +0,40s nhận gói, client đợi server. | Ping200ms, cú sát hạn hợp lệ; hết hạn không gửi, chỉ một cá/kết quả/lịch. |
| 14 | 2 · Argon P1-3 | WorldPromptAccess dùng prompt thật/bán kính3D; VM PASS. | Mở bảng rồi đi xa, lệch cao/sai đảo không mất tiền/cá. |
| 15 | 2 · Codex P1-06 | Appraise/Bounty/Trident/Enchant cùng kiểm prompt hợp lệ tại xác nhận. | Thử NPC mặc định, override nếu bật, bệ Enchant sát trong/ngoài tầm. |
| 16 | 2 · Argon P1-1 | Index lần đầu và GridWindow vùng thấy +1 hàng; VM PASS. | Hồ sơ mới0/35 cá,0/30 pet; mở/đóng/cuộn50 lần không tăng thẻ/kết nối. |
| 17 | 2 · Codex P1-14 | Grid ẩn/khuất không cấp thẻ/khởi động xoay lại theo mã + VM vùng cuộn. | Tab ẩn/lưới ngoài màn hình có0 thẻ xoay; điện thoại giữ mượt khi túi đầy. |
| 18 | 3 · Codex P1-13 | Policy strict boolean false;6 ca giao dịch từ chối giữ tiền/vật phẩm; Gold/Relic PASS. | Pending/API lỗi/thiếu/sai kiểu/true bị chặn Gems; false trả đúng giá. |
| 19 | 3 · Argon P1-6 | Odds19.200 rổ khớp roll/provider; trứng/Enchant/purchase preview. | Từng loài/mode/buff/nước khớp UI; xem trước cả lối Shop/Exclusive trước mua. |
| 20 | 3 · Codex P1-12 | Live Odds Base/Live cho người có2 pass; Swift0%, Midas4/72; Boss trong Rare+. | Mở Live Odds, đổi cast/buff cập nhật; đóng không prompt mua; có sẵn khi readOnly. |
| 21 | 3 · Codex P2-02 | CatchControl dùng chung; Trident Twig17kg; slot pet2→4, từ chối5 không thay pet cũ. | Rare28%/Boss22% cộng đúng Strength; Unequip→Equip mới và EquipBest dễ dùng. |
| 22 | 3 · Codex P1-16 | AnimationController thật trong VM R6/Motor6D/AnimationConstraint, không cộng dồn100frame. | Hai client thấy đúng động tác/cá/tạ; kiểm khớp tay và hồi sinh trên3 kiểu rig. |
| 23 | 3 · Codex P2-05 | ParticleBudget/Pet lifecycle VM, giữ aura state/Toolbox; mã lọc emitter được đánh dấu. | Chủ pet xa160studs/đổi đảo/quay về, cá đột biến gần/xa LowGFX; đo p95 điện thoại. |

## Checklist chơi thật ngắn cho chủ dự án

- [ ] **Play Solo (F5):** hồ sơ mới mở Index; rút/cất cần và giữ/thả; câu nước/đất/cầu; thử Auto OFF→ON, hủy tay; xem Live Odds kể cả đã có pass; bán/khóa/Appraise10,4kg, Trident/Bounty đúng UID; preview14 cá khóa rồi Rebirth giữ12/ghim/Exclusive; bỏ pet cũ rồi đeo mới/EquipBest. Xem Output và thông báo chỉ đọc; đóng thoại không tự bán cá.
- [ ] **Server & Clients, 2 client, ping200ms:** 1/2/3 vòng sát hạn; đổi đảo/Rebirth/chết giữ Auto, hủy tay dừng; một cá/nhịp; camera thoại chồng minigame; hai người quan sát hoạt ảnh/tạ/R6-R15, pet gần/xa, LowGFX. Ghi ảnh/video, số thẻ/kết nối trước/sau50 lần mở cửa sổ.
- [ ] **Staging, 2 server:** cùng tài khoản thử chuyển A→B trong lúc tải/lưu chậm; nộp một UID Bounty và nhận đúng một thưởng sau vào lại; lỗi API/lưu cuối/lease/Reset có kết quả rõ; hồ sơ chỉ đọc không tiêu tiền hoặc ghi bảng điểm. Giữ nguyên kho production; dùng place staging và tài khoản thử.
- [ ] **Điện thoại thật:** giữ quăng bằng ngónA, ngónB không đổi/hủy aim; A thả lấy điểm cuối; nút/preview không cắt; túi60 cá/80pet/65Index cuộn ổn, LowGFX gần/xa. Ghi thiết bị, cấu hình, FPS/p95 cùng cảnh trước/sau.

Mỗi ô ghi SHA/place/hash, ngày, người thử, kết quả thực tế và lỗi còn lại. Chỉ publish ứng viên lên staging theo chỉ đạo; place chính phải đợi đúng bản đó được nghiệm thu và Kỹ sư trưởng duyệt. File này không cấp quyền phát hành.

### Runner mặc định đã chạy trên ứng viên dữ liệu 99216b5

| Script trong tools | Exit |
|---|---|
| test_animation_pose.ps1 | 0 |
| test_camera_focus.ps1 | 0 |
| test_catch_control.ps1 | 0 |
| test_combined_integration.ps1 | 0 |
| test_fishing_wave.ps1 | 0 |
| test_live_odds.ps1 | 0 |
| test_paid_random_policy.ps1 | 0 |
| test_paid_random_transactions.ps1 | 0 |
| test_particle_budget.ps1 | 0 |
| test_place_sources.ps1 (mới) | 0 |
| test_session_acquisition.ps1 | 0 |
| test_studio_data_isolation.ps1 | 0 |
| test_v3_regression.ps1 | 0 |
| verify_project.ps1 | 0 |
