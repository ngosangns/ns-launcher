# Triển Khai Genshin Sophon Update

## Trạng Thái

Đã triển khai MVP trong source code. Update Genshin hiện chọn `GenshinSophonInstaller` khi game dùng `streamingManifest`: service fetch `getGameBranches`, fetch Sophon `getBuild`, tải manifest `game` + voice `en-us`, giải nén zstd, decode protobuf bằng decoder Swift nhỏ, lập delta theo size + asset MD5 để resolve file đã có, chỉ đưa asset thiếu/sai checksum vào queue tải chunk, tải chunk bằng URLSession high-concurrency có global request limiter, giải nén chunk bằng libzstd in-process, verify chunk MD5, ghi theo offset vào staging file qua writer giữ file handle mở, verify asset MD5, rồi replace atomic và ghi `.nslauncher-install.json`.

MVP chưa dùng `SwiftProtobuf`; thay vào đó dùng decoder protobuf tối thiểu cho các field Sophon đang cần. Đường chính dùng `libzstd` in-process qua runtime `dlopen`; binary `zstd` chỉ còn là fallback khi in-process decompress không dùng được.

## Bối Cảnh

Genshin Global live đã không còn update bằng `ScatteredFiles/pkg_version` cũ. Kiểm tra ngày 2026-05-10 cho thấy:

- `getGamePackages?launcher_id=VYTpXlbWo8` vẫn trả `hk4e_global` version `5.5.0`.
- `getGameBranches?game_ids[]=gopR6Cufr3&launcher_id=VYTpXlbWo8` trả live branch `tag = 6.5.0`, `package_id = ScSYQBFhu9`.
- Sophon `getBuild` hoạt động với `branch=main`, `package_id=ScSYQBFhu9`, `password` từ branch response, và `plat_app=ddxf6vlr1reo`; response trả 5 manifest: game resource và 4 voice packs.
- Manifest Sophon là zstd-compressed protobuf. Manifest game hiện có khoảng 2,468 files, 97,332 chunks, khoảng 113 GB decompressed; voice `en-us` khoảng 170 files, 13,687 chunks, khoảng 16 GB decompressed.

Repo hiện có `ManifestInstaller` cho file-level URL trực tiếp. Flow đó không thể áp dụng trực tiếp cho Sophon vì mỗi file phải được dựng từ nhiều chunk đã nén zstd, ghi theo offset, verify chunk MD5 và file MD5 trước khi move vào install directory.

## Mục Tiêu

- Thêm backend update/install mới cho Genshin Sophon chunk metadata.
- Update được install hiện tại từ 5.5.x lên live 6.x mà không báo sai `up to date`.
- Ưu tiên đường an toàn: tải full target chunks cho files thiếu/sai checksum, dựng file vào staging/partial, verify rồi replace atomic.
- Reuse UI update log/progress/pause/stop hiện có càng nhiều càng tốt.
- Giữ `ScatteredFiles/pkg_version` path làm legacy fallback nếu HoYoPlay trả file-level manifest hợp lệ trong tương lai.

## Ngoài Phạm Vi

- Chưa implement Sophon patch/diff build trong MVP. `diff_tags` hiện chỉ có 6.4.0 và 6.3.0, không giúp trực tiếp cho local 5.5.0.
- Chưa tự chạy HoYoPlay official launcher trong Wine.
- Chưa hỗ trợ tải mọi voice language cùng lúc. MVP chọn game resource + một voice language.
- Chưa tối ưu cache chunk dùng chung giữa nhiều file nếu chưa cần để update chạy đúng.

## Thiết Kế Hiện Tại

`GenshinSophonInstaller` gộp metadata service và installer trong một actor để giữ pipeline update nhỏ gọn. Actor fetch branch từ `getGameBranches`, fetch build từ Sophon `getBuild`, chọn category `game` và voice mặc định `en-us`, tải manifest protobuf nén zstd, verify compressed size, giải nén, verify manifest MD5, rồi decode các field asset/chunk bằng decoder Swift tối thiểu.

Sophon không được ép vào `RemoteGameFile` vì mỗi asset có nhiều chunk nén. `GameUpdatePlan` vì vậy có `sourceKind = sophon`, `sophonTargetAssets`, `sophonAssetsToWrite`, `sophonSkippedAssets`, `bytesToDownload` theo compressed bytes, và `decompressedBytesToWrite` theo kích thước asset cuối cùng. Delta skip asset khi file local đúng size và asset MD5; asset thiếu hoặc mismatch đi vào queue dựng lại.

Update ghi qua `.nslauncher-sophon-staging`, giữ `SophonAssetWriter` mở file handle theo asset, tải chunk qua URLSession high-concurrency, giới hạn tổng request bằng limiter 48, giải nén chunk bằng `libzstd` in-process, verify decompressed chunk MD5, ghi theo offset, batch sidecar state mỗi 64 chunk, verify MD5 toàn asset, rồi atomic replace vào install root. Trước khi tải delta, `InstallTargetPruner` xóa file không còn trong target manifests nhưng bảo vệ Wine prefix, metadata, staging và partial/resume files.

`LauncherCoordinator.fetchUpdatePlan` chọn Sophon cho bundled Genshin `streamingManifest`. Manifest `pkg_version` cũ vẫn là fallback legacy khi cần, nhưng current Genshin 6.x update đi qua Sophon branch metadata. `LauncherViewModel` dùng cùng update flow/progress surface, thêm log riêng cho update để ghi strategy, install root, installed/latest version, delta bytes, sample changed assets, pause/stop, milestones, verify, metadata write và lỗi.

### Voice Language

MVP default `en-us` vì đó là category voice global phổ biến và đã xác minh manifest. Sau MVP:

- thêm `voiceLanguage` vào `AppSettings`
- Settings segmented/menu: English, Chinese, Japanese, Korean
- Nếu install folder đã có voice folder rõ ràng, auto-select folder đó
- Nếu không rõ, dùng `en-us`

### File Xóa Không Còn Dùng

Trước khi tải chunk mới, launcher prunes các file trong install root không còn xuất hiện trong selected target manifests. Cleanup giữ lại `.nslauncher-install.json`, staging folder của launcher, resumable partial/state files và Wine prefix để không làm hỏng runtime hoặc resume. Sophon patch/diff metadata vẫn là follow-up, nhưng full-build target manifest hiện đã đủ để dọn stale files theo file set đã chọn.

## Việc Còn Lại Sau MVP

1. Bundle hoặc quản lý rõ runtime `libzstd` để app độc lập hơn trên máy không có Homebrew/system lib.
2. Thêm setting voice language thay vì hardcode `en-us`.
3. Nghiên cứu `getPatchBuild`/`SophonPatchProto` để update diff 6.x -> 6.x tối ưu hơn.
4. Thêm smoke/integration tests cho decoder protobuf, zstd fixture, resume sidecar và asset writer.
4. Bổ sung test fixture chính thức trong repo thay vì chỉ validation command tạm.

## Rủi Ro Và Ràng Buộc

- Full Sophon update có thể tải rất nhiều dữ liệu nếu local 5.5.0 khác xa 6.5.0; cần log byte estimate rõ trước khi chạy.
- Disk cần staging ít nhất bằng file lớn nhất đang dựng, nhưng nếu chạy nhiều asset song song thì peak temp tăng theo tổng file đang active; plan phải tính conservative.
- `plat_app=ddxf6vlr1reo` đã xác minh hoạt động cho global PC Sophon build, nhưng chưa thấy trong `getGameBranches`; nên giữ thành constant có log rõ và fail actionable nếu endpoint đổi.
- zstd/protobuf dependency làm build graph phức tạp hơn; cần pin version và validation trên macOS arm64.
- MD5 chunk là hash của dữ liệu sau decompress; phải verify chunk trước khi coi sidecar chunk complete.
- Pause/stop cần checkpoint giữa chunk download, decompress và file write để không kẹt UI.

## Kiểm Chứng

- Unit test version/category selection bằng JSON fixture từ `getGameBranches` và `getBuild`.
- Unit test protobuf decode bằng một manifest sample nhỏ hoặc downloaded fixture đã cắt gọn.
- Unit test zstd decompress fixture.
- Unit test plan skip/download bằng temp install folder có file đúng/sai MD5.
- Integration dry-run: fetch live `6.5.0` metadata, decode manifests, assert có `GenshinImpact.exe` và `GenshinImpact_Data/app.info`.
- Safe download test với 1-2 asset nhỏ như `pkg_version`/small config asset vào temp folder, verify chunk MD5 và final MD5.
- `swift build`.
- Manual app test: Update Game log hiển thị Sophon build `6.5.0`, categories selected, bytes estimate, and can pause/stop without corrupting final files.

## Nguồn Tham Chiếu

- Hi3Helper.Sophon documents Sophon as HoYoverse's chunk download method and states it downloads files in several chunks to reduce disk amplification.
- Hi3Helper.Sophon `SophonManifestProto.proto` defines the manifest asset/chunk fields needed by this launcher.
- SwiftProtobuf provides the Swift protobuf runtime and `protoc-gen-swift` flow needed for generated `.pb.swift` files.
- facebook/zstd is the reference implementation for the zstd compression format used by Sophon manifests/chunks.
