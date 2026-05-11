# Sophon-Only Download Flow

## Bối Cảnh

Repo hiện đã có `GenshinSophonInstaller` cho update Genshin hiện tại qua
HoYoPlay Sophon metadata, nhưng các đường download cũ vẫn còn nằm trong domain,
coordinator, view model, settings UI, docs và localized text:

- `InstallerStrategy` vẫn có `archivePackage`, `existingInstall`, `manifest`,
  `streamingManifest`.
- `GameDefinition` vẫn chứa `manifestURL` và `packageSource`.
- `AppSettings` vẫn encode storage cho download cache và temporary extraction,
  đồng thời giữ bundled archive metadata cũ `GenshinImpact_5.5.0.zip.001`.
- `LauncherCoordinator` vẫn inject và dùng `ManifestInstaller`,
  `GenshinStreamingMetadataService`, `PackageDownloadService`,
  `ArchiveInstaller`, `ImportService`, và `DownloadStateStore`.
- `SettingsView` vẫn hiển thị cache/extraction directory, package section,
  archive format, package URLs, multipart URL editor.
- `ContentView` vẫn có local archive install button khi strategy phù hợp.
- `LauncherViewModel` vẫn có install/archive/package resume state, package URL
  setters, archive format setters và error mapping cho các installer cũ.

User muốn chuyển hoàn toàn sang Sophon và loại bỏ mọi phương án download cũ,
kể cả trong Settings. Vì vậy target là product/codebase Sophon-only cho bundled
Genshin, không còn archive/manifest/pkg_version/local archive/import download
surface.

## Mục Tiêu

- Chỉ còn một download/update backend: Sophon.
- Fresh install và update đều đi qua `GenshinSophonInstaller`.
- Main UI chỉ còn action Sophon install/update phù hợp, không còn local archive
  install.
- Settings không còn cache/extraction/package/archive/URL editor; chỉ giữ ngôn
  ngữ, install root, executable path và display mode.
- Domain/settings không còn persist package source hoặc generic manifest config.
- Xóa source/service không còn dùng cho package/archive/file-level manifest.
- Docs/README phản ánh Sophon-only, không còn hướng dẫn archive/pkg_version.

## Ngoài Phạm Vi

- Không triển khai bypass `HoYoKProtect.sys`.
- Không thêm nhiều game hoặc generic downloader mới.
- Không thêm selectable voice language trong bước này; Sophon vẫn dùng default
  voice hiện tại trong `GenshinSophonInstaller`.
- Không đổi core Wine/DXMT launch ngoài những compile fixes cần thiết.

## Hướng Tiếp Cận Đề Xuất

### 1. Thu gọn domain model

- Thay `InstallerStrategy` bằng một strategy duy nhất hoặc bỏ hẳn khỏi
  `GameDefinition` nếu không còn quyết định runtime nào cần nó.
- Xóa `ArchiveFormat`, `PackageSource`, `PersistedDownloadState`,
  `RemoteGameManifest`, `RemoteGameFile`, và các field `manifestURL`,
  `packageSource` khỏi `GameDefinition`.
- Đổi `InstalledGameMetadata.installMode` để tương thích migration:
  - hoặc giữ optional/decode-compatible enum nhưng encode future metadata là
    Sophon-only;
  - hoặc thêm custom decoder đọc metadata cũ nhưng không phụ thuộc strategy cũ.
- Xóa `downloadCacheDirectory` và `temporaryExtractionDirectory` khỏi settings
  encode mới; decoder vẫn đọc bỏ qua các key cũ để settings hiện tại không hỏng.
- `AppSettings.applyingBundledGenshinDefaultsIfNeeded()` migrate mọi settings cũ
  sang bundled Genshin Sophon-only, bỏ package source cũ.

### 2. Biến Sophon thành install/update backend duy nhất

- Mở rộng `SophonInstalling`/`GenshinSophonInstaller` để hỗ trợ fresh install:
  - `fetchBuild(language:)` giữ nguyên;
  - `planInstall(for:build:)` có thể reuse `planUpdate` với
    `installedMetadata: nil`;
  - `install(...)`/`update(...)` dùng chung asset writer, staging, prune, verify,
    metadata write.
- `LauncherCoordinator.fetchInstallPlan` gọi Sophon build/plan trực tiếp.
- `LauncherCoordinator.installGame` gọi Sophon install/apply trực tiếp.
- `LauncherCoordinator.fetchUpdatePlan` luôn gọi Sophon.
- `LauncherCoordinator.updateGame` chỉ xử lý `sourceKind == .sophon`; sau đó có
  thể xóa `UpdatePlanSourceKind.manifest`, `targetFiles`, `filesToDownload` nếu
  không còn cần cho UI.
- Xóa `updateManifest(...)`, `cleanupDownloadedArchives(...)`, package resume
  API và dependency injection các service cũ.

### 3. Gỡ services/files cũ

Xóa hoặc để compiler chứng minh không còn tham chiếu rồi remove:

- `Sources/NSLauncherApp/Services/Installer/ManifestInstaller.swift`
- `Sources/NSLauncherApp/Services/Installer/PackageDownloadService.swift`
- `Sources/NSLauncherApp/Services/Installer/ArchiveInstaller.swift`
- `Sources/NSLauncherApp/Services/Installer/GenshinStreamingMetadataService.swift`
- `Sources/NSLauncherApp/Services/ImportService.swift`
- `Sources/NSLauncherApp/Services/DownloadStateStore.swift`

Giữ:

- `GenshinSophonInstaller.swift`
- `InstallTargetPruner.swift`
- `OperationController.swift`
- `ProcessRunner.swift`
- `WineService.swift`
- `SettingsStore.swift`
- `BinaryLocator.swift`

### 4. Thu gọn ViewModel/UI

- `LauncherViewModel.bootstrap()` chỉ inject `SettingsStore`,
  `GenshinSophonInstaller`, `WineService`.
- Xóa `restorePersistedDownloadStateIfNeeded`,
  `applyPersistedDownloadState`, `resumableDownloadGameID`, package/archive
  setters, archive override parameter, package download interruption handling.
- `canDownloadSelectedGame` luôn true khi có selected game; `canUpdateSelectedGame`
  tương tự.
- `canInstallFromLocalArchive` bị xóa.
- `installSelectedGame()` không nhận `archiveOverrideURL`.
- `apply(event:)` bỏ các nhánh chỉ dành cho archive/package/import:
  `readyToExtract`, `downloadingPackage`, `extracting`,
  `cleaningDownloadedArchives`, `importing`. Nếu Sophon vẫn emit
  `downloadingManifest`, `verifying`, `validatingInstall`, `finished`, giữ các
  nhánh đó.
- `ContentView` bỏ `UniformTypeIdentifiers`, `chooseArchiveURL`, local archive
  button và badge `localOnly`.
- `SettingsView` bỏ state `packageURLText`, `partURLRows`, `packageSection`,
  package sync/persist helpers, download cache directory, temporary extraction
  directory. Storage card chỉ còn language hoặc đổi tên thành General.

### 5. Dọn localized text

Xóa hoặc đổi các string không còn dùng:

- package/archive URL labels, multipart hints, archive format, cache cleanup,
  local archive title/description, 7zip errors, manifest URL errors, streaming
  pkg_version stale errors.
- Đổi copy:
  - `downloadInstallTitle` thành Sophon-oriented nếu cần.
  - `downloadInstallDescription` nói tải/reconstruct asset từ Sophon chunks.
  - `updateGameDescription` nói check Sophon metadata.
  - `launcherStrategyDescription` không còn nhận strategy cũ.

### 6. Docs

- Cập nhật `README.md`, `docs/architecture.md`, `docs/genshin-install-plan.md`,
  `docs/modules/downloader-optimization.md`, `docs/_index.md`, `docs/_sync.md`.
- Có thể giữ planning specs cũ như historical context, nhưng thêm ghi chú rõ rằng
  current product direction là Sophon-only.

## Công Việc Cần Làm

1. Thu gọn models/settings và migration decode-compatible.
2. Refactor coordinator sang Sophon-only.
3. Refactor `GenshinSophonInstaller` để fresh install và update dùng chung flow.
4. Refactor ViewModel bỏ package/archive/import/manifest state.
5. Refactor ContentView và SettingsView bỏ mọi UI download cũ.
6. Xóa service files cũ và strings không còn dùng.
7. Cập nhật docs.
8. Chạy `swift build` và sửa compile errors theo compiler.

## Rủi Ro Và Ràng Buộc

- Đây là breaking change với settings cũ; cần custom decode/migration để app còn
  mở được file settings hiện tại.
- `InstalledGameMetadata` cũ có `installMode: streamingManifest`; nếu decoder mới
  không tương thích, mọi install hiện có sẽ bị coi như missing metadata.
- Fresh install Sophon sẽ tải rất lớn; UI phải còn báo download/write size rõ.
- Xóa Manifest/Archive services có thể làm mất khả năng import existing install;
  đây là chủ ý theo yêu cầu, nhưng cần UI không còn ám chỉ import/local archive.
- Các thay đổi trước đó về lỗi kernel driver đang dirty trong worktree; khi
  triển khai cần giữ hoặc tích hợp, không revert vô tình.

## Kiểm Chứng

- `swift build`.
- Mở Settings: không còn cache/extraction/package/archive URL controls.
- Main screen: không còn Install From Local Archive, không còn badge local-only.
- Fresh install path gọi Sophon plan/apply thay vì `GenshinStreamingMetadataService`
  hoặc `ManifestInstaller`.
- Update path vẫn gọi Sophon, vẫn log source `sophon`, vẫn ghi
  `.nslauncher-install.json`.
- `rg` không còn source references tới `PackageDownloadService`,
  `ArchiveInstaller`, `ManifestInstaller`, `GenshinStreamingMetadataService`,
  `PackageSource`, `ArchiveFormat`, `pkg_version` trong source app.
