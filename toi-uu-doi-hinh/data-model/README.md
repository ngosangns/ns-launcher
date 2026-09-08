# Data model — dữ liệu có cấu trúc cho thuật toán tối ưu đội hình

Đây là **hợp đồng dữ liệu (JSON Schema)** cho bản JSON có cấu trúc của toàn bộ
dữ liệu trong `../nhan-vat/`, `../vu-khi/`, `../thanh-di-vat/`,
`../quai-vat-la-hoan/`, `../cong-thuc-sat-thuong.md` — dùng để một chương
trình/thuật toán đọc và tính toán tự động, thay vì phải parse Markdown. Các
file `.md` ở thư mục cha vẫn là **nguồn sự thật** để con người đọc/tra cứu và
để cập nhật khi có bản game mới; JSON được sinh ra bằng cách transcribe lại
đúng nguyên văn số liệu từ các file đó (không tra cứu/suy diễn thêm) — xem
`sourceFile` trong mỗi record để đối chiếu ngược lại Markdown gốc.

> **Bản JSON đã chuyển đi.** Trước đây nằm ở `data-model/data/`, nay ở
> **[`Sources/NSLauncherApp/Resources/Abyss/`](../../Sources/NSLauncherApp/Resources/Abyss/README.md)**
> vì SwiftPM chỉ đóng gói được tài nguyên nằm trong thư mục target, và giữ
> hai bản sao thì chúng sẽ lệch nhau. Thư mục `schema/` ở lại đây — nó là
> công cụ validate, không phải dữ liệu chạy, đóng gói vào app chỉ tổ nặng.

## Cấu trúc thư mục

```
data-model/
└── schema/                          # JSON Schema (draft-07) — hợp đồng dữ liệu
    ├── character.schema.json
    ├── weapon.schema.json
    ├── artifact-set.schema.json
    ├── abyss-cycle.schema.json
    ├── damage-formula.schema.json
    ├── team-bonus.schema.json
    ├── tuning.schema.json           # tham số thuật toán (KHÔNG phải số liệu game)
    └── team.schema.json             # hợp đồng ĐẦU RA cho thuật toán tối ưu

Sources/NSLauncherApp/Resources/Abyss/     ← dữ liệu thật nằm ở đây
├── characters/                      # 1 file JSON/nation, mảng Character[]
│   ├── mondstadt.json  liyue.json  inazuma-fontaine.json  sumeru-natlan.json
├── weapons/                         # 1 file JSON/loại vũ khí, mảng Weapon[]
│   ├── kiem.json (Sword)  dai-kiem.json (Claymore)  thuong.json (Polearm)
│   └── cung.json (Bow)    phap-khi.json (Catalyst)
├── artifact-sets.json               # mảng ArtifactSet[], toàn bộ 63 bộ
├── abyss-monsters/                  # 1 file JSON / chu kỳ Trầm Thủy
├── damage-formula.json              # hằng số + công thức DPS
├── team-bonus.json                  # Cộng Hưởng Nguyên Tố, Nguyệt Triệu, Hexerei, Nightsoul Burst
└── tuning.json                      # tham số thuật toán, dùng chung Swift + Python
```

Validate toàn bộ dữ liệu ở vị trí mới:

```bash
python3 - <<'EOF'
import json, glob, jsonschema
S = 'toi-uu-doi-hinh/data-model/schema'
D = 'Sources/NSLauncherApp/Resources/Abyss'
for name, files, is_array in [
    ('character', glob.glob(f'{D}/characters/*.json'), True),
    ('weapon', glob.glob(f'{D}/weapons/*.json'), True),
    ('artifact-set', [f'{D}/artifact-sets.json'], True),
    ('abyss-cycle', glob.glob(f'{D}/abyss-monsters/*.json'), False),
    ('damage-formula', [f'{D}/damage-formula.json'], False),
    ('team-bonus', [f'{D}/team-bonus.json'], False),
    ('tuning', [f'{D}/tuning.json'], False),
]:
    schema = json.load(open(f'{S}/{name}.schema.json'))
    n = 0
    for path in files:
        doc = json.load(open(path))
        for item in (doc if is_array else [doc]):
            jsonschema.validate(item, schema); n += 1
    print(f'{name}: {n} records OK')
EOF
```

Mỗi entity có `id` dạng slug kebab-case (vd. `hu-tao`, `wolfs-gravestone`,
`viridescent-venerer`) — dùng làm khoá liên kết chéo giữa các file (vd. một
`TeamComposition.members[].characterId` trỏ tới `Character.id`).

## Liên kết chéo giữa các entity

- `Character.weaponType` ∈ `{Sword, Claymore, Polearm, Bow, Catalyst}` quyết
  định nhân vật đó chỉ dùng được vũ khí trong file `weapons/` tương ứng
  (Sword→`kiem.json`, Claymore→`dai-kiem.json`, Polearm→`thuong.json`,
  Bow→`cung.json`, Catalyst→`phap-khi.json`).
- `Weapon.bestCharacters` / `ArtifactSet.bestCharacters` chỉ là **gợi ý tham
  khảo** (ghi nhận meta cộng đồng tại thời điểm fetch) — một thuật toán tối
  ưu thật sự nên **tự tính điểm** qua `damage-formula.json` thay vì chỉ lọc
  theo gợi ý này, vì gợi ý không tính đến vai trò cụ thể trong đội hoặc
  quái/chúc phúc của mùa hiện tại.
- `AbyssCycle.floors[].chambers[].waves[].monsters[].elements` +
  `resistanceNotes` dùng để đối chiếu với `Character.element` /
  `ArtifactSet` giảm kháng (vd. Viridescent Venerer 4pc) khi tính
  `RES Multiplier` trong `damage-formula.json`.
- `AbyssCycle.blessingOfTheAbyssalMoon` là buff áp dụng cho **toàn bộ**
  Trầm Thủy (mọi tầng 1–12) suốt cả chu kỳ — khác với
  `floors[].leyLineDisorder` vốn chỉ áp dụng riêng từng tầng 9–12 (đôi khi
  khác nhau theo nửa tầng). Cả hai loại buff đều cần cộng dồn khi tính DMG
  kỳ vọng ở bước 5 bên dưới.
- `Nhà Lữ Hành (Traveler)` được tách thành 7 `Character` riêng theo nguyên
  tố (`traveler-anemo` … `traveler-cryo`) vì mỗi nguyên tố là một lựa chọn
  đội hình độc lập, dù share chung base stats.

## Quy trình một thuật toán tối ưu đội hình nên dùng

1. **Roster đầu vào** (KHÔNG có trong kho này — xem mục "Giới hạn" bên
   dưới): danh sách nhân vật/vũ khí/thánh di vật người chơi thực sự sở hữu,
   kèm cấp độ/cung mệnh/tinh luyện/substat roll thực tế.
2. Lọc `characters/*.json` + `weapons/*.json` +
   `data/artifact-sets.json` theo roster đó (nếu không có roster, coi như
   "full roster" để so sánh lý thuyết).
3. Với mỗi ứng viên (character + weapon + artifact set), tính tổng chỉ số
   build (`estimatedStats` theo `team.schema.json`) từ `baseStats` (nhân
   vật) + `atkLv90`/`subStat` (vũ khí) + bonus set (thánh di vật) + main
   stat giả định theo build phổ biến của role đó + buff tự động từ
   `team-bonus.json` (Cộng Hưởng Nguyên Tố theo tổ hợp nguyên tố của cả 4
   nhân vật, Nguyệt Triệu/Hexerei/Nightsoul Burst nếu đội có đủ nhân vật
   trong `characterIds` tương ứng).
4. Đọc `data/abyss-monsters/<chu-kỳ-hiện-tại>.json` để lấy `elements`,
   `resistanceNotes`, `weakpoint`, `mechanics` của quái từng chặng/tầng
   muốn tối ưu, và `leyLineDisorder` (buff/nerf theo nguyên tố/loại phản
   ứng của cả tầng).
5. Dùng `damage-formula.json` để tính DMG kỳ vọng của từng kỹ năng
   (`Character.elementalSkill/elementalBurst/normalAttack`, hệ số trong
   `scaling`) lên quái mục tiêu, cộng dồn theo rotation ước lượng của đội.
6. Ràng buộc khi ghép 4 nhân vật thành `TeamComposition`
   (`team.schema.json`): tối thiểu 1 `main-dps`, cân nhắc cộng hưởng
   nguyên tố (Elemental Resonance — 2+ nhân vật cùng hệ), khả năng kích
   hoạt phản ứng có lợi (Vaporize/Melt/Aggravate/Spread/Bloom
   family/Lunar/Stellar tuỳ chúc phúc tầng), vai trò hỗ trợ/khiên/heal nếu
   quái/tầng đòi hỏi (xem `mechanics`/`recommendation` trong
   `abyss-monsters`).
7. Chấm điểm (`score.estimatedTotalDamage`) và xếp hạng các
   `TeamComposition` khả thi, trả về top-N.

## Giới hạn đã biết (không nằm trong kho dữ liệu tĩnh này)

Những phần này **thay đổi theo từng người chơi** nên không thể fetch sẵn —
cần thu thập riêng (nhập tay, import từ Enka.Network/paimon.moe, hoặc hỏi
người dùng) trước khi chạy thuật toán:

- Roster thực tế: nhân vật/vũ khí/thánh di vật đã sở hữu.
- Cấp độ nuôi, số cung mệnh, cấp tinh luyện vũ khí hiện tại.
- Substat roll thực tế trên từng thánh di vật đang đeo (không phải giá trị
  lý tưởng ở cấp 90).
- Ping/độ thành thạo thao tác thực chiến (rotation lý tưởng trên giấy có
  thể không đạt được 100% trong thực chiến).

## Cập nhật dữ liệu

Khi có bản game mới hoặc mùa Trầm Thủy mới:

1. Cập nhật Markdown nguồn (`../nhan-vat/`, `../vu-khi/`, `../thanh-di-vat/`,
   `../quai-vat-la-hoan/`) theo đúng quy ước ở `../README.md`.
2. Transcribe lại đúng phần thay đổi sang JSON tương ứng ở đây (không cần
   viết lại toàn bộ nếu chỉ một vài nhân vật/vũ khí mới).
3. Với `abyss-monsters/`, luôn tạo file JSON mới theo khoảng ngày (giống quy
   ước file `.md`), không ghi đè file cũ.
