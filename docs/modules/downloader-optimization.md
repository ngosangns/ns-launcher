---
title: "Downloader Optimization"
description: "Current Sophon-only downloader design, including concurrency, resume state, verification, pruning, and operational constraints."
type: module
status: active
tags: ["downloader", "genshin", "sophon"]
owners: ["installer"]
source_paths:
  - "Sources/NSLauncherApp/Services/Installer/GenshinSophonInstaller.swift"
  - "Sources/NSLauncherApp/Services/Installer/InstallTargetPruner.swift"
related:
  - "../architecture.md"
  - "../genshin-install-plan.md"
  - "../specs/planning/optimize-genshin-sophon-downloads.md"
  - "../specs/planning/sophon-only-download-flow.md"
---

# Downloader Optimization

## Meta

- Trạng thái: active
- Phạm vi: Sophon-only install/update cho bundled Genshin Global
- Nguồn code: `Sources/NSLauncherApp/Services/Installer/GenshinSophonInstaller.swift`, `Sources/NSLauncherApp/Services/Installer/InstallTargetPruner.swift`
- Tuân thủ: official HoYoPlay Sophon metadata, checksum validation, resumable install/update, bounded CDN concurrency
- Links: [Architecture](../architecture.md), [Genshin Install Plan](../genshin-install-plan.md), [Optimize Genshin Sophon Downloads](../specs/planning/optimize-genshin-sophon-downloads.md), [Sophon-only Download Flow](../specs/planning/sophon-only-download-flow.md)

## Tổng Quan

Launcher hiện chỉ dùng Sophon cho install/update Genshin. Các đường tải cũ như archive package, local archive import, generic manifest, và `ScatteredFiles/pkg_version` không còn là product path.

`GenshinSophonInstaller` lấy metadata từ HoYoPlay Sophon, tải manifest `game` và voice mặc định, dựng delta theo asset MD5, tải chunk nén zstd, ghi qua staging file, verify toàn asset, rồi thay thế final file bằng atomic move. Flow này dùng chung cho fresh install và update; fresh install chỉ là delta khi chưa có metadata cũ.

Các invariant chính:

- chỉ dùng official Sophon branch/build metadata;
- không bỏ qua checksum manifest, chunk, hoặc asset;
- không ghi trực tiếp lên final file trước khi verify;
- pause/stop đi qua `OperationController.checkpoint()`;
- giới hạn tổng request để tránh tự gây throttle CDN;
- chỉ ghi `.nslauncher-install.json` sau khi expected executable tồn tại.

## Sophon Pipeline

Pipeline hiện tại:

1. Fetch `getGameBranches` để chọn live Genshin branch.
2. Fetch Sophon `getBuild` cho package hiện hành.
3. Chọn manifest `game` và voice mặc định `en-us`.
4. Tải manifest protobuf nén zstd.
5. Verify compressed size, decompress, verify manifest MD5, rồi decode asset/chunk.
6. Plan delta bằng cách so local file size và asset MD5.
7. Prune file không còn nằm trong target manifest.
8. Với mỗi changed asset, tạo staging file `.nslauncher-sophon-staging/<matchingField>/<asset>.partial`.
9. Tải chunk, decompress zstd, verify decompressed size và chunk MD5, ghi vào offset đã khai báo.
10. Verify MD5 toàn asset và atomic move vào path đích.
11. Ghi install metadata mới.

Metadata cũ có `installMode` legacy vẫn được decode thành Sophon để người dùng không phải xóa settings hoặc reinstall thủ công sau migration.

## Concurrency

Concurrency được tách thành hai lớp:

| Setting | Giá trị | Ý nghĩa |
| --- | ---: | --- |
| `maxConcurrentAssets` | 4 | asset workers lấy việc từ `SophonAssetQueue` |
| `maxConcurrentChunksPerAsset` | 12 | chunk tasks tối đa trong một asset |
| `maxActiveChunkRequests` | 48 | limiter toàn cục cho mọi chunk HTTP request |
| `stateFlushChunkCount` | 64 | batch save chunk resume state |
| progress byte threshold | 4 MiB | batch progress theo compressed bytes |
| progress time threshold | 0.25 s | batch progress theo thời gian |

Queue sort asset lớn trước theo compressed bytes để giảm tail latency khi cuối update còn một asset nặng. Tăng concurrency không luôn nhanh hơn; nếu CDN trả nhiều timeout, 429, hoặc 5xx, hướng đúng là giảm cap hoặc thêm adaptive policy thay vì tăng thẳng request count.

## Decompression Và Write Path

Đường chính của zstd là in-process qua `dlopen`:

- `/opt/homebrew/lib/libzstd.dylib`;
- `/usr/local/lib/libzstd.dylib`;
- `libzstd.dylib` theo dynamic loader path.

Nếu load được `ZSTD_decompress` và `ZSTD_isError`, launcher decompress thẳng từ compressed `Data` sang buffer expected size. Nếu libzstd không có hoặc zstd báo lỗi, path fallback gọi CLI `zstd` qua `ProcessRunner`. CLI chỉ là fallback compatibility vì spawn process theo chunk quá đắt với Sophon manifest có nhiều chunk.

Mỗi asset có `SophonAssetWriter` actor giữ `FileHandle` mở trong suốt thời gian dựng staging file. Actor serialize `seek + write` theo asset, nên các chunk có thể tải/decompress song song nhưng write vào cùng file vẫn không race.

## Resume State Và Progress

Resume sidecar Sophon nằm cạnh staging file dưới dạng `<staging>.chunks.json`. State chỉ được reuse khi asset path, asset MD5, và asset size khớp metadata hiện tại; nếu không, launcher coi như chưa có chunk nào hoàn tất.

State không flush sau từng chunk. `installPendingChunks` giữ completed set trong memory và save sau mỗi `64` chunk hoàn tất, cộng thêm một lần cuối asset. Nếu app crash giữa hai lần save, launcher có thể tải lại tối đa một batch chunk, đổi lại giảm mạnh atomic JSON write và metadata I/O.

`SophonProgressTracker` tính progress theo compressed bytes vì tổng download plan là compressed size. Existing assets và completed chunks từ resume state vẫn được register vào progress để resumed run không bắt đầu từ 0.

## Pruning Và Atomicity

`InstallTargetPruner.pruneBeforeApplyingTarget` chạy trước khi áp dụng Sophon delta. Pruner xóa file trong install root không còn thuộc target manifest, nhưng bảo vệ Wine prefix và các file metadata/staging/resume của launcher.

Atomicity được giữ theo cấp file:

- Sophon path ghi vào `.nslauncher-sophon-staging`;
- full asset phải pass MD5 trước khi move vào final path;
- metadata install chỉ được ghi sau khi expected executable tồn tại.

Nếu update bị stop hoặc lỗi giữa chừng, final file đã verify trước đó vẫn ở path đích; staging sidecar giữ đủ thông tin để lần sau resume phần chưa xong.

## Failure Modes

Các lỗi được xem là transient và có retry ngắn: timeout, cannot find/connect host, network lost, DNS lookup failed, offline/data not allowed, và chunk invalid transient trong giới hạn retry.

Các lỗi không nên retry vô hạn:

- manifest protobuf/checksum không hợp lệ;
- decompressed chunk MD5 mismatch sau retry;
- final asset MD5 mismatch;
- expected executable không tồn tại sau khi pipeline báo xong.

Những lỗi này thường chỉ ra metadata không khớp, file bị corrupt lặp lại, source upstream thay đổi, hoặc bug write path; retry vô hạn sẽ che vấn đề và làm tốn băng thông.

## Validation

Validation tối thiểu cho thay đổi downloader:

- `swift build` để đảm bảo actor/sendable path compile.
- Sophon smoke test trên một nhóm asset giới hạn, có asset nhiều chunk và asset đã tồn tại đúng MD5 để verify skip path.
- Stop/resume giữa asset nhiều chunk để kiểm tra `.chunks.json`.
- Verify final executable và `.nslauncher-install.json` chỉ xuất hiện sau khi validation xong.
