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
là **bản duy nhất**.

## Nội dung

| Đường dẫn | Nội dung |
|---|---|
| `characters/*.json` | 125 nhân vật, nhóm theo quốc gia trong game |
| `weapons/*.json` | 246 vũ khí, nhóm theo loại |
| `artifact-sets.json` | 63 bộ thánh di vật |
| `abyss-monsters/<khoảng-ngày>.json` | Quái + Ley Line Disorder + Uyên Nguyệt Chúc Phúc của một chu kỳ |
| `damage-formula.json` | Hằng số công thức sát thương + ví dụ mẫu để test |
| `team-bonus.json` | Cộng hưởng nguyên tố, Nguyệt Triệu, Hexerei, Nightsoul Burst — **luật**, không phải danh sách nhân vật |
| `character-traits.json` | Mọi thứ chỉ đúng với **một** nhân vật: tag cơ chế, nhãn đòn nặng, buff toàn đội theo talent, giảm kháng, base damage phản ứng |
| `tuning.json` | Tham số thuật toán (xem bên dưới) |
| `game-ids.json` | Id số trong game → slug ở đây, để nhập Showcase theo UID |
| `icons/characters/<id>.png`, `icons/weapons/<id>.png` | Ảnh chân dung, 256×256 |
| `manifest.json` | Số lượng bản ghi + các khoảng trống dữ liệu đã biết |

## Thêm nhân vật mới thì sửa ở đâu

`character-traits.json` là chỗ duy nhất cần sửa cho phần "nhân vật này đặc biệt
ở chỗ nào". Trước 2026-09-12 thì không: 48 sự thật kiểu đó nằm rải ở bảy bảng
thuộc ba file khác nhau —

| Nằm ở | Bảng |
|---|---|
| `tuning.json` | `chargedAttackLabels`, `talentPartyBuff`, `stellarJubileeCharacterIds`, `resistanceShred` (các dòng gắn nhân vật) |
| `team-bonus.json` | `moonsign.characterIds`, `hexerei.characterIds` |
| `damage-formula.json` | `lunarStellar.reactionBaseDmgBonusSources` |

— với hai quy ước id lẫn nhau (chín tên hiển thị và một slug `traveler-cryo`
nằm chung một cột), và **sáu trên bảy bảng đọc mà không kiểm id**. Đó mới là chỗ
đau: gõ sai id không làm hỏng gì cả. Nó gỡ mất một cơ chế, và một đội thiếu
Stellar Jubilee vì gõ sai trông y hệt một đội vốn không có ai Stellar Jubilee.

Giờ: một entry mỗi nhân vật, `characterId` luôn là slug trùng `characters/*.json`,
và `AbyssDataLibrary` ghi mọi id/tên phản ứng không phân giải được vào
`diagnostics.unknownTraitCharacterIDs` — `AbyssCharacterTraitsTests` ghim nó
rỗng, nên id sai làm **đỏ test** thay vì làm sai lặng lẽ.

Ranh giới với `tuning.json`: **câu đó có gọi tên một nhân vật không?** Uptime
burst của Faruzan là sự thật về Faruzan → `character-traits.json`. `rotationSeconds`,
`conditionalUptime`, `setEffectApprox` là giả định của thuật toán áp cho mọi
người → ở lại `tuning.json`. Hai dòng `resistanceShred` còn lại trong `tuning.json`
là ví dụ rõ nhất: chúng gate theo *nguyên tố của đội* để đại diện cho "support
Anemo thì chắc mặc Viridescent Venerer" — một giả định, không phải sự thật về ai.

`game-ids.json` **sinh tự động**, đừng sửa tay:

```bash
python3 scripts/generate-abyss-game-ids.py
```

Chạy lại mỗi khi thêm nhân vật / vũ khí / bộ thánh di vật — bảng cũ khiến tính
năng nhập theo UID lặng lẽ bỏ sót nhân vật. Script từ chối ghi nếu bảng mới mất
id so với bảng đã commit, và `AbyssShowcaseImportTests` ghim bảng theo đúng bộ
dữ liệu này.

Văn bản của thánh di vật — tên và mô tả hiệu ứng 2 món / 4 món, **cả tiếng Anh
lẫn tiếng Việt** — cũng sinh tự động, từ bản địa hoá chính thức của game:

```bash
python3 scripts/sync-abyss-artifact-text.py
```

Đừng viết hay dịch các trường `name`, `nameVI`, `description`, `descriptionVI`
bằng tay (hay bằng AI). Game có bản tiếng Việt chính thức; mô tả diễn đạt lại thì
đọc khác cái người chơi thấy trong game, gọi cùng một cơ chế bằng tên khác
("Xoáy cuốn" trong khi game gọi là "Khuếch Tán"), và lặng lẽ thêm bớt điều kiện.
Trước 2026-09-14 cả 59 mô tả 4 món đều là văn tự diễn đạt như vậy, còn mô tả 2 món
là tiếng Anh viết tắt — và vì một trường chứa hai thứ tiếng, giao diện tiếng Anh
hiển thị văn tiếng Việt. Script khớp theo id số qua `game-ids.json` (nên chạy
sau `generate-abyss-game-ids.py` khi thêm bộ mới) và từ chối ghi nếu có bộ nào
không phân giải được ở cả hai ngôn ngữ. `bonuses` — số liệu model đọc — không bị
đụng tới; không có gì parse phần văn xuôi.

`icons/` cũng sinh tự động, cùng một kiểu:

```bash
python3 scripts/fetch-abyss-icons.py
```

Khớp tên với `gi.yatta.moe` rồi tải PNG về đúng theo slug của mình
(`icons/characters/hu-tao.png`), nên lúc chạy Swift không cần biết mã icon nội
bộ của Yatta — chỉ mở đúng file theo id, giống hệt cách `characters/<id>` và
`weapons/<id>` đã hoạt động. File đã có thì bỏ qua, không tải lại; dùng
`--force` nếu muốn tải lại toàn bộ. Nặng khoảng 8.6 MB, dùng riêng cho tab
Trầm Thủy — không tính vào phần Story hay dung lượng game.

Nhân vật Nhà Lữ Hành (Traveler) dùng chung một ảnh cho cả 7 biến thể nguyên
tố — game không vẽ ảnh riêng theo nguyên tố, chỉ khác theo giới (chọn cố định
Aether/nam cho nhất quán, không phải khẳng định "đây mới là" Nhà Lữ Hành đúng).
Nhân vật hoặc vũ khí không tải được ảnh sẽ hiện icon SF Symbol tô màu như cũ,
không hiện ô trống.

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
   file game, đã validate schema. `damage-formula.json` giờ là NGUỒN THẬT của
   các hệ số: đường cong EM, hệ số amplifying/transformative và levelMultiplier
   đều được đọc lúc load (`AbyssDamageConstants`), không còn chép tay trong
   Swift. Phần chưa đọc được sẽ báo ở `AbyssParseDiagnostics.damageFormulaUnread`.
2. **Hằng số game chuẩn** — `artifactMainStats`, `substatRollValue`. Ổn định
   qua các bản cập nhật nhưng **chưa được đối chiếu API trong repo này**.
3. **Ước lượng heuristic của thuật toán** — tất cả phần còn lại. Đây là các
   giả định mô hình (độ dài rotation, uptime buff có điều kiện, hệ số quy đổi
   hiệu ứng 4 món phức tạp), **không phải số liệu game**. `setEffectApprox` là
   phần chủ quan nhất: 36/63 bộ có hiệu ứng 4 món quá phức tạp để tách số máy
   móc, nên được gán tay một mức "%DMG hiệu dụng". Sửa bảng này là cách nhanh
   nhất để đổi kết quả theo hiểu biết của bạn.
4. **`talentPartyBuff` — nửa data, nửa giả định.** Bảng này khai buff CẢ ĐỘI
   đến từ chiêu nhân vật (Bennett, Kujou Sara, Faruzan). Con số hệ số được
   **đọc từ data nhân vật** theo `(talent, label)` nên tự cập nhật khi hệ số
   chiêu đổi; chỉ `kind` (dòng đó nghĩa là gì) và `uptime` là viết tay. Cần
   bảng này vì nhãn không tự phân biệt được: "ATK Bonus 100.8% Base ATK" (buff
   phẳng cho cả đội) và "ATK Bonus (%DEF) 103.7%" (tự quy đổi cho bản thân) là
   cùng ba chữ, và bộ lọc sát thương bỏ cả hai vì cả hai đều không phải một
   đòn đánh. Nếu `label` trôi, `AbyssParseDiagnostics.talentPartyBuffUnresolved`
   báo lên và `AbyssBuildAssemblerTests` fail — buff không biến mất im lặng.
   Khoá `notes.talentPartyBuff` liệt kê những buff **cố ý chưa mô hình hoá**.

Giải thích từng nhóm nằm ở khoá `notes` trong chính `tuning.json` (JSON không
có comment).

## Cập nhật dữ liệu

1. Sửa Markdown nguồn trong `toi-uu-doi-hinh/` theo quy ước ở README của nó.
2. Cập nhật JSON tương ứng ở đây.
3. Validate: xem lệnh trong `toi-uu-doi-hinh/data-model/README.md`.
4. Chạy `swift test` — các test Abyss pin số lượng bản ghi và tính toàn vẹn
   tham chiếu, nên dữ liệu hỏng sẽ làm đỏ test thay vì âm thầm rỗng trong app.

## Golden fixture cho test

`Tests/NSLauncherAppTests/Fixtures/abyss-golden.json` giữ giá trị trung gian
(scaling basis, hệ số từng đòn, chỉ số build, bối cảnh tầng, top-10 đội hình
của roster mẫu) — engine phải khớp trong sai số tương đối `1e-9`. Nó bắt đúng
loại lỗi nguy hiểm nhất ở đây: một nhánh quy đổi tên chỉ số đấu nhầm ô sẽ cho
ra số *hợp lý nhưng sai*, không crash, không ai nhận ra.

Số trong file vốn do một bản Python sinh ra, bản đó đã bị xoá sau khi engine
Swift chứng minh khớp từng chữ số. Nay file do **chính engine** sinh, nên nó
là **mốc hồi quy**: "hôm kiểm, engine tính ra thế này". Vì vậy sinh lại là một
**quyết định**, không phải cách chữa test đỏ — chỉ sinh lại khi cố ý đổi mô
hình (sửa `tuning.json`, sửa parser, cập nhật dữ liệu làm đổi kết quả), rồi
**đọc diff**: một thay đổi nhắm vào một nhân vật mà làm trôi ba trăm con số là
diff đang nói cho bạn biết điều gì đó.

```bash
ABYSS_DUMP_GOLDEN=Tests/NSLauncherAppTests/Fixtures/abyss-golden.json \
    swift test --filter testRegenerateGoldenFixture
```
