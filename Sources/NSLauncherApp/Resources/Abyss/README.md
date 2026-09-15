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
| `character-kits.json` | Mọi thứ chỉ đúng với **một** nhân vật và không file game nào ghi: một lần dùng chiêu gồm những dòng nào (`hits`), kit đổi HP/DEF ra ATK (`conversions`), talent buff gì cho đội/cho mình (`buffs`), tag cơ chế, nhãn đòn nặng, giảm kháng, base damage phản ứng (xem "Kit nhân vật") |
| `talent-params.json` | Hệ số talent **đúng như file game**, mọi cấp 1–15, sinh tự động — nguồn thay thế cho bảng `scaling` văn xuôi (xem "Số liệu talent") |
| `particles.json` | Số hạt nguyên tố Kỹ năng Nguyên tố tạo ra, theo Genshin Impact Wiki, sinh tự động (xem "Năng lượng") |
| `tuning.json` | Tham số thuật toán (xem bên dưới) |
| `game-ids.json` | Id số trong game → slug ở đây, để nhập Showcase theo UID |
| `icons/characters/<id>.png`, `icons/weapons/<id>.png` | Ảnh chân dung, 256×256 |
| `manifest.json` | Số lượng bản ghi + các khoảng trống dữ liệu đã biết |

## Thêm nhân vật mới thì sửa ở đâu

`character-kits.json` (tên cũ `character-traits.json`, đến 2026-09-15) là chỗ duy
nhất cần sửa cho phần "nhân vật này đặc biệt ở chỗ nào". Trước 2026-09-12 thì không: 48 sự thật kiểu đó nằm rải ở bảy bảng
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
`diagnostics.unknownKitCharacterIDs` — `AbyssCharacterKitTests` ghim nó
rỗng, nên id sai làm **đỏ test** thay vì làm sai lặng lẽ.

Ranh giới với `tuning.json`: **câu đó có gọi tên một nhân vật không?** Uptime
burst của Faruzan là sự thật về Faruzan → `character-kits.json`. `rotationSeconds`,
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

## Số liệu talent: file game thay cho văn xuôi

`talent-params.json` cũng sinh tự động:

```bash
python3 scripts/sync-abyss-talent-params.py
```

Trước 2026-09-15, hệ số talent đi từ bảng `scaling` trong `characters/*.json` —
nhãn tiếng Việt + chuỗi kiểu `"172.53% DEF"` mỗi cấp, transcribe từ wiki — qua
26 regex trong `AbyssTextParser`. Đối chiếu với file game (Yatta) trên toàn bộ
118 nhân vật có id cho thấy chỉ **16/118** khớp; phần lớn lệch là lỗi
transcription, và nặng nhất: **28 nhân vật Sumeru/Natlan ghi "chưa xác nhận"
cho toàn bộ đòn thường → mô hình đang chấm họ với đòn thường và đòn nặng bằng 0**.

File này là dữ liệu nguyên văn của game: mỗi talent có `lines` (dòng mô tả,
vd. `"Skill DMG|{param1:P} Max HP"`) và `params` theo cấp. **Không có suy diễn
nào trong file** — dòng nào là damage, dòng nào là lựa chọn thay thế ("Skill
DMG" / "Low HP Skill DMG"), `+` cộng và `×3` nhân ra sao, đều do
`AbyssTalentReader` (Swift) quyết định, và mỗi luật là một test trong
`AbyssTalentReaderTests`. Muốn biết hai nguồn lệch ở đâu, chạy
`AbyssTalentSourceComparisonTests` — nó in bảng so sánh từng nhân vật.

`AbyssDataLibrary` ưu tiên file này; nhân vật không có ở đây (7 Nhà Lữ Hành —
Yatta gộp chung một avatar) vẫn đi đường văn xuôi. Bảng `scaling` trong
`characters/*.json` vì thế chỉ còn là nguồn dự phòng cho Nhà Lữ Hành — chưa
xoá, nhưng đừng sửa nó để "chỉnh" damage của ai nữa: sửa ở đây không có tác
dụng.

## Kit nhân vật: điều bảng talent không nói được

Bảng talent của game liệt kê **mọi** dòng của một chiêu, không nói một lần
dùng thật sự gồm dòng nào. Bảng E của Bennett có "Press DMG", "Charge Level 1
DMG", "Charge Level 2 DMG", "Explosion DMG" — một lần bấm là *một* trong số
đó; bảng burst của Raiden liệt kê cả chuỗi 5 đòn Musou Isshin thay cho đòn
thường; "ATK Increase|{p} Max HP" của Hu Tao không phải đòn mà là HP đổi ra
ATK. Đó là tri thức về cách kit được *chơi*, và `character-kits.json` là chỗ
duy nhất nó được viết xuống (Pha 2 của `docs/redesign.md`):

- `hits.{skill,burst,combo,charged}` — danh sách tham chiếu `{label | param,
  count, category, factor}` vào `talent-params.json`. Slot có mặt **thay
  toàn bộ** suy luận của `AbyssTalentReader` cho slot đó; mảng rỗng = không
  có gì. Slot quyết định *tần suất* (combo × `normalCombosPerRotation`, ability
  × 1), `category` quyết định *bucket buff* — hai thứ này trùng nhau ở mọi
  dòng reader tự suy, và chỉ kit mới tách được (Isshin của Raiden: chuỗi đòn
  thường, tính là Elemental Burst DMG).
- `conversions` — dòng talent đổi HP/DEF ra ATK; lên sheet dưới dạng *tỉ lệ*
  (`AbyssStats.atkFromHPRate`) nên HP% tự thành chỉ số damage của Hu Tao
  trong tìm kiếm substat. Vũ khí cùng loại (Trượng Hộ Ma "ATK from HP",
  Engulfing "ATK from Energy Recharge over 100%") đi cùng khung, ở
  `AbyssBuildAssembler.weaponConversionRules`.
- `buffs` — `scope: party | self`; số đọc từ `talent-params.json` theo `label`
  (thiên phú không có bảng thì `value` literal kèm trích dẫn).

Mọi số ở đây là **tham chiếu** vào file game, đọc ở đúng cấp talent của nhân
vật; mọi lựa chọn chủ quan (chế độ nào, bao nhiêu stack, uptime) nằm trong
`note` kèm chữ game trích nguyên văn. Tham chiếu không giải được → `diagnostics.kitReferencesUnresolved`,
`AbyssCharacterKitTests` ghim rỗng. Nhân vật không có entry (hoặc slot không
ghi đè) đi theo luật chung của reader — app chạy trọn vẹn ở mọi mức phủ.
Đến 2026-09-15: 21 nhân vật có `hits`, 2 có `conversions`, 4 có `buffs`.

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

## Năng lượng: hạt nguyên tố và số lần Q

Pha 3 của `docs/redesign.md`. Trước đây mọi Q được dùng đúng một lần mỗi
rotation, và nhân vật ngoài sân bị nhân phẳng `offFieldUptime = 0.85` — nên
Energy Recharge đáng giá 0 với điểm, và support bị ép mang cát ER. Giờ số lần
Q = `min(1, rotationSeconds / CD, năng lượng × ER / năng lượng Q)`, với năng
lượng tính từ hạt của cả đội:

- **Hạt mỗi lần E** — `particles.json`, sinh bằng

  ```bash
  python3 scripts/sync-abyss-particles.py
  ```

  từ template `{{Talent Note|particles|…}}` trên trang kỹ năng của Genshin
  Impact Wiki (MediaWiki API), đối chiếu với code nhân vật của gcsim
  (github.com/genshinsim/gcsim, MIT) — hai nguồn khớp nhau ở mọi nhân vật đã
  so. Số liệu do cộng đồng đo, không phải file game: Yatta có CD, năng lượng
  Q, gauge và ICD, nhưng không có số hạt.
- **Điều wiki không nói** nằm ở `character-kits.json` → `energy`: ghi chú
  "mỗi đòn của Oz" cần biết một lần E có bao nhiêu đòn (`eventsPerCast`,
  kèm nguồn nhịp đánh: bảng talent, mô tả kỹ năng hoặc hằng số gcsim); trang
  không có ghi chú cần số literal (`particlesPerCast`, trích file:dòng gcsim);
  triệu hồi thì hạt về người đang đứng sân (`collectedBy: field`); E kiểu vào
  trạng thái chỉ dùng một lần mỗi rotation (`skillCastsPerRotation`); chuỗi
  đòn chỉ có trong Q (`stance` — Raiden, Cyno, Xiao).
- **Luật và giả định** ở `tuning.json` → `energy`: hạt cùng nguyên tố 3, khác
  nguyên tố 1, không màu 2, ngoài sân nhận 60% (luật game); quái rơi 0 hạt
  mỗi rotation và tối đa 2 lần E mỗi rotation (giả định, xem `notes.energy`).

Nhân vật không đọc được số hạt (7 Nhà Lữ Hành, Linnea, Lohen, Zibai) dùng
trung vị của mọi nhân vật đọc được, và được ghim đích danh trong
`AbyssEnergyTests`. Buff đội từ Q (Bennett, Faruzan) đi kênh riêng
(`AbyssStats.burstPartyFlatATK`) để scorer nhân theo số lần Q của người buff.

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

Sau khi thêm/sửa một file chu kỳ, chạy script đồng bộ — không tham số thì
nó quét các file đóng gói trong repo; file đè nằm ngoài repo thì đưa đường
dẫn vào:

```bash
python3 scripts/sync-abyss-monster-resistance.py
python3 scripts/sync-abyss-monster-resistance.py ~/Library/Application\ Support/NSLauncher/abyss-cycles/*.json
```

Script khớp từng quái với id số của game qua `gi.yatta.moe`, ghi kháng
**thật** (7 nguyên tố + Vật Lý) vào đúng dòng quái đó — `gameId`,
`resistances`, `physicalResistance`. Đây là sửa **văn bản theo dòng**, không
phải parse-rồi-ghi-lại: mỗi quái nằm gọn một dòng trong file, và
`json.dump` sẽ làm nổ nó thành hàng chục dòng mỗi quái. Quái nào script
không khớp được (tên trong chu kỳ khác tên trong file game, do dịch/đặt tên
elite riêng) thì bị bỏ qua và in ra stderr — không đoán; xem
`MONSTER_ALIASES` trong script để thêm alias đã xác nhận, hoặc để nguyên nếu
chưa chắc (xem lý do "Battle-Hardened Chimeric Volkodlak Archer" bị bỏ qua
trong chính script, làm ví dụ cho việc không nên đoán khi không có gì xác
nhận lại được).

`resistances`/`physicalResistance` **thắng** suy đoán phẳng
(`tuning.enemyOwnElementResistance`) cho quái đã khớp, nhưng
`resistanceNotes` dịch tay từ wiki vẫn thắng cả hai — ghi chú có thể nói về
một trạng thái *động* trong trận (khiên, "Rooted"...) mà bảng kháng tĩnh của
game không thấy được. Xem `AbyssFloorContext.build` và
`docs/redesign.md` mục 4.1 để biết vì sao suy đoán phẳng từng sai — cả theo
hướng bịa ra bonus không có, lẫn hướng hiểu thấp một con số thật.

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
4. **`character-kits.json.buffs` — nửa data, nửa giả định** (trước ở
   `tuning.json.talentPartyBuff`). Buff đến từ chiêu nhân vật (Bennett, Kujou
   Sara, Faruzan cho đội; Xiao cho mình). Con số hệ số được **đọc từ
   `talent-params.json`** theo `(talent, label)` nên tự cập nhật khi hệ số
   chiêu đổi; chỉ `scope`/`kind` (dòng đó nghĩa là gì) và `uptime` là viết
   tay. Cần bảng này vì nhãn không tự phân biệt được: "ATK Bonus Ratio" của
   Bennett (phần ATK cơ bản, cộng phẳng cho cả đội) và "ATK Bonus|{p} DEF"
   của Noelle (tự quy đổi cho bản thân — một `conversion`) đều không phải một
   đòn đánh và bộ lọc sát thương bỏ cả hai. Nếu `label` trôi,
   `AbyssParseDiagnostics.talentBuffUnresolved` báo lên và
   `AbyssBuildAssemblerTests` fail — buff không biến mất im lặng. Khoá
   `notes.talentPartyBuff` của `tuning.json` liệt kê những buff **cố ý chưa
   mô hình hoá**.

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
