# Tối Ưu Tốc Độ Tải Genshin ScatteredFiles

## Bối Cảnh

Luồng cài đặt hiện tại dùng official `ScatteredFiles/pkg_version` của HoYoPlay để tải từng file lẻ vào install directory qua `.partial`, tránh phải tải split zip lớn rồi extract.

`ManifestInstaller` hiện đã có nhiều tối ưu quan trọng:

- dùng `URLSession`
- đặt `httpMaximumConnectionsPerHost = 64`
- tải các manifest files song song tối đa 32 worker
- sắp xếp file lớn trước
- resume file nhỏ/trung bình bằng HTTP `Range`
- file từ `32 MiB` trở lên được chia thành range `16 MiB`, tối đa `4` segment mỗi file
- giới hạn tổng active HTTP request bằng `DownloadRequestLimiter(maxConcurrentRequests: 64)`
- ghi vào `<destination>.partial`, verify size/checksum nếu có, rồi move vào final path
- persist `<file>.partial.segments.json` để resume segmented file

Vấn đề user báo cáo là tốc độ download từng file vẫn chậm. Khi research, điểm đáng nghi nhất nằm ở implementation network read cũ của `ManifestInstaller`: cả `streamFile` và `downloadSegment` đều dùng `session.bytes(for:)` rồi lặp `for try await byte in bytes`, tức là xử lý từng byte một trước khi gom thành buffer `256 KiB`. Implementation hiện đã chuyển hai path này sang `URLSessionDataDelegate.didReceive data: Data`, nhận chunk `Data` trực tiếp và ghi ngay xuống disk.

## Kết Quả Research Hiện Tại

Code paths liên quan:

- `Sources/NSLauncherApp/Services/Installer/ManifestInstaller.swift`
  - constants download concurrency và segment config ở đầu actor
  - `installFile` chọn segmented hay streaming path
  - `resumeSegmentedFile` tải các segment theo batch
  - `downloadSegment` dùng chunk delegate cho từng byte range
  - `streamFile` dùng chunk delegate cho full/ranged file request
  - `ManifestDownloadProgressTracker` gom progress cho UI
- `Sources/NSLauncherApp/Services/Installer/PackageDownloadService.swift`
  - `RangeDownloadDelegate` là mẫu code chunk-based đang có sẵn trong repo

Docs hiện tại đã mô tả downloader có concurrent file downloads, segmented large files và MD5 verification. Docs không stale về tính năng lớn, nhưng plan cũ cần cập nhật vì segmented downloads đã được implement một phần.

Kiểm tra manifest official tại thời điểm research:

- version trả về: `5.5.0`
- tổng file: `2123`
- tổng bytes: khoảng `76.74 GiB`
- file `>= 16 MiB`: `1135` file, khoảng `74.97 GiB`
- file `>= 32 MiB`: `992` file, khoảng `71.51 GiB`
- file `>= 64 MiB`: `261` file, khoảng `38.97 GiB`
- file `>= 128 MiB`: `144` file, khoảng `27.95 GiB`

Điều này có nghĩa là threshold `64 MiB` cũ để khoảng `32.5 GiB` trong nhóm `32-63 MiB` đi qua single-stream path. Threshold hiện đã được hạ xuống `32 MiB`, nên nhóm này cũng được hưởng segmented ranged download. Nếu per-file speed vẫn chậm sau thay đổi này, bước tiếp theo nên là benchmark và điều chỉnh adaptive policy thay vì chỉ tăng global file concurrency.

## Mục Tiêu

- Tăng throughput từng file, đặc biệt với file `16-63 MiB` và file lớn.
- Giữ official HTTPS/Range path, không dùng mirror/unofficial protocol.
- Giữ resume `.partial` và segmented sidecar đúng.
- Giữ peak disk thấp: không staging archive.
- Giữ progress UI đủ chính xác nhưng không phát event quá dày.
- Không tăng request song song quá mức làm CDN throttle.

## Ngoài Phạm Vi

- Không thêm torrent, FTP, Metalink, rsync, mirror unofficial.
- Không hardcode version/path CDN.
- Không yêu cầu user cài external downloader cho default path.
- Không refactor UI lớn ngoài những thay đổi cần thiết để hiển thị speed/progress đúng.

## Hướng Tiếp Cận Đề Xuất

### Phase 1: Đổi ManifestInstaller sang chunk-based URLSessionDataDelegate

Trạng thái: đã triển khai. `ManifestInstaller` không còn đọc response body bằng `session.bytes(for:)` byte-by-byte cho `streamFile` và `downloadSegment`; các path này đã chuyển sang delegate downloader riêng cho manifest file/range:

- nhận `Data` chunks qua `urlSession(_:dataTask:didReceive:)`
- ghi chunk trực tiếp vào `FileHandle`
- với normal streaming file: append từ `startOffset`
- với segmented range: seek đến `range.start`, ghi chunk liên tiếp trong range
- validate status code `200/206` trong delegate response callback
- bridge completion về async/await bằng continuation giống `PackageDownloadService.RangeDownloadDelegate`
- support cancellation/operation checkpoint để stop/pause không treo
- emit progress theo chunk hoặc throttle theo byte/time để tránh SwiftUI churn

Đây là việc ưu tiên cao nhất vì nó xóa overhead `for try await byte` trên mỗi file và mỗi segment.

### Phase 2: Hạ ngưỡng segmented download cho file trung bình

Trạng thái: đã triển khai bước đầu với threshold `32 MiB`:

- cân nhắc threshold `16 MiB` nếu benchmark cho thấy lợi ích lớn hơn overhead request
- `segmentSize = 16 MiB` để file `32-63 MiB` có 2-4 ranges
- `maxSegmentsPerFile = 4` để tránh tăng request đột ngột
- cap tổng request vẫn là `64`

Nếu benchmark cho thấy per-file speed vẫn bị cap thấp với file rất lớn, tăng `maxSegmentsPerFile` lên `6` hoặc `8` có điều kiện, nhưng chỉ sau khi có số đo lỗi/throughput.

### Phase 3: Tách cấu hình và adaptive policy nhỏ gọn

Nếu Phase 1-2 vẫn chưa đủ, thêm policy adapt nhẹ:

- cấu hình nội bộ cho `maxConcurrentDownloads`, `maxActiveRequests`, `segmentedDownloadThreshold`, `maxSegmentsPerFile`
- giảm active request khi gặp nhiều timeout/429/503/network lost
- tăng chậm lại khi throughput ổn định
- không cần UI setting ngay; default an toàn trong code là đủ cho lần đầu

### Phase 4: Benchmark optional với aria2c

Dùng `aria2c` chỉ như baseline so sánh, không phải default production path:

```text
aria2c --continue=true --max-concurrent-downloads=32 --max-connection-per-server=8 --split=8 --min-split-size=16M --file-allocation=none --input-file=<urls.txt>
```

Nếu native sau Phase 1-2 vẫn kém xa aria2 trên cùng subset, cân nhắc sidecar mode sau.

## Công Việc Cần Làm

1. Đã thêm manifest chunk downloader delegate có thể tải full file hoặc byte range vào offset cụ thể.
2. Đã thay `streamFile` để dùng delegate, giữ resume logic khi server ignore `Range`.
3. Đã thay `downloadSegment` để dùng delegate, giữ segment state và progress accounting hiện có.
4. Đã throttle progress event theo byte threshold để tránh progress/UI churn.
5. Đã hạ segmented threshold xuống `32 MiB`.
6. Cần thêm test cho range request/status validation, resume offset, partial oversize reset và segment completion khi repo có test target.
7. Cần chạy benchmark subset official manifest trước/sau, gồm ít nhất:
   - 1 file `16-31 MiB`
   - 1 file `32-63 MiB`
   - 1 file `>=128 MiB`
   - 20-50 file mixed size

## Rủi Ro Và Ràng Buộc

- Delegate downloader phải đảm bảo continuation resume đúng một lần khi cancel/error/success.
- Segmented writer phải seek và ghi đúng offset; lỗi ở đây có thể tạo file sai nhưng vẫn đúng size, nên checksum MD5 là bắt buộc.
- Nhiều request song song hơn có thể làm CDN throttle; cap global `64` nên được giữ trong lần đầu.
- Progress tracker hiện có logic active segment bytes; khi đổi sang delegate phải giữ semantics "không double-count retry".
- `FileHandle.synchronize()` quá thường xuyên có thể làm chậm; nên sync khi kết thúc task/range, không sync mỗi chunk.
- Worktree hiện đang có nhiều file dirty sẵn; implementation cần tránh revert/chạm vào unrelated changes.

## Kiểm Chứng

- `swift test` nếu thêm test target.
- Nếu repo chưa có test target, thêm test target nhỏ cho downloader logic trước khi thay đổi sâu.
- Manual benchmark với official `ScatteredFiles` subset:
- current baseline trước thay đổi
- chunk delegate + threshold `32 MiB`
- optional aria2 baseline
- Verify downloaded files bằng expected size và MD5 từ `pkg_version`.
- Manual install dry run/resume:
  - stop giữa file nhỏ/trung bình
  - stop giữa segmented file
  - rerun và verify no double-count progress, final executable tồn tại

## Acceptance Criteria

- Downloader không còn xử lý response body theo từng byte trong `ManifestInstaller`.
- Tốc độ từng file trên sample `32-63 MiB` tốt hơn baseline rõ rệt.
- File lớn vẫn segmented và resume đúng qua `.partial.segments.json`.
- Tất cả downloaded files verify bằng size và MD5/SHA-256 nếu có.
- Khi network lỗi, downloader retry/backoff như hiện tại, không busy loop.
- Không tăng peak disk đáng kể và không cần archive staging.
