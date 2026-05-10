# Triển Khai Tính Năng Update Game

## Trạng Thái

Đã triển khai MVP. App có action `Update Game`, lập `GameUpdatePlan` theo delta manifest, kiểm tra file local bằng size và MD5/SHA-256 khi có, tải lại đúng subset file qua pipeline `.partial`/segmented download hiện có, ghi metadata version mới sau update, và báo `up to date` khi không còn việc cần làm.

Genshin update có guard chống nguồn manifest cũ: nếu HoYoPlay `getGamePackages` vẫn trả manifest 5.x trong khi public download porter đã trỏ tới installer 2026 mới hơn, launcher báo stale manifest thay vì kết luận game đã mới nhất.

## Bối Cảnh

`ns-launcher` hiện đã dùng official HoYoPlay streaming metadata cho Genshin Impact. `GenshinStreamingMetadataService` lấy version hiện tại và đọc `pkg_version` thành `RemoteGameManifest`. `ManifestInstaller` đã có nền tảng quan trọng cho update: mỗi file được tải trực tiếp vào install directory qua `.partial`, file đúng size/hash được bỏ qua, file sai size bị xóa và tải lại, file lớn dùng ranged segmented download, và metadata `.nslauncher-install.json` được ghi sau khi install xong.

Điểm thiếu là product flow update riêng. UI hiện chỉ có `Download & Install`, nên người dùng không biết đang fresh install, repair hay update. Plan install hiện cũng ước tính toàn bộ manifest size thay vì chỉ phần cần tải, nên không phù hợp để hiển thị update size. Metadata đã có trường `version`, nhưng chưa có logic đọc/so sánh installed version với latest manifest version để quyết định trạng thái.

Docs hiện tại xem `repair mode`, `persist and compare installed version metadata` là remaining work. Tính năng update nên xử lý cả hai phần đó ở mức MVP: biết local version, biết latest version, tính delta cần tải, tải thiếu/sai/cũ, và ghi metadata version mới.

## Mục Tiêu

- Thêm action update game rõ ràng cho Genshin streaming install.
- Phân biệt trạng thái:
  - chưa cài hoặc thiếu executable: cài mới
  - đã cài cùng version và file hợp lệ: up to date
  - local version khác latest hoặc có file thiếu/sai: update/repair
- Tính update plan theo delta thực tế thay vì tổng dung lượng manifest.
- Tải lại chỉ file thiếu, sai size, sai checksum hoặc chưa có.
- Giữ toàn bộ lợi ích hiện tại: `.partial` resume, segmented download, MD5/SHA-256 verify, progress speed/ETA, stop/pause.
- Ghi `.nslauncher-install.json` với version latest sau update thành công.

## Ngoài Phạm Vi

- Không triển khai HoYo patch diff binary format riêng nếu official `pkg_version` đã đủ cho file-level update.
- Không thêm updater cho Wine/DXMT runtime trong scope này.
- Không thêm multi-game update queue.
- Không thêm background scheduler/auto-update.
- Không thêm UI phức tạp như changelog, release notes hoặc channel selector.

## Hướng Tiếp Cận Đề Xuất

### 1. Thêm model trạng thái update

Thêm các model nhỏ trong Domain hoặc service layer:

- `InstalledGameMetadata` đã có sẵn, cần helper đọc metadata từ install directory.
- `GameUpdateStatus`:
  - `notInstalled`
  - `upToDate(version: String)`
  - `updateAvailable(installedVersion: String?, latestVersion: String, bytesToDownload: Int64, filesToDownload: Int)`
  - `repairRequired(version: String?, bytesToDownload: Int64, filesToDownload: Int)`
- `GameUpdatePlan` hoặc mở rộng `InstallPlan` để chứa:
  - latest version
  - installed version nếu có
  - files cần tải
  - bytes cần tải
  - files đã đúng và được skip

Không nên chỉ dựa vào version string. Nếu version bằng nhau nhưng file thiếu/sai checksum, update status phải là repair required.

### 2. Tách manifest delta planning khỏi install toàn bộ

`ManifestInstaller.planInstall(for:manifest:)` hiện tính tổng bytes của mọi file. Cần thêm API mới, ví dụ:

```swift
func planDelta(for game: GameDefinition, manifest: RemoteGameManifest) async throws -> ManifestDeltaPlan
```

Delta logic:

- Với mỗi `RemoteGameFile`, kiểm tra destination.
- Nếu destination không tồn tại: cần tải.
- Nếu size khác expected: cần tải.
- Nếu có MD5/SHA-256 và size đúng:
  - Với update status/manual check, verify hash để phát hiện file corrupted.
  - Có thể giới hạn hash check ban đầu bằng policy để tránh scan toàn bộ 70+ GiB quá lâu, nhưng MVP update nên ưu tiên đúng hơn nhanh.
- Nếu `.partial` tồn tại, tính bytes còn lại dựa trên normalized partial/segment state để plan download size tốt hơn, nhưng acceptance tối thiểu là estimated bytes bằng tổng size files cần tải.

`ManifestInstaller.install(...)` hiện đã skip file đúng size. Nên sau delta planning, có hai lựa chọn:

1. truyền toàn bộ manifest vào install như hiện tại, đơn giản và an toàn vì `installFile` skip file đúng size;
2. truyền subset files cần update để progress total không tính file skipped.

Đề xuất MVP dùng subset files cần update để UI progress đúng và nhanh hơn. Nếu subset rỗng, không chạy install, chỉ báo up to date.

### 3. Thêm service boundary trong LauncherCoordinator

Thêm methods:

- `fetchUpdatePlan(for:settings:)`
  - fetch latest manifest theo strategy:
    - `.streamingManifest`: dùng `GenshinStreamingMetadataService`
    - `.manifest`: dùng `ManifestInstaller.fetchManifest`
    - `.archivePackage`: ngoài scope hoặc báo unsupported cho update file-level
  - đọc installed metadata
  - gọi `ManifestInstaller.planDelta`
- `updateGame(_:settings:operationController:onEvent:)`
  - fetch latest manifest
  - build delta
  - nếu không có file cần tải: emit finished/up-to-date event hoặc return status
  - gọi manifest installer với subset files cần tải

Tên API nên tránh gắn Genshin quá sâu để sau này generic manifest games cũng update được.

### 4. UI action và trạng thái

Thêm button `Update Game` hoặc đổi label động cho button install:

- Nếu chưa có metadata/executable: `Download & Install`
- Nếu có installed metadata: `Update Game`
- Nếu plan cho thấy up-to-date: button có thể vẫn enabled để `Check for Updates`, hoặc label riêng `Check Updates`.

Đề xuất MVP:

- Thêm button riêng `Update Game` cạnh `Download & Install`.
- Disable khi busy hoặc khi game strategy không hỗ trợ update.
- Khi bấm:
  - status: `Checking for updates...`
  - fetch plan
  - nếu up-to-date: status `Game is up to date`
  - nếu có update/repair: chạy tải subset, progress hiển thị số file/bytes cần tải

Không cần dialog xác nhận ở MVP; update là thao tác rõ ràng và resumable giống install.

### 5. Progress và event text

Có thể reuse `InstallProgressEvent` hiện tại, nhưng cần thêm text:

- `checkingUpdates`
- `gameUpToDate(version:)`
- `updating(gameName:)`
- `updateCompleted(version:)`
- `updateFailed`
- `updatePlanSummary(installed/latest/download/files)`

Nếu thêm event mới, giữ nó generic:

- `checkingUpdates(version: String?)`
- hoặc không cần event mới, ViewModel tự set status trước khi gọi coordinator.

### 6. Metadata và version comparison

`InstalledGameMetadata.version` là source chính cho local version. Nếu metadata thiếu nhưng executable tồn tại, status là `repairRequired(version: nil)` hoặc `notInstalled` tùy product copy. Với Genshin streaming install, nên coi là repair/update path để không bắt user tải lại toàn bộ nếu file đã có.

Sau update thành công, metadata cần:

- `gameID`
- `installMode`
- `installedAt` hoặc đổi nghĩa thành lastUpdatedAt nếu giữ field cũ
- `version: latest`
- `executableRelativePath`

Không cần đổi schema ngay; `installedAt` có thể là thời điểm lần ghi metadata gần nhất.

## Công Việc Cần Làm

1. Hoàn tất helper đọc `.nslauncher-install.json` an toàn.
2. Hoàn tất model `GameUpdatePlan`.
3. Hoàn tất `ManifestInstaller.planUpdate(...)`.
4. Hoàn tất overload `ManifestInstaller.install(...)` nhận subset `[RemoteGameFile]`.
5. Hoàn tất `LauncherCoordinator.fetchUpdatePlan(...)` và `updateGame(...)`.
6. Hoàn tất state/action `updateSelectedGame()` trong `LauncherViewModel`.
7. Hoàn tất localized strings cho update/check/up-to-date/failure.
8. Hoàn tất button `Update Game` trong `ContentView`, chỉ enable cho `.streamingManifest` và `.manifest`.
9. Hoàn tất progress detail để update dùng bytes/files delta thay vì total manifest.
10. Hoàn tất docs sau implementation: `docs/architecture.md`, `docs/genshin-install-plan.md`, `docs/_sync.md`.

## Rủi Ro Và Ràng Buộc

- Hash scan toàn bộ install có thể chậm với 70+ GiB. Nếu quá chậm, plan cần chia thành quick check và deep repair check. MVP có thể verify hash chỉ khi size mismatch/missing? Nhưng để repair corrupted file, cần deep check.
- Nếu chỉ skip theo size trong install path, corrupted same-size file có thể không được sửa. Update delta nên dùng checksum khi user bấm update/repair.
- Official manifest endpoint có thể thay đổi hoặc chưa đầy đủ; giữ validation hiện có.
- Official package manifest có thể stale so với game live; update phải fail rõ thay vì báo up-to-date sai.
- Nếu update subset không bao gồm executable nhưng executable đang thiếu, installer vẫn phải fail rõ hoặc delta phải luôn include missing executable.
- Progress total phải tính đúng subset; nếu vẫn tính full manifest sẽ làm update trông đứng hoặc quá chậm.
- Worktree đang dirty nhiều file; implementation phải tránh revert thay đổi không liên quan.

## Kiểm Chứng

- `swift build`.
- Nếu có thể thêm test target nhỏ:
  - planDelta: file missing => cần tải
  - size mismatch => cần tải
  - size đúng + checksum đúng => skip
  - size đúng + checksum sai => cần tải
  - metadata version cũ + no file delta => status update completed/up-to-date theo latest metadata
- Manual validation:
  - Cài mới xong, bấm Update Game => up to date.
  - Xóa một file nhỏ, bấm Update Game => chỉ tải file đó.
  - Sửa bytes của một file có MD5, bấm Update Game => tải lại file đó.
  - Xóa `.nslauncher-install.json` nhưng giữ files, bấm Update Game => repair metadata hoặc báo repair rõ.
  - Stop giữa update rồi bấm lại => resume `.partial`.

## Acceptance Criteria

- UI có action update game rõ ràng.
- Update không tải lại toàn bộ manifest khi install hiện tại đã có hầu hết file đúng.
- Nếu game đã mới nhất và file hợp lệ, không hiện lỗi và báo up to date.
- Nếu file thiếu/sai, update tải lại đúng subset và ghi metadata version latest.
- Progress/speed/ETA phản ánh bytes cần tải cho update.
- Existing `Download & Install`, local archive install và Wine launch không bị regression.
