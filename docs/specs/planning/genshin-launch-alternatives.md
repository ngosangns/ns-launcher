# Genshin Launch Alternatives

## Bối Cảnh

Wine trên macOS không chạy được Windows kernel driver như `HoYoKProtect.sys`.
Yêu cầu hiện tại là tìm đường khởi chạy khác để chơi/kiểm thử mà không bypass
hoặc vô hiệu hóa lớp protection của game.

Nguồn tham chiếu:

- HoYoverse Help Center: PC requirement chính thức là Windows 10 64-bit tối
  thiểu, Windows 10/11 64-bit khuyến nghị, DirectX 11, và 110 GB storage.
- NVIDIA GeForce NOW FAQ: Genshin Impact được hỗ trợ trên GeForce NOW, có thể
  chơi trên Mac, không cần tải toàn bộ game, progress lưu cloud, và policy
  trong game nhất quán với nền tảng khác.
- Apple Support: Boot Camp chỉ áp dụng cho Mac Intel được hỗ trợ để cài Windows
  10 native.
- Microsoft Support: Windows 11 Arm qua Parallels là giải pháp được ủy quyền
  cho Mac Apple silicon, nhưng có hạn chế với game/app phụ thuộc DirectX 12 và
  một số lớp ảo hóa/bảo mật.
- Parallels KB: Parallels hỗ trợ DirectX tới 11 và OpenGL tới 4.1, nhưng đa số
  anti-cheat không chạy trong môi trường ảo hóa.

## Mục Tiêu

- Đề xuất các đường chạy hợp lệ thay cho Wine khi game yêu cầu Windows kernel
  driver.
- Xác định hướng nào đáng tích hợp vào NSLauncher và hướng nào chỉ nên ghi chú
  cho người dùng.
- Không triển khai bypass anti-cheat, patch driver, hook kernel, stub driver,
  hoặc hướng dẫn né kiểm tra protection.

## Ngoài Phạm Vi

- Bypass `HoYoKProtect.sys` hoặc bất kỳ kernel anti-cheat/protection driver nào.
- Sửa binary game, sửa launcher chính thức, DLL override để vô hiệu hóa
  protection, hoặc dùng build không chính thức.
- Cam kết VM sẽ chạy được Genshin nếu protection hoặc nền tảng Windows Arm không
  hỗ trợ.

## Đánh Giá Các Hướng

### 1. GeForce NOW

Đây là hướng khả thi nhất trên macOS nếu mục tiêu là chơi game, không phải debug
file local. Game chạy trên máy Windows/cloud của NVIDIA, Mac chỉ stream input và
video. Ưu điểm là không cần Wine, không cần Windows image, không đụng kernel
driver local, progress sync cloud. Nhược điểm là phụ thuộc khu vực hỗ trợ,
network latency, hàng chờ/gói thuê bao, và NSLauncher không còn quản lý install
local.

### 2. Windows Native Trên Máy Windows Hoặc Intel Mac Boot Camp

Đây là hướng đúng nhất nếu cần kiểm thử behavior thật của PC build. Windows chạy
native nên driver/protection có môi trường phù hợp. Với Mac Intel được Apple hỗ
trợ, Boot Camp có thể cài Windows 10. Với Apple silicon, Boot Camp không phải
đường native khả dụng.

### 3. Parallels/VMware Windows 11 Arm

Đây là hướng có thể thử nghiệm phụ, nhưng rủi ro cao cho game có anti-cheat.
Windows 11 Arm trong VM có thêm lớp khác biệt kiến trúc CPU, GPU virtualization,
và hạn chế anti-cheat trong môi trường ảo hóa. Dù Genshin yêu cầu DirectX 11,
vấn đề kernel/protection vẫn là blocker tiềm năng.

### 4. UTM/QEMU Windows Image

Không nên ưu tiên cho game. Trên Apple silicon, hiệu năng GPU/3D acceleration
không phù hợp cho game nặng và vẫn không giải quyết sạch yêu cầu kernel driver.

### 5. Nền Tảng Mobile/iPadOS

Khả thi nếu mục tiêu là chơi bằng tài khoản hiện có. Không thay thế PC local
install trong NSLauncher, nhưng là fallback hợp lệ và ít rủi ro.

## Hướng Tiếp Cận Đề Xuất Cho NSLauncher

1. Giữ Wine path hiện tại như best-effort cho game không đòi Windows kernel
   driver.
2. Khi detect `HoYoKProtect.sys`, hiển thị nhóm lựa chọn thay thế thay vì chỉ
   báo lỗi:
   - Mở GeForce NOW Genshin.
   - Hướng dẫn dùng Windows native/Boot Camp nếu là Mac Intel.
   - Cảnh báo Parallels/VM Windows Arm là experimental và có thể fail vì
     anti-cheat/architecture.
3. Thêm `LaunchAlternative` model nhỏ để UI có thể render các hành động:
   `cloudGaming`, `windowsNative`, `virtualMachineExperimental`, `mobile`.
4. Thêm link ngoài có kiểm soát trong UI, không tự tải/cài VM hoặc image Windows.
5. Log rõ lý do Wine không tiếp tục: kernel driver unsupported, không phải lỗi
   Wine version hay DXMT.

## Công Việc Cần Làm

1. Thêm copy localized cho các launch alternatives.
2. Mở rộng error mapping trong `LauncherViewModel` để lỗi kernel driver có
   recovery options.
3. Thêm UI nhỏ trong launch log/error panel để mở link GeForce NOW và tài liệu
   Windows native.
4. Cập nhật docs architecture/launch handling để ghi rõ policy: không bypass,
   chỉ điều hướng sang nền tảng hỗ trợ.
5. Manual test bằng output mẫu chứa `HoYoKProtect.sys`.

## Rủi Ro Và Ràng Buộc

- GeForce NOW availability thay đổi theo khu vực và tài khoản.
- VM có thể cài được Windows nhưng vẫn fail ở anti-cheat hoặc architecture.
- Link ngoài phải là hướng dẫn, không được biến NSLauncher thành công cụ bypass.
- User có thể hiểu nhầm Parallels là giải pháp chắc chắn; UI cần ghi rõ là
  experimental.

## Kiểm Chứng

- Inject sample stderr chứa `HoYoKProtect.sys` và xác nhận UI hiện recovery
  options thay vì log thô.
- Kiểm tra nút GeForce NOW mở đúng trang.
- Kiểm tra copy tiếng Việt/Anh không hứa Wine/VM bypass được protection.
- `swift build` sau khi implement UI/model.
