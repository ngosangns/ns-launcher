# Fix Genshin Wine Kernel Driver Launch

## Bối Cảnh

Người dùng start Genshin qua Wine và process thất bại với log `HoYoKProtect.sys`
/ `HoYoProtect`. Local install hiện có `HoYoKProtect.sys`, `mhypbase.dll`,
`rtlbase.dll`, và `driverError.log` ghi `initDriver Failed: Error [4,1114,0]`.
Launcher đang gọi `GenshinImpact.exe`, không thấy `HoYoPlay.exe` hoặc executable
launcher chính thức trong install root. Metadata `.nslauncher-install.json` vẫn
ghi version `5.5.0`, trong khi thư mục game đã có nhiều asset mới hơn và
`.nslauncher-sophon-staging` còn tồn tại.

Windows `ZwLoadDriver` dùng để load device hoặc file-system driver vào hệ thống
đang chạy. Log Wine đang fail đúng tại lớp này:
`ntoskrnl:ZwLoadDriver failed to create driver ... HoYoProtect` và thiếu
`WDFLDR.SYS`. Wine `ntoskrnl.exe` vẫn có nhiều kernel API ở trạng thái stub,
nên launcher không thể sửa bằng cách làm Wine load được `HoYoKProtect.sys`.
Hướng sửa hợp lệ là không đưa user vào launch path yêu cầu driver này khi install
/ update chưa đúng trạng thái, và sau đó surface lỗi rõ ràng nếu bản game hiện
tại thật sự bắt buộc kernel protection driver.

## Mục Tiêu

- Không để user bấm Play trên một Genshin install đang stale hoặc update dở.
- Nếu toàn bộ asset Sophon đã khớp nhưng metadata cũ, Update phải repair metadata
  mà không tải lại game.
- Khi Wine gặp kernel driver protection sau khi install đã được repair/update,
  launcher báo nguyên nhân rõ ràng và không coi đây là lỗi DXMT/Wine chung.
- Giữ launch path hợp lệ: không bypass, patch, vô hiệu hóa hoặc giả lập anti-cheat
  / protection driver của game.

## Ngoài Phạm Vi

- Không triển khai bypass, patch, stub giả, rename/delete, registry hack hoặc
  DLL override nhằm vô hiệu hóa `HoYoKProtect.sys`, `mhypbase.dll`, hoặc
  anti-cheat/protection.
- Không tự chạy HoYoPlay Windows launcher trong Wine.
- Không xóa/cài lại game tự động khi chưa có hành động rõ từ user.
- Không đổi Sophon patch/diff format; vẫn dùng full-build asset manifest hiện có.

## Hướng Tiếp Cận Đề Xuất

1. Giữ detection lỗi kernel driver trong `WineService` và localized message trong
   UI. Phần này đã được thêm bước đầu để thay raw `Process failed code 5`.
2. Thêm Genshin launch preflight trong `LauncherCoordinator.launchGame` hoặc
   `LauncherViewModel.launchSelectedGame`:
   - đọc `.nslauncher-install.json`;
   - nếu `game.id == genshin-global` và metadata đang là legacy `5.5.0`, hoặc
     `.nslauncher-sophon-staging` còn partial/chunk state cho thấy update chưa
     hoàn tất, block launch với message yêu cầu chạy Update Game trước;
   - nếu metadata thiếu hoặc không đọc được, block launch và yêu cầu import/update
     lại thay vì gọi Wine mù.
3. Tăng chất lượng Update path cho trường hợp hiện tại:
   - nếu Sophon plan thấy mọi asset đã match nhưng metadata cũ, cho phép Update
     chạy repair metadata;
   - cleanup `.nslauncher-sophon-staging` rỗng hoặc chỉ còn file hệ thống sau khi
     metadata repair/update thành công.
4. Không fetch Sophon manifest nặng trước mỗi Play. Preflight launch chỉ kiểm tra
   state local; Update Game mới là nơi fetch Sophon build/manifest và repair.
5. Thêm log/UI text riêng cho trạng thái "install needs update before launch" để
   user biết cần bấm Update, không phải lỗi Wine.

## Công Việc Cần Làm

- Thêm `AppText.genshinUpdateRequiredBeforeLaunch(...)`.
- Thêm domain error như `LauncherCoordinatorError.updateRequiredBeforeLaunch`.
- Trong launch flow của Genshin, chặn metadata legacy/stale trước khi gọi Wine.
- Thêm helper kiểm tra `.nslauncher-sophon-staging` có state dở dang; bỏ qua file
  hệ thống như `.DS_Store`.
- Đảm bảo `GenshinSophonInstaller.update` repair metadata khi `assets` rỗng nhưng
  `metadataNeedsUpdate == true`.
- Cleanup staging directory sau Sophon update thành công nếu không còn partial /
  chunk state hữu ích.
- Giữ kernel-driver error detection đã thêm; không dùng `driverError.log` làm
  nguồn quyết định vì nó là output của lần launch fail trước.

## Rủi Ro Và Ràng Buộc

- Nếu bản Genshin hiện tại thật sự yêu cầu kernel driver để chạy, NSLauncher không
  thể làm nó chạy trên Wine/macOS theo hướng hợp lệ.
- Cố gắng giả lập/stub kernel driver có thể tạo hành vi sai, vi phạm kỳ vọng bảo
  vệ của game, và không phù hợp với mục tiêu launcher.
- Fetch Sophon build/manifest trước mỗi Play sẽ làm Play chậm và tốn mạng, nên
  preflight launch chỉ dùng metadata/state local.
- Metadata `5.5.0` có thể là dấu hiệu update chưa hoàn tất, nhưng cũng có thể là
  metadata cũ sau khi files đã match; Update repair phải xử lý cả hai.

## Kiểm Chứng

- `swift build`.
- Với install local đang có metadata `5.5.0`, bấm Play phải bị chặn trước Wine và
  báo cần chạy Update.
- Chạy Update khi files đã match Sophon target phải ghi lại
  `.nslauncher-install.json` version mới mà không tải lại toàn bộ asset.
- Sau metadata repair/update, nếu Wine vẫn gặp `HoYoKProtect.sys`, UI phải báo lỗi
  kernel driver rõ ràng thay vì stderr thô.
