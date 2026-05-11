# HoYoKProtect Wine Launch Handling

## Bối Cảnh

NSLauncher hiện phát hiện lỗi Wine khi Genshin Impact cố load `HoYoKProtect.sys`. Đây là driver kernel/protection của HoYoverse. Research trên Wine và nguồn cộng đồng cho thấy Wine không chạy native Windows kernel drivers trên Unix/macOS vì Wine không implement Windows kernel thật, chỉ cung cấp lớp tương thích user-space trên host kernel.

Nguồn tham chiếu:

- Wine Developer's Guide: Wine không chạy native Windows drivers vì không cung cấp hạ tầng kernel Windows bên trong Wine.
- HoYoverse Help Center: yêu cầu PC chính thức của Genshin là Windows 10 64-bit.
- Microsoft Q&A: `HoYoKProtect.sys` được nhận diện là anti-cheat/protection driver của Genshin.
- Các thảo luận Wine/Linux gaming gần đây nhất quán rằng kernel-level anti-cheat/protection không có fix tổng quát trong Wine/Proton nếu nhà phát hành không hỗ trợ đường chạy tương thích.

## Kết Luận Research

Không tìm thấy cách fix an toàn, ổn định và hợp pháp để Wine trên macOS load hoặc thay thế `HoYoKProtect.sys`.

Những hướng không nên làm:

- Không hướng dẫn disable, patch, rename, delete, bypass hoặc né anti-cheat/protection driver.
- Không hứa rằng đổi DXVK/DXMT/Wine prefix sẽ sửa được lỗi kernel driver.
- Không khuyến nghị launcher bên thứ ba nếu bản chất là bypass protection/anti-cheat.

Những hướng hợp lý:

- Cập nhật game bằng Sophon trong NSLauncher vẫn hữu ích, nhưng launch có thể bị chặn nếu bản game yêu cầu driver protection.
- Hiển thị thông báo rõ: launch trên Wine/macOS hiện không hỗ trợ driver kernel Windows của HoYoverse.
- Gợi ý lựa chọn được hỗ trợ: Windows chính thức, thiết bị/mobile/console được HoYoverse hỗ trợ, hoặc chờ HoYoverse/Wine có hỗ trợ tương thích chính thức.

## Mục Tiêu

Khi gặp `HoYoKProtect.sys`, NSLauncher phải:

- Giải thích đây là giới hạn kernel-driver/anti-cheat của Wine, không phải lỗi download/update.
- Tránh wording “chạy đúng file không cần driver protection” vì research không chứng minh có file chính thức như vậy.
- Không đưa workaround bypass.
- Giữ log kỹ thuật đủ để debug: driver name, Wine binary, executable path, prefix, exit code nếu có.

## Hướng Tiếp Cận Đề Xuất

1. Cập nhật copy lỗi `unsupportedKernelDriver` trong `AppText`/ViewModel thành thông báo rõ ràng hơn.
2. Khi detect `HoYoKProtect.sys`, thêm link hoặc text hướng dẫn rằng PC chính thức yêu cầu Windows.
3. Tách lỗi này khỏi lỗi Wine/DXMT chung để user không mất thời gian đổi runtime.
4. Giữ detector hiện tại trong `WineService.unsupportedKernelDriverName`.

## Công Việc Cần Làm

- Sửa message user-facing cho `WineServiceError.unsupportedKernelDriver`.
- Cập nhật localization tiếng Việt/Anh nếu đang hardcode ở `localizedErrorMessage`.
- Thêm log detail trước khi throw lỗi unsupported driver.
- Không sửa downloader/update flow.

## Rủi Ro Và Ràng Buộc

- Đây là thay đổi UX/error handling, không làm game chạy được qua Wine.
- Không thêm hướng dẫn bypass anti-cheat/protection.
- Nếu HoYoverse đổi driver name, detector cần cập nhật danh sách tên.

## Kiểm Chứng

- `swift build`
- Unit/manual check bằng sample Wine output chứa `HoYoKProtect.sys` để đảm bảo message đúng và không bị phân loại thành lỗi process generic.
