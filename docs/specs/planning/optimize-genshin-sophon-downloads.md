# Tối Ưu Tốc Độ Tải Genshin Sophon

## Bối Cảnh

Genshin update hiện đã chuyển sang Sophon full-build metadata. Live manifest ngày 2026-05-10 trả build `6.5.0`, package `ScSYQBFhu9`. Manifest `game` có 2,468 assets, 97,332 chunks, khoảng 109.9 GB compressed và 113.1 GB decompressed. Manifest `en-us` có 170 assets, 13,687 chunks, khoảng 16.1 GB compressed. Kích thước chunk khá nhỏ: p50 khoảng 1.1 MB, p90 khoảng 1.5 MB, p99 khoảng 2.1 MB.

Trước tối ưu, `GenshinSophonInstaller` chạy `maxConcurrentAssets = 2` và `maxConcurrentChunksPerAsset = 4`, dùng `URLSession.shared`, tải từng chunk bằng `session.data(from:)`, gọi binary `zstd` riêng cho từng chunk, mở/đóng `FileHandle` mỗi chunk, emit progress mỗi chunk, và ghi sidecar JSON state sau mỗi chunk hoàn tất. Với hơn 111k chunks cho `game + en-us`, các overhead per-chunk này đủ lớn để làm tốc độ thực tế thấp hơn nhiều so với băng thông mạng.

Trạng thái sau triển khai: Sophon dùng URLSession high-concurrency, global request limiter 48 chunk requests, 4 asset workers x 12 chunk tasks per asset, libzstd in-process qua runtime `dlopen`, writer actor giữ staging file handle mở theo asset, resume state flush mỗi 64 chunks, progress batching theo byte/time threshold, và retry ngắn cho lỗi tải chunk transient.

`ManifestInstaller` đã có một số pattern nhanh hơn: URLSession cấu hình nhiều connection, request limiter, segmented streaming write, progress batching và retry. Sophon đã port các phần phù hợp: high-concurrency session, request limiter, progress batching và retry chunk transient.

## Mục Tiêu

- Tăng tốc tải Sophon update bằng cách nâng concurrency thực tế và giảm overhead per-chunk.
- Giữ nguyên tính an toàn: verify decompressed chunk MD5, verify final asset MD5, ghi vào staging rồi atomic replace.
- Giữ pause/stop/resume hoạt động ổn định.
- Log tốc độ rõ hơn để biết đang nghẽn ở network, decompression hay disk write.

## Ngoài Phạm Vi

- Không đổi logic chọn manifest Sophon hoặc voice language trong task này.
- Không implement Sophon patch/diff update.
- Không bỏ checksum validation.
- Không tải lại file đã match local size + MD5.

## Kết Luận Research

Các cổ chai chính theo thứ tự ưu tiên:

1. `zstd` shell-out theo từng chunk: mỗi chunk tạo temp dir, ghi input `.zst`, spawn process, đọc output. Với hơn 111k chunks, đây là overhead lớn nhất và có thể làm mạng rảnh trong lúc CPU/process/disk bận.
2. Concurrency thấp và bị giới hạn theo asset: hiện tối đa khoảng 8 chunk requests trên lý thuyết, lại dùng `URLSession.shared` thay vì session high-concurrency. Với chunk p50 khoảng 1.1 MB, cần nhiều in-flight requests hơn để saturate CDN.
3. Ghi sidecar state sau từng chunk: mỗi chunk atomic-write JSON chứa danh sách completed chunks đang tăng dần. Với asset nhiều chunk, chi phí này tăng theo thời gian và tạo rất nhiều metadata I/O.
4. Mở/đóng file cho từng chunk: mỗi chunk mở staging file, seek, write, close. An toàn nhưng tốn syscall và làm disk write kém mượt.
5. Progress/log phát mỗi chunk: UI đã throttle một phần ở ViewModel, nhưng installer vẫn gọi event cho từng chunk. Với hàng trăm nghìn chunk, MainActor và string formatting vẫn bị kéo vào pipeline.

## Hướng Tiếp Cận Đề Xuất

### 1. Tạo Sophon Download Session Và Global Request Limiter

Thêm cấu hình tương tự `ManifestInstaller`:

- `httpMaximumConnectionsPerHost = 64`
- `waitsForConnectivity = true`
- `requestCachePolicy = .reloadIgnoringLocalCacheData`
- global `DownloadRequestLimiter` dùng chung cho mọi chunk, mặc định 48 hoặc 64 requests.

Không chỉ tăng `maxConcurrentChunksPerAsset`; cần chuyển sang limiter global để nhiều asset nhỏ và lớn cùng chia slots, tránh asset hiện tại quyết định toàn bộ throughput.

### 2. Đổi Scheduler Từ Asset-Local Sang Global Chunk Pipeline

Giữ asset lifecycle và final verify, nhưng scheduling chunk nên dùng hàng đợi global:

- Asset workers chuẩn bị staging, load completed state, đăng ký asset đang active.
- Chunk workers toàn cục kéo `SophonChunkJob` từ queue với `asset`, `chunk`, `stagingURL`.
- Giới hạn download, decompress và write bằng limiter riêng nếu cần:
  - network cap: 48-64
  - decompression cap: theo CPU, ví dụ 4-8
  - per-asset write serialization: một actor writer cho mỗi staging file

Cách này tận dụng CDN tốt hơn mà vẫn không ghi đè loạn offset trong cùng một file.

### 3. Thay `zstd` Per Chunk Bằng In-Process Decompressor

Ưu tiên tạo C target wrapper quanh libzstd:

- thêm vendored/minimal `zstd` hoặc dependency đã pin trong SwiftPM
- expose hàm Swift `decompress(data:expectedSize:) -> Data`
- verify expected decompressed size trước MD5

Nếu chưa muốn đưa libzstd ngay, fallback tạm có thể là batch/pool process, nhưng đó chỉ là bước chuyển tiếp. In-process zstd là fix đúng vì Sophon chunk count rất lớn.

### 4. Batch Resume State

Không ghi `.chunks.json` sau từng chunk. Thay bằng:

- giữ completed set trong memory
- flush state khi một trong các điều kiện xảy ra:
  - thêm 32 hoặc 64 chunks mới
  - quá 1 giây từ lần flush trước
  - pause/stop/checkpoint
  - asset hoàn tất

Khi crash giữa hai lần flush, tối đa tải lại vài chục chunk, đổi lại giảm rất mạnh metadata I/O.

### 5. Giữ FileHandle Mở Theo Asset

Tạo `SophonAssetWriter` actor:

- mở `FileHandle` một lần cho staging file
- serialize `seek + write` theo asset
- close khi asset hoàn tất hoặc lỗi

Điều này giữ an toàn cho write offset và giảm open/close mỗi chunk.

### 6. Batch Progress Và Log

Đổi `SophonProgressTracker` để aggregate bytes và emit theo ngưỡng:

- mỗi 512 KB hoặc 1 MB
- hoặc mỗi 250 ms
- vẫn emit ngay khi asset begin/verify/finished

Log thêm các dòng tổng quan:

- network concurrency cap
- decompression concurrency cap
- completed chunk count / total chunk count
- average throughput window
- nếu có thể, thời gian download/decompress/write/checksum để tìm nghẽn thật.

### 7. Retry Cho Chunk Download

Hiện chunk download fail là fail cả update. Thêm retry giống manifest:

- retry transient `URLError.networkConnectionLost`, timeout, DNS temporary, 5xx, 429
- exponential hoặc fixed backoff ngắn, có checkpoint pause/stop
- không retry checksum mismatch vô hạn; retry 1-2 lần rồi báo lỗi.

## Công Việc Cần Làm

1. Đã tách các hằng số tuning trong `GenshinSophonInstaller`: asset workers, per-asset chunk cap, global request cap, state flush chunk count, progress flush byte/time.
2. Đã thêm high-concurrency `URLSession` và request limiter cho Sophon.
3. Đã tăng scheduling thực tế lên tối đa 48 chunk requests qua 4 asset workers và 12 chunk tasks mỗi asset; global queue thuần vẫn là follow-up nếu cần tinh chỉnh thêm fairness giữa asset.
4. Đã thêm `SophonAssetWriter` actor giữ file handle mở và serialize writes theo asset.
5. Đã batch-save completed chunks mỗi 64 chunks và flush cuối asset.
6. Đã thay đường chính của `ZstdDecompressor` bằng in-process libzstd wrapper; CLI `zstd` chỉ còn fallback.
7. Đã throttle `SophonProgressTracker` để giảm event/UI churn.
8. Đã thêm retry cho chunk download với lỗi transient.
9. Đã cập nhật update log để hiển thị downloader high-concurrency, in-process zstd và batched resume state.
10. Đã cập nhật docs sau triển khai.

## Rủi Ro Và Ràng Buộc

- Tăng concurrency quá cao có thể bị CDN throttle, timeout hoặc làm máy nóng. Cần chọn default bảo thủ, ví dụ 48 requests, và dễ giảm nếu thấy lỗi.
- In-process zstd phụ thuộc `libzstd` có sẵn ở runtime; nếu không có, launcher fallback sang binary `zstd`. Packaging sau này nên bundle lib hoặc runtime tool rõ ràng.
- Ghi parallel vào cùng staging file phải serialize theo asset, nếu không có nguy cơ corrupt file dù offset khác nhau.
- Batch resume state có thể làm tải lại một số chunk sau crash. Đây là trade-off chấp nhận được nếu giới hạn batch nhỏ.
- Hash MD5 final asset vẫn tốn thời gian cho file lớn; không nên bỏ, chỉ log rõ giai đoạn verify để user không tưởng download bị treo.

## Kiểm Chứng

- Unit test `SophonAssetStateBuffer`: flush theo số chunk, theo thời gian, và flush bắt buộc khi stop.
- Unit test `SophonAssetWriter`: ghi nhiều chunk out-of-order vào temp file và verify byte layout.
- Unit test zstd wrapper bằng fixture chunk nhỏ, so sánh decompressed size và MD5.
- Integration test tải một asset nhỏ và một asset nhiều chunk vào temp folder, verify final MD5.
- Regression test skip existing asset: file đã đúng size + MD5 không xuất hiện trong queue tải.
- Throughput smoke test với một nhóm asset giới hạn: log MB/s trước/sau, số requests active, số chunks completed/s.
- `swift build`.

## Acceptance Criteria

- Update Sophon không còn spawn process `zstd` cho từng chunk trong đường chính.
- Chunk download có global request limiter 48 active requests và session cho phép nhiều connection per host.
- Resume state không còn atomic-write JSON sau từng chunk.
- File staging không còn bị mở/đóng cho từng chunk.
- Progress UI được batch theo byte/time threshold, pause/stop vẫn checkpoint giữa chunk operations, và checksum validation vẫn bắt lỗi.
- Với cùng mạng và cùng set asset test, throughput kỳ vọng tăng rõ so với MVP vì đã loại bỏ process spawn, giảm metadata I/O và tăng in-flight chunk requests.
