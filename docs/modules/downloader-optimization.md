---
title: "Downloader Optimization"
description: "Current design of the manifest and Sophon downloader paths, including concurrency, resume state, verification, and operational constraints."
type: module
status: active
tags: ["downloader", "genshin", "sophon", "manifest"]
owners: ["installer"]
source_paths:
  - "Sources/NSLauncherApp/Services/Installer/ManifestInstaller.swift"
  - "Sources/NSLauncherApp/Services/Installer/GenshinSophonInstaller.swift"
  - "Sources/NSLauncherApp/Services/Installer/InstallTargetPruner.swift"
related:
  - "../architecture.md"
  - "../genshin-install-plan.md"
  - "../specs/planning/optimize-genshin-scatteredfiles-downloads.md"
  - "../specs/planning/optimize-genshin-sophon-downloads.md"
---

# Downloader Optimization

## Meta

- Trạng thái: active
- Phạm vi: downloader tối ưu cho manifest/scattered-file install và Genshin Sophon update
- Nguồn code: `Sources/NSLauncherApp/Services/Installer/ManifestInstaller.swift`, `Sources/NSLauncherApp/Services/Installer/GenshinSophonInstaller.swift`, `Sources/NSLauncherApp/Services/Installer/InstallTargetPruner.swift`
- Tuân thủ: official HoYoPlay metadata, checksum validation, resumable install/update, bounded CDN concurrency
- Links: [Architecture](../architecture.md), [Genshin Install Plan](../genshin-install-plan.md), [Optimize Genshin ScatteredFiles Downloads](../specs/planning/optimize-genshin-scatteredfiles-downloads.md), [Optimize Genshin Sophon Downloads](../specs/planning/optimize-genshin-sophon-downloads.md)

## Tổng Quan

Launcher có hai downloader chính cho install/update dựa trên metadata chính thức:

- `ManifestInstaller` tải từng file từ manifest/scattered-file source vào `<destination>.partial`.
- `GenshinSophonInstaller` tải chunk Sophon nén zstd, dựng lại asset đầy đủ trong `.nslauncher-sophon-staging`, rồi thay thế file đích.

Cả hai path cùng giữ các invariant quan trọng: chỉ dùng source chính thức đã được metadata mô tả, không bỏ checksum, ghi qua staging/partial trước khi thay final file, có checkpoint pause/stop giữa các operation dài, và giới hạn tổng request để không đẩy CDN vào trạng thái throttle quá dễ.

## Manifest Downloader

`ManifestInstaller` dùng cho official streaming/scattered-file source và generic manifest install. Downloader này tối ưu quanh file-level HTTP:

- `maxConcurrentDownloads = 32` worker cùng kéo file từ actor queue.
- `maxActiveRequests = 64` là giới hạn toàn cục cho mọi request đang active, bao gồm full-file stream và segmented byte range.
- `httpMaximumConnectionsPerHost = 64`, `waitsForConnectivity = true`, và `reloadIgnoringLocalCacheData` được đặt trong URLSession configuration.
- File được sort lớn trước trong `FileWorkQueue` để tránh cuối lượt còn một asset rất lớn kéo dài toàn bộ install.

File dưới `32 MiB` đi qua streaming resume path. Nếu có `.partial`, downloader gửi `Range: bytes=<offset>-`. Nếu server bỏ qua range và trả `200`, launcher reset partial về 0 và tải lại từ đầu để tránh nối nhầm payload.

File từ `32 MiB` trở lên đi qua segmented path:

- `segmentSize = 16 MiB`.
- Mỗi file chạy tối đa `4` segment song song trong một batch.
- Mỗi segment dùng HTTP `Range` và yêu cầu response `206 Partial Content`.
- Partial file được truncate tới expected size trước, rồi từng segment ghi vào offset cuối cùng.
- State resume nằm ở `<destination>.partial.segments.json`, gồm file size, segment size, segment count và danh sách segment đã hoàn tất.

Downloader không dùng `session.bytes(for:)` theo từng byte. Cả full-file stream và segmented range đều dùng `ManifestChunkDownloadDelegate`, nhận `Data` chunk qua `URLSessionDataDelegate.didReceive`, ghi trực tiếp vào `FileHandle`, và chỉ emit progress theo block tối thiểu `1 MiB`. Điều này giảm overhead CPU/UI so với vòng lặp byte-by-byte, nhất là khi manifest có nhiều file trung bình và file lớn.

## Manifest Verification Và Resume

Trước khi tải, final file hiện có được check theo size và hash nếu metadata cung cấp `md5` hoặc `sha256`. File đã match được tính vào progress và không tải lại. Final file sai size/hash bị xóa trước khi dựng partial mới, vì patch trực tiếp một file đích mismatch không an toàn.

Sau khi tải xong, downloader verify:

- partial size phải bằng manifest size;
- MD5 nếu official metadata có MD5;
- SHA-256 nếu generic manifest có SHA-256;
- expected executable phải tồn tại trước khi ghi `.nslauncher-install.json`.

Transient network errors được retry bằng vòng lặp resume. Backoff được sleep theo lát `250 ms`, có gọi `OperationController.checkpoint()` giữa các lát để pause/stop không bị kẹt trong retry delay.

## Sophon Downloader

`GenshinSophonInstaller` dùng cho Genshin update hiện tại qua HoYoPlay Sophon metadata. Path này khác manifest downloader vì unit tải là chunk nén, còn unit verify/thay thế cuối cùng là asset.

Pipeline hiện tại:

1. Fetch `getGameBranches` và `getBuild`.
2. Chọn manifest `game` và voice mặc định `en-us`.
3. Tải manifest protobuf nén zstd, verify compressed size, decompress, verify manifest MD5, rồi decode asset/chunk.
4. Plan delta bằng cách so local file size và asset MD5.
5. Prune file không còn nằm trong target manifest.
6. Với mỗi changed asset, tạo staging file `.nslauncher-sophon-staging/<matchingField>/<asset>.partial`.
7. Tải chunk, decompress zstd, verify decompressed size và chunk MD5, ghi vào offset đã khai báo.
8. Verify MD5 toàn asset và atomic move vào path đích.

Concurrency được tách thành hai lớp:

- `maxConcurrentAssets = 4` asset workers lấy việc từ `SophonAssetQueue`.
- `maxConcurrentChunksPerAsset = 12` chunk tasks trong mỗi asset.
- `maxActiveChunkRequests = 48` là limiter toàn cục để tổng chunk HTTP request không vượt cap dù nhiều asset cùng chạy.

Queue sort asset lớn trước theo compressed bytes, giống manifest path, để giảm nguy cơ tail latency khi cuối update còn một asset nặng.

## Sophon Decompression Và Write Path

Đường chính của zstd là in-process qua `dlopen`:

- thử `/opt/homebrew/lib/libzstd.dylib`;
- thử `/usr/local/lib/libzstd.dylib`;
- thử `libzstd.dylib` theo dynamic loader path.

Nếu load được `ZSTD_decompress` và `ZSTD_isError`, launcher decompress thẳng từ compressed `Data` sang buffer expected size. Nếu libzstd không có hoặc zstd báo lỗi, path fallback gọi CLI `zstd` qua `ProcessRunner`. CLI chỉ là fallback compatibility, không phải path tối ưu, vì spawn process theo chunk quá đắt với Sophon manifest có hàng chục nghìn chunk.

Mỗi asset có `SophonAssetWriter` actor giữ `FileHandle` mở trong suốt thời gian dựng staging file. Actor serialize `seek + write` theo asset, nên các chunk có thể tải/decompress song song nhưng write vào cùng file vẫn không race. Khi asset xong hoặc lỗi, writer được close rõ ràng.

## Sophon Resume State Và Progress

Resume sidecar Sophon nằm cạnh staging file dưới dạng `<staging>.chunks.json`. State chỉ được reuse khi asset path, asset MD5 và asset size khớp metadata hiện tại; nếu không, launcher coi như chưa có chunk nào hoàn tất.

State không flush sau từng chunk. `installPendingChunks` giữ completed set trong memory và save sau mỗi `64` chunk hoàn tất, cộng thêm một lần cuối asset. Trade-off hiện tại là nếu app crash giữa hai lần save, launcher có thể tải lại tối đa một batch chunk, đổi lại giảm mạnh atomic JSON write và metadata I/O trên asset có hàng nghìn chunk.

`SophonProgressTracker` tính progress theo compressed bytes vì tổng download plan là compressed size. Nó batch event theo một trong các điều kiện:

- tăng thêm ít nhất `4 MiB`;
- hoặc đã qua `0.25 s` từ lần emit trước;
- hoặc download đã chạm tổng bytes.

Existing assets và completed chunks từ resume state vẫn được register vào progress để resumed run không bắt đầu từ 0.

## Pruning Và Atomicity

Cả manifest update và Sophon update đều gọi `InstallTargetPruner.pruneBeforeApplyingTarget` trước khi tải delta. Pruner xóa file trong install root không còn thuộc target manifest, nhưng bảo vệ Wine prefix và các file metadata/staging/resume của launcher.

Atomicity được giữ theo cấp file:

- manifest path ghi vào `.partial`, verify rồi move vào final path;
- Sophon path ghi vào `.nslauncher-sophon-staging`, verify full asset MD5 rồi move vào final path;
- install metadata `.nslauncher-install.json` chỉ được ghi sau khi expected executable tồn tại.

Nếu update bị stop hoặc lỗi giữa chừng, final file đã verify trước đó vẫn ở path đích; partial/staging sidecar giữ đủ thông tin để lần sau resume phần chưa xong.

## Tuning Hiện Tại

Các giá trị đang dùng là default trong code, chưa có UI setting:

| Path | Setting | Giá trị | Ý nghĩa |
| --- | --- | ---: | --- |
| Manifest | `maxConcurrentDownloads` | 32 | số worker kéo file |
| Manifest | `maxActiveRequests` | 64 | tổng HTTP request full/range |
| Manifest | `segmentedDownloadThreshold` | 32 MiB | file từ ngưỡng này dùng parallel ranges |
| Manifest | `segmentSize` | 16 MiB | kích thước mỗi byte range |
| Manifest | `maxSegmentsPerFile` | 4 | segment song song tối đa cho một file |
| Manifest | delegate progress interval | 1 MiB | giảm event churn từ URLSession chunks |
| Sophon | `maxConcurrentAssets` | 4 | asset workers |
| Sophon | `maxConcurrentChunksPerAsset` | 12 | chunk tasks trong một asset |
| Sophon | `maxActiveChunkRequests` | 48 | tổng chunk HTTP request |
| Sophon | `stateFlushChunkCount` | 64 | batch save chunk resume state |
| Sophon | progress byte threshold | 4 MiB | batch progress theo compressed bytes |
| Sophon | progress time threshold | 0.25 s | batch progress theo thời gian |

Khi cần tune tiếp, ưu tiên đo throughput, retry count, HTTP status, CPU decompression và write time theo subset nhỏ trước. Tăng request cap không phải lúc nào cũng nhanh hơn; nếu CDN trả nhiều timeout, 429 hoặc 5xx, giảm cap/adaptive policy sẽ an toàn hơn tăng thẳng.

## Failure Modes

Các lỗi được xem là transient và có retry:

- manifest streaming/range: network lost, offline, timeout, cannot connect/find host, DNS lookup failed, secure connection failed và các lỗi URL loading tương tự trong `NSURLErrorDomain`;
- Sophon chunk: timeout, cannot find/connect host, network lost, DNS lookup failed, offline/data not allowed, và chunk invalid transient trong giới hạn retry ngắn.

Các lỗi không nên retry vô hạn:

- manifest final checksum mismatch;
- Sophon decompressed chunk MD5 mismatch sau retry;
- Sophon final asset MD5 mismatch;
- manifest protobuf/checksum không hợp lệ;
- expected executable không tồn tại sau khi pipeline báo xong.

Những lỗi này thường chỉ ra metadata không khớp, file bị corrupt lặp lại, source upstream thay đổi, hoặc bug write-path; retry vô hạn sẽ che vấn đề và làm tốn băng thông.

## Validation

Validation tối thiểu cho thay đổi downloader:

- `swift build` để đảm bảo actor/delegate/sendable path compile.
- Manifest smoke test với một file nhỏ, một file `32-63 MiB`, một file `>=128 MiB`, có stop/resume giữa chừng.
- Sophon smoke test trên một nhóm asset giới hạn, có asset nhiều chunk và asset đã tồn tại đúng MD5 để verify skip path.
- Kiểm tra partial/sidecar sau stop: `.partial.segments.json` và `.chunks.json` phải resume đúng, không double-count progress.
- Verify final installed executable và `.nslauncher-install.json` chỉ xuất hiện sau khi validation xong.
