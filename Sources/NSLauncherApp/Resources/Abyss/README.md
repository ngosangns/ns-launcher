# Dữ liệu tab Trầm Thủy (Abyss)

Dữ liệu tra cứu Genshin Impact cho tính năng gợi ý đội hình Trầm Thủy: nhân
vật, vũ khí, thánh di vật, quái + chúc phúc của mùa hiện tại, công thức sát
thương, buff đội, và bộ tham số của thuật toán.

> Genshin Impact và toàn bộ nhân vật, vật phẩm, số liệu gốc thuộc bản quyền
> HoYoverse. Số liệu ở đây được trích xuất từ file game qua Yatta/Ambr
> (`gi.yatta.moe`) và đối chiếu với Genshin Impact Wiki trên Fandom
> (nội dung Fandom theo giấy phép CC BY-SA 3.0). Thư mục này chỉ phục vụ tra
> cứu và tính toán trong ứng dụng, không nhằm thay thế hay tái bản nguồn gốc.

## Vì sao dữ liệu nằm ở đây chứ không ở `toi-uu-doi-hinh/`

Bản Markdown cho người đọc vẫn ở `toi-uu-doi-hinh/` (kèm `data-model/schema/`
để validate). Nhưng SwiftPM **chỉ đóng gói được tài nguyên nằm trong thư mục
target**, nên bản JSON mà app đọc lúc chạy phải nằm ở đây. Giữ hai bản sao ở
hai nơi thì sớm muộn cũng lệch nhau mà không ai phát hiện — nên thư mục này
là **bản duy nhất**; công cụ Python trong `toi-uu-doi-hinh/optimizer/` cũng
đọc thẳng từ đây (`DATA_ROOT` trong `abyss_optimizer/data.py`).

## Nội dung

| Đường dẫn | Nội dung |
|---|---|
| `characters/*.json` | 125 nhân vật, nhóm theo quốc gia trong game |
| `weapons/*.json` | 246 vũ khí, nhóm theo loại |
| `artifact-sets.json` | 63 bộ thánh di vật |
| `abyss-monsters/<khoảng-ngày>.json` | Quái + Ley Line Disorder + Uyên Nguyệt Chúc Phúc của một chu kỳ |
| `damage-formula.json` | Hằng số công thức sát thương + ví dụ mẫu để test |
| `team-bonus.json` | Cộng hưởng nguyên tố, Nguyệt Triệu, Hexerei, Nightsoul Burst |
| `tuning.json` | Tham số thuật toán (xem bên dưới) |
| `game-ids.json` | Id số trong game → slug ở đây, để nhập Showcase theo UID |
| `manifest.json` | Số lượng bản ghi + các khoảng trống dữ liệu đã biết |

`game-ids.json` **sinh tự động**, đừng sửa tay:

```bash
python3 scripts/generate-abyss-game-ids.py
```

Chạy lại mỗi khi thêm nhân vật / vũ khí / bộ thánh di vật — bảng cũ khiến tính
năng nhập theo UID lặng lẽ bỏ sót nhân vật. Script từ chối ghi nếu bảng mới mất
id so với bảng đã commit, và `AbyssShowcaseImportTests` ghim bảng theo đúng bộ
dữ liệu này.

Schema JSON của từng loại: `toi-uu-doi-hinh/data-model/schema/`.

## Dữ liệu chu kỳ Trầm Thủy hết hạn nhanh

`abyss-monsters/` là phần **hết hạn nhanh nhất**: quái và chúc phúc đổi mỗi 2
tuần (reset ngày 1 và 16). Bản `.app` đã phát hành sẽ mang dữ liệu của chu kỳ
lúc build. App hiển thị khoảng ngày áp dụng + cảnh báo khi quá hạn, và đọc
thêm file đè đặt ở:

```
~/Library/Application Support/NSLauncher/abyss-cycles/*.json
```

File đè cùng định dạng, trùng `periodStart` thì thắng bản đóng gói — cập nhật
được dữ liệu mùa mới mà không cần phát hành lại app.

## `tuning.json` — đọc kỹ trước khi tin con số

Ba nhóm số, độ tin cậy **khác hẳn nhau**:

1. **Số liệu game đã fetch** — mọi file *khác* `tuning.json`. Trích thẳng từ
   file game, đã validate schema.
2. **Hằng số game chuẩn** — `artifactMainStats`, `substatRollValue`. Ổn định
   qua các bản cập nhật nhưng **chưa được đối chiếu API trong repo này**.
3. **Ước lượng heuristic của thuật toán** — tất cả phần còn lại. Đây là các
   giả định mô hình (độ dài rotation, uptime buff có điều kiện, hệ số quy đổi
   hiệu ứng 4 món phức tạp), **không phải số liệu game**. `setEffectApprox` là
   phần chủ quan nhất: 36/63 bộ có hiệu ứng 4 món quá phức tạp để tách số máy
   móc, nên được gán tay một mức "%DMG hiệu dụng". Sửa bảng này là cách nhanh
   nhất để đổi kết quả theo hiểu biết của bạn.

Giải thích từng nhóm nằm ở khoá `notes` trong chính `tuning.json` (JSON không
có comment). Cả bản Swift lẫn bản Python đọc chung file này nên sửa một lần là
đổi cả hai.

## Cập nhật dữ liệu

1. Sửa Markdown nguồn trong `toi-uu-doi-hinh/` theo quy ước ở README của nó.
2. Cập nhật JSON tương ứng ở đây.
3. Validate: xem lệnh trong `toi-uu-doi-hinh/data-model/README.md`.
4. Chạy `swift test` — các test Abyss pin số lượng bản ghi và tính toàn vẹn
   tham chiếu, nên dữ liệu hỏng sẽ làm đỏ test thay vì âm thầm rỗng trong app.

## Golden fixture cho test

`Tests/NSLauncherAppTests/Fixtures/abyss-golden.json` giữ giá trị trung gian
(scaling basis, hệ số từng đòn, chỉ số build, bối cảnh tầng, top-10 đội hình
của roster mẫu) sinh từ **bản Python** — engine Swift phải khớp trong sai số
tương đối `1e-9`. Nó bắt đúng loại lỗi nguy hiểm nhất khi port: một nhánh
quy đổi tên chỉ số đấu nhầm ô sẽ cho ra số *hợp lý nhưng sai*, không crash,
không ai nhận ra.

Sinh lại **chỉ khi cố ý đổi mô hình** (sửa `tuning.json`, sửa parser, cập
nhật dữ liệu làm đổi kết quả) — nếu sinh lại mỗi lần test đỏ thì fixture hết
tác dụng:

```bash
cd toi-uu-doi-hinh/optimizer
python3 optimize_abyss.py --dump-golden ../../Tests/NSLauncherAppTests/Fixtures/abyss-golden.json
```
