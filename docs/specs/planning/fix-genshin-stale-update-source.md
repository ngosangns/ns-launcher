# Sửa Update Genshin Báo Sai Up-To-Date Khi Game Live Đã Mới Hơn

## Trạng Thái

Đã triển khai guard và Sophon update path. Khi HoYoPlay `getGamePackages` vẫn trả Genshin 5.x nhưng `getGameBranches` trả live branch Sophon mới hơn, launcher không còn báo `up to date`; bundled Genshin `streamingManifest` update hiện đi qua `GenshinSophonInstaller` để fetch Sophon build, lập delta theo asset MD5, tải chunk, verify và ghi metadata mới.

## Bối Cảnh

Người dùng đã chạy `Update Game`, launcher báo mới nhất, nhưng khi vào game vẫn hiện dialog `Version update found. Please start the launcher to download the latest version...`. Kiểm tra local install cho thấy toàn bộ 2,123 file trong `ScatteredFiles/pkg_version` hiện tại đều tồn tại và đúng size. Metadata `.nslauncher-install.json` cũng ghi `version: 5.5.0`.

Nguyên nhân trực tiếp là `GenshinStreamingMetadataService` đang dùng HoYoPlay `getGamePackages` với `launcher_id=VYTpXlbWo8`, và endpoint này hiện trả `hk4e_global` `main.major.version = 5.5.0` với CDN path `20250314110016_HcIQuDGRmsbByeAE`. Trong khi `getGameBranches` cho `game_ids[]=gopR6Cufr3` trả live branch `tag = 6.5.0`, `package_id = ScSYQBFhu9`. Vì vậy launcher đang đúng theo manifest cũ nhưng sai theo live game version; Genshin đã chuyển update metadata sang Sophon chunk flow.

## Mục Tiêu

- Không bao giờ báo `Game is already up to date` khi official package manifest đang stale so với live game.
- Phát hiện tình trạng `getGamePackages` stale cho Genshin, hiển thị lỗi/log rõ ràng thay vì để user vào game gặp dialog.
- Chuẩn bị đường update an toàn sang nguồn metadata mới nếu tìm được endpoint full package/scattered files hiện hành.
- Giữ pipeline delta/scattered-file update hiện có cho các manifest hợp lệ.

## Ngoài Phạm Vi

- Không tự tải/chạy HoYoPlay Windows launcher trong Wine trong bước này.
- Không implement hdiff patch apply nếu chưa xác minh được format và toolchain an toàn.
- Không hardcode link 6.x lấy từ nguồn không ổn định hoặc không chính thức.
- Không xóa/cài lại game tự động.

## Thiết Kế Hiện Tại

`GenshinStreamingMetadataService.fetchUpdateManifest` vẫn kiểm tra freshness của legacy `pkg_version` source. Service fetch `getGamePackages`, lấy thêm live branch evidence từ `getGameBranches`, và lấy installer-link evidence từ `download_porter/time_link/ys_global/genshinimpactpc/default`. Nếu package manifest thấp hơn live branch hoặc rõ ràng stale theo installer evidence, service throw lỗi localized thay vì để manifest cũ trở thành latest truth.

Bundled Genshin update không còn phụ thuộc vào stale error path làm outcome chính. `LauncherCoordinator.fetchUpdatePlan` chọn `GenshinSophonInstaller` trước cho `streamingManifest` + `genshin-global`; Sophon build tag trở thành latest playable version, còn `pkg_version` chỉ là legacy manifest fallback khi Sophon không được dùng.

UI update log hiển thị plan source, installed/latest version, delta counts/bytes, sample changed assets/files, pause/stop, progress milestones, verify, metadata writes và final success/failure. Khi legacy manifest bị stale, localized errors vẫn chứa endpoint evidence để tránh false-positive up-to-date.

## Rủi Ro Và Ràng Buộc

- HoYoPlay package endpoint cho Genshin có thể cố ý stale hoặc bị phân phối khác theo launcher cache; không nên hardcode workaround không xác minh.
- Version live không luôn suy ra chắc chắn từ asset date; nếu không có source version chính thức, chỉ dùng check này để chặn false-positive up-to-date, không dùng để tải file.
- Nếu user đang ở bản 5.5.0, update thật lên 6.x có thể yêu cầu full reinstall hoặc official launcher pipeline mới.

## Acceptance Criteria

- Với endpoint hiện tại trả `5.5.0`, `Update Game` không báo up-to-date nữa.
- Với Genshin live Sophon 6.x, update plan đi qua `GenshinSophonInstaller` và dùng branch/build tag làm latest version.
- Legacy manifest stale errors vẫn chứa evidence endpoint và version trả về.
- Nếu sau này endpoint `pkg_version` trả version hiện hành hợp lệ, flow delta manifest hiện tại vẫn chạy được.
