# Thiết kế lại mô hình damage — kế hoạch và tiến độ

> **2026-09-22:** Engine Swift mà tài liệu này mô tả đã được gỡ khỏi launcher.
> Dữ liệu JSON vẫn ở `Sources/NSLauncherApp/Resources/Abyss/`; trang web đọc
> nó. Phần dưới chỉ là nhật ký của engine đã xoá.

> Bắt đầu 2026-09-15, sau khi đánh giá thuật toán tìm đội hình hiện tại. Tài
> liệu này ghi lại **vì sao** cần thiết kế lại, **thiết kế thế nào**, và
> **đã làm tới đâu**. Cập nhật tài liệu này mỗi khi một pha hoàn tất — nó là
> nhật ký quyết định, không phải specs viết một lần rồi bỏ quên.

## 1. Vấn đề: mô hình không có thời gian

Bộ máy tìm kiếm (`AbyssOptimizer`) và công thức sát thương từng đòn
(`AbyssDamageMath`) đúng và đã được đo. Vấn đề nằm ở tầng giữa hai cái đó:
**cách một rotation được dựng lên**. Hiện tại, `AbyssScorer` cộng *mọi* hệ số
kỹ năng + nộ của một nhân vật đúng một lần mỗi `rotationSeconds` giây (20s),
bất kể hồi chiêu, bất kể năng lượng, bất kể nhân vật đó có đứng sân hay không
— rồi nhân bằng một loạt **hằng số dùng chung cho mọi nhân vật** để giả vờ
bù lại phần thời gian bị bỏ qua:

| Thứ thực tế quyết định DPS | Mô hình hiện tại (`tuning.json`) |
|---|---|
| Tần suất nộ (năng lượng, ER, hạt) | Nộ luôn có mỗi 20s; `energyRecharge` có 0 chỗ đọc trong `AbyssScorer` |
| Uptime của nhân vật ngoài sân | `offFieldUptime = 0.85` cho *mọi* người |
| Tỉ lệ đòn được khuếch đại (ICD, gauge, thứ tự áp nguyên tố) | `amplifyingUptime = 0.55` cho *mọi* đòn |
| Số phản ứng biến đổi/rotation | `transformativeReactionsPerRotation = 6` cho Hyperbloom lẫn Overloaded |
| Số stack buff đạt được | `assumedStacks = 2.5` |
| Buff có điều kiện lên bao lâu | `conditionalUptime = 0.6` |
| Kit hỗ trợ theo talent (Kazuha, Zhongli, Furina, Xingqiu…) | Chỉ 3 nhân vật có buff toàn đội mô hình hoá được (Bennett, Kujou Sara, Faruzan); 4 nguồn giảm kháng (không có Zhongli) |
| HP quái → thời gian dọn tầng | Không có; hai nửa tầng giả định HP bằng nhau |

Đây là **heuristic xếp hạng bậc một tốt** — đủ để nói "đội này chắc mạnh hơn
đội kia rõ rệt". Nó **không đủ** để nói đội nào tốt hơn khi hai đội gần
nhau, mà đó chính là câu hỏi người dùng đặt ra khi bấm nút "Tìm đội hình".
Thêm hằng số vào `tuning.json` không sửa được — bản thân việc dùng hằng số
chung là cái sai.

**Thước đo thành công của việc thiết kế lại:** số hằng số kiểu "uptime"
trong `tuning.json` phải tiến về 0. Đó là cách kiểm tra khách quan rằng mô
hình đã *tính* thay vì *giả định*.

## 2. Thiết kế: ba lớp dữ liệu, một pipeline theo thời gian

### 2.1. Ranh giới dữ liệu — nối tiếp nguyên tắc `character-traits.json`

| Lớp | File | Nội dung | Test của việc thuộc về |
|---|---|---|---|
| 1 | `characters/`, `weapons/`, `artifact-sets/`, **`abyss-monsters/`** | Dữ liệu game, sinh bằng script, không sửa tay | Đọc được từ file game / wiki |
| 2 | `character-kits.json` (mới, thay thế + mở rộng `character-traits.json`) | Ngữ nghĩa kit: hành động, buff, gauge — viết tay, không API nào có | Cần kiến thức về cách nhân vật *chơi* |
| 3 | `tuning.json` | Giả định của planner — độ dài rotation, ngân sách substat | Đổi vì đổi ý, không đổi vì học thêm sự thật |

Lớp 2 là chỗ toàn bộ tri thức "kit nhân vật" phải quy về **một hình dạng**:

```
action:  { id, talent, castTime, fieldTime, cooldown, energyCost,
           hits: [{ param, count, element, icdTag, gauge }],
           dot:  { param, interval, duration }?,
           buffs: [{ stat|param, scope: self|party, duration, condition }] }
kit:     { actions, energy: { particlesPerSkill }, stacks: { max, perHit }, tags }
```

Kazuha A4 = một `buff` trỏ vào EM, `duration: 8`. Zhongli = một `buff` giảm
RES 20%, `duration: 20`. Xingqiu = một `hits` gắn `icdTag: "burst"` vào đòn
thường người đứng sân. Furina fanfare = `stacks`. Tất cả cùng một cấu trúc.

### 2.2. Engine — giữ khung tìm kiếm, thay lõi chấm điểm

1. Ráp chỉ số — **giữ nguyên** (`AbyssBuildAssembler`).
2. **Dựng rotation** cho mỗi đội: tham lam theo giá trị/thời gian, ràng buộc
   `fieldTime` tổng = độ dài rotation, mỗi action ≤ 1 lần/cooldown, nộ chỉ
   khi năng lượng đủ (hạt × ER × tỉ lệ nhặt ≥ cost). **ER có giá trị thật từ
   đây.**
3. **Giải phản ứng** dọc timeline: theo dõi gauge/ICD theo (nhân vật, tag);
   số phản ứng là **kết quả**, không phải hằng số.
4. **Giải buff**: `duration` phủ lên timeline; đòn lúc `t` nhận đúng buff
   đang bật lúc `t`.
5. **Điểm = thời gian dọn** = HP quái / DPS, từng nửa; điểm plan = `t₁ + t₂`.
   Trung bình điều hoà giả định HP bằng nhau **về hưu** khi có HP thật.
6. **Tìm kiếm** — giữ nguyên (`AbyssOptimizer`), nhưng scorer mới đắt hơn
   ~10–50×, nên chạy hai tầng: scorer hiện tại lọc nhanh còn một shortlist,
   scorer rotation chạy trên shortlist đó — đúng cách `AbyssArtifactAdvisor`
   đang làm hôm nay.

### 2.3. Kiểm chứng — thay "khớp hôm qua" bằng "khớp game"

Golden fixture hiện tại (`abyss-golden.json`) chỉ chứng minh *engine hôm nay
== engine hôm qua*, chưa bao giờ chứng minh *engine == game*. `akasha.cv` chặn
bot (403, Cloudflare). **Đã có từ 2026-09-16:** cơ sở dữ liệu công khai của
gcsim (`gcsim.app/api/db`) — 5,949 đội đã mô phỏng kèm DPS; `scripts/
sync-abyss-benchmark.py` giữ đội tốt nhất của mỗi tổ hợp 4 nhân vật một mục tiêu
(`Tests/.../Fixtures/gcsim-benchmark.json`, 4,078 đội), `AbyssBenchmarkTests`
chấm lại bằng mô hình và đo **thứ tự** (Spearman) cùng độ lệch theo nhân vật.
Chạy: `ABYSS_BENCHMARK=1 swift test --filter AbyssBenchmarkTests`. Xem mục 7.6.

## 3. Lộ trình

| Pha | Việc | Xoá được hằng số nào | Trạng thái |
|---|---|---|---|
| **0** | Nhập kháng quái thật từ Yatta; đặt nền benchmark | `enemyOwnElementResistance` làm fallback thay vì luật chính | **Xong — xem mục 4** |
| 1 | Talent → `params` cấu trúc từ Yatta, thay 26 regex trong `AbyssTextParser` | — (gỡ nguồn lỗi lớn nhất) | **Xong cho 118/125 — xem mục 5** |
| 2 | `character-kits.json` cho ~30 nhân vật hay dùng nhất; nhân vật chưa có kit rơi về mô hình cũ | — | **Khung xong + 21 kit — xem mục 6** |
| 3 | Dựng rotation + năng lượng | `offFieldUptime`, hack ER | **Xong (năng lượng; thời gian đứng sân để sau) — xem mục 7** |
| 4 | Gauge/ICD/phản ứng theo timeline | `amplifyingUptime`, `transformativeReactionsPerRotation` | **Xong (đếm theo số lần áp, chưa phải timeline) — xem mục 8** |
| 5 | Timeline buff + stack | `conditionalUptime`, `assumedStacks`, phần lớn `setEffectApprox` | **Xong (cả ba; uptime tính từ rotation, chưa phải mô phỏng khung giờ) — xem mục 10** |
| 6 | Điểm = thời gian dọn — HP quái từ wiki, đối chiếu đường cong game trên Yatta | trung bình điều hoà giả định HP bằng nhau | **Xong cho tầng 9, 10, 12 (tầng 11 bị từ chối: wiki không chắc số lượng) — xem mục 11** |
| 7 | Lunar-Charged/Lunar-Crystallize gián tiếp — công thức `lunarStellar.indirect` (đã có trong dữ liệu từ Pha 4, chưa từng đọc) | — (sửa lỗi mô hình, không xoá hằng số) | **Xong — xem mục 12** |

Quy mô thật: làm đủ 125 nhân vật là việc nhiều tháng, Pha 2 là nút thắt.
~80% giá trị nằm ở Pha 0–3 trên ~30 nhân vật hay dùng, và nhờ cơ chế rơi về
mô hình cũ, app chạy trọn vẹn ở mọi bước giữa chừng.

## 4. Pha 0 — kết quả

### 4.1. Kháng quái thật, thay suy đoán phẳng

`scripts/sync-abyss-monster-resistance.py` khớp từng quái trong
`abyss-monsters/*.json` với id số của game qua `gi.yatta.moe`, lấy bảng
kháng **thật** (7 nguyên tố + Vật Lý) từ file game, ghi thẳng vào đúng dòng
quái đó (`gameId`, `resistances`, `physicalResistance`) bằng sửa văn bản
theo dòng — không `json.dump` lại cả file, vì file này viết tay mỗi quái một
dòng và `json.dump` sẽ nổ thành hàng trăm dòng thừa (lỗi đã gặp một lần với
các file schema trong phiên này).

**Bằng chứng suy đoán phẳng sai — đo trên tầng 12 mùa hiện tại**
(`enemyOwnElementResistance = 30pp` cho mọi nguyên tố quái "dùng"):

| Quái | Nguyên tố | Suy đoán cũ | Thật (Yatta) | Lệch |
|---|---|---|---|---|
| Cryo Abyss Mage | Cryo | +30pp | **+0pp** | Suy đoán bịa ra một bonus không tồn tại |
| Iniquitous Baptist | Cryo/Electro/Hydro/Pyro | +30pp mỗi loại | **+0pp** cả 4 | Như trên, ×4 |
| Icewind Suite | Anemo | +30pp | **+60pp** | Suy đoán chỉ bằng nửa thật |
| Icewind Suite | Cryo | +30pp | **+60pp** | Như trên |
| Gluttonous Yumkasaur | Dendro | +30pp | **+60pp** | Suy đoán chỉ bằng nửa thật |
| Gluttonous Yumkasaur | Pyro | +30pp | **+0pp** | Bịa ra, dù quái có 2 nguyên tố "elements" thì chỉ 1 cái thật kháng |
| Chimeric Horned Bear | Pyro | +30pp | **+20pp** | Gần nhưng vẫn sai |
| Chimeric Winged Lion | Anemo, Electro | +30pp mỗi loại | **+40pp** mỗi loại | Hiểu thấp |

Một hằng số không thể vừa "bịa ra", vừa "chỉ bằng nửa thật", vừa "gần đúng"
cho các quái khác nhau — vì game không có luật phẳng ở đây, nó có **một con
số cho từng quái**.

Đo qua golden fixture (whole-floor, không chia nửa): kháng trung bình tầng
12 đổi Anemo 30%→60%, Cryo 30%→26%, Dendro 30%→70%, Hydro 30%→10%,
Pyro 30%→14%. 307 số damage/team trong fixture dịch chuyển theo — toàn bộ
đã kiểm chứng khớp đúng công thức trung bình mới (xem
`AbyssScoreBasisTests.testTheFlatInference...`).

**Thứ tự ưu tiên khi có nhiều nguồn cho cùng một (quái, nguyên tố)**
(`AbyssFloorContext.build`):
1. `resistanceNotes` dịch tay từ wiki — có thể ghi trạng thái **động** trong
   trận (vd. "kháng Pyro -220% khi 'Rooted'") mà bảng tĩnh của game không
   thấy được.
2. `resistances` đồng bộ từ Yatta — thật, nhưng **chỉ áp dụng cho những
   nguyên tố quái đã có trong `elements`** (giữ nguyên tập "quái nào được
   tính" như trước, chỉ thay số suy đoán bằng số thật — không mở rộng số
   quái/nguyên tố tham gia trung bình, để tránh một thay đổi mô hình khác
   chưa được đo: liệu một quái không "dùng" nguyên tố X có nên góp phiếu
   "không đặc biệt kháng X" vào trung bình chung hay không).
3. Suy đoán phẳng `enemyOwnElementResistance` — giờ chỉ còn là **phương án
   cuối cùng** cho quái script chưa khớp được.

**2 quái chưa khớp** (trong 41 tên; một trong hai — Volkodlak Archer — nằm ngay tầng 12, nửa 1, nên nửa đó vẫn còn một phiếu suy đoán phẳng cho Cryo):
`Battle-Hardened Chimeric Volkodlak Archer`, `Veteran Tainted
Water-Splitting Phantasm` — không đoán, để lại dùng suy đoán phẳng như cũ.
Lý do từng cái nằm trong `scripts/sync-abyss-monster-resistance.py`.

**Chưa dùng — Vật Lý.** Dữ liệu thật lộ ra một khoảng trống khác: máy Ruin
kháng Vật Lý thật (Ruin Cruiser 30%, Perpetual Mechanical Array 70%) —
số này được decode vào `physicalResistance` nhưng **không nhân vật nào có
damage mô hình hoá là Vật Lý** nên engine chưa dùng được. Ghi lại để không
phải fetch lại, chưa đóng — nằm ngoài phạm vi Pha 0.

### 4.2. Benchmark — đổi hướng

Kế hoạch gốc: ~20 đội theo thứ hạng DPS cộng đồng đồng thuận (gcsim/Akasha).
Đã thử fetch, không khả thi (mục 2.3). Thay bằng test loại **bất biến theo
hướng** (directional invariant) — không cần số ngoài, suy trực tiếp từ luật
game, và đúng kiểu lỗi mà session này đã sửa nhiều lần:

- Một nguồn giảm kháng không bao giờ được làm điểm đội **giảm**.
- Một buff đặt tên đúng phản ứng X không được đổi damage của phản ứng Y.
- Hai đội giống hệt trừ một thành viên bật/tắt được phản ứng khuếch đại thì
  đội bật phải điểm cao hơn.

Chưa viết — việc còn lại của Pha 0, làm cùng lúc với Pha 1 vì cả hai cùng
chạm `AbyssFloorContext`/`AbyssScorer`.

### 4.3. Review sau khi triển khai — lỗi tự tìm thấy và đã sửa

Đọc lại toàn bộ diff với con mắt reviewer (2026-09-15) lộ ra bốn lỗi trong
chính phần việc trên, đều đã sửa và có test:

1. **Script đọc sai entry.** `resistance_table` lấy entry *đầu tiên* của quái
   với lý do "các entry luôn khớp nhau, đã kiểm tra" — kiểm tra trên đúng
   **một** quái. Đo lại trên cả 39: 23 quái có các entry *không* khớp (biến
   thể sự kiện/tier yếu hơn), và với 3 quái Oprichniki entry đầu là biến thể
   khác nên `physicalResistance` bị ghi 0.1 thay vì -0.2 thật. Bảng nguyên tố
   tình cờ trùng nên engine không bị ảnh hưởng — nhưng số trong file là sai,
   và lời khẳng định trong docstring là sai. Sửa: đọc entry có id trùng id
   quái (dạng gốc), từ chối chạy nếu không có; chạy lại chỉ đổi đúng 3 dòng.
2. **Cache key mù dữ liệu.** Chính Pha 0 chứng minh: cùng `periodStart`, kháng
   tầng 12 đổi hết, cache cũ vẫn khớp 7 ngày. Trước đó được ghi là "chấp nhận
   khoảng trống". Không chấp nhận nữa: `AbyssDataLibrary.dataDigest` băm bytes
   của mọi file dữ liệu lúc load (kể cả file đè), đưa vào key. Chi phí không
   đo được cạnh việc parse.
3. **Cache key nhạy thứ tự roster** trong khi `AbyssOptimizer` lọc theo tập id
   và tra cứu theo id — thứ tự không đổi kết quả. Test cũ ghim hành vi sai kèm
   lý do ngược. Sửa: sort theo id trong key; test đảo lại.
4. **Tên quái có ký tự ngoài ASCII** sẽ không bao giờ khớp: `json.dumps(name)`
   sinh `\u00e1` còn file ghi ký tự thật. Chưa gây hại vì mùa này toàn tên
   tiếng Anh. Sửa `ensure_ascii=False`.

Ngoài ra: README nói script xử lý được file đè nhưng script chỉ quét thư mục
repo → thêm tham số đường dẫn; hai chỗ sai sự thật trong chính tài liệu này
(Volkodlak Archer "ở tầng khác 12" — thực ra ở tầng 12 nửa 1; "HP đã có từ
Pha 0" — Pha 0 cố tình không lấy HP).

## 5. Pha 1 — kết quả

### 5.1. Nguồn số liệu talent: file game, không phải văn xuôi

`scripts/sync-abyss-talent-params.py` lấy từng talent của 118 nhân vật (7 Nhà
Lữ Hành không có avatar riêng trên Yatta — vẫn đi đường cũ) và ghi **nguyên
văn** vào `talent-params.json`: dòng mô tả như game viết
(`"Skill DMG|{param1:P} Max HP"`) và mảng `params` theo cấp 1–15. File không
chứa suy diễn nào; `AbyssTalentReader` (Swift) đọc nó theo một grammar nhỏ
trên từ vựng khép kín — mọi hình dạng biểu thức đã được liệt kê trên toàn bộ
dữ liệu **trước** khi viết reader (`@`, `@+@`, `@×3`, `(@ ATK+@ EM)×2`,
`@/@`, `@ Max HP`, …), và mỗi luật là một test.

Ba lần script từ chối chạy, đều đúng: (a) dòng mô tả **không** giống nhau ở
mọi cấp — 43 talent đổi độ chính xác format, 5 đổi chữ, và 2 (Freminet, Jean
cấp 15) **đánh lại số thứ tự placeholder** → phải lưu dòng theo cấp
(`lineOverrides`), không được lấy một bản; (b) Ayaka/Mona có "chạy nước rút"
là talent type-0 không bảng; (c) Ningguang đánh một đòn ghi "Normal Attack
DMG" chứ không "1-Hit". Mỗi lần là một giả định sai bị bắt bởi dữ liệu.

### 5.2. Hai nguồn lệch ở đâu — đo trên 118 nhân vật

`AbyssTalentSourceComparisonTests` chạy cả hai đường và in bảng. **16/118 khớp
trong 0,5%.** Các lệch chia thành nhóm, đa số là lỗi transcription:

| Nhóm | Ví dụ | Phía đúng |
|---|---|---|
| **Đòn thường = 0** | 28 nhân vật (toàn bộ Sumeru + Natlan): bản transcription ghi "chưa xác nhận" cho cả bảng đòn thường — mô hình đã chấm họ với đòn thường và đòn nặng bằng **0** | Game |
| Đòn cùng trúng bị đọc là lựa chọn | Hu Tao 5-Hit `{a}+{b}`: prose lấy max, game cộng | Game |
| Buff đọc thành đòn | Hu Tao "ATK cộng thêm 6.256% Max HP"; Sethos/Xiao burst là buff thuần | Game |
| Sai cơ sở | Candace/Columbina scale HP, Linnea DEF, Nefer EM, Illuga/Chiori có cả EM/DEF lẫn ATK | Game |
| Số chép sai | Hu Tao trọng kích 153% (đúng: 243%); Xingqiu skill 3.02% (đúng: 302%) | Game |
| Biến thể bị cộng dồn | Bennett/Beidou/Freminet/Shenhe: prose cộng mọi cấp giữ chiêu, reader lấy max | Game (reader) |
| Chế độ (stance) burst/skill | Raiden, Cyno, Varka, Mavuika: bảng liệt kê cả chuỗi đòn thường của chế độ; reader cộng mỗi dòng một lần (định nghĩa burst của mô hình), prose chỉ đọc đòn đầu | Không bên nào — cần Pha 3 (thời gian) |

Golden fixture tái tạo: 118/125 profile đổi; tầng 12 đội đầu **giữ nguyên**
(Bennett/Diona/Hu Tao/Venti), tầng 9–11 đổi đội đầu; điểm đội đầu +6–8%.

### 5.3. Giới hạn còn lại — đã ghim bằng test, chưa sửa

- **Biến thể mà chữ không nói lên**: Varesa "Rush DMG" / "Fiery Passion Rush
  DMG" (một chế độ), Bennett "Press DMG" / "Charge Level 2 DMG" (một lần bấm)
  vẫn cộng — đây là tri thức kit, thuộc `character-kits.json` (Pha 2 — đã
  làm cho 21 nhân vật, mục 6). 18 dòng đòn thường chưa phân loại (chuỗi đòn
  của chế độ, đòn phụ arkhe, Riptide) được ghim đích danh trong
  `AbyssMissingMechanicsTests` (còn 5 sau Pha 2).
- **7 dòng DMG cố ý không đọc** (Razor/Wanderer/Wriothesley/Yoimiya "% Normal
  Attack DMG" là *phần* của đòn khác; Lauma "per Verdant Dew"; Nicole "ATK của
  nhân vật khác") — ghim trong `AbyssTalentReaderTests`.
- **Đòn nặng khác cơ sở**: so hệ số thô giữa 246% ATK và 14.5% Max HP là vô
  nghĩa (Neuvillette: dòng HP mạnh gấp bốn). Giải quyết bằng luật: nhãn trong
  `character-kits.json` chỉ đích danh dòng nào là đòn nặng thì dòng đó thắng;
  hệ số chỉ quyết định giữa các dòng cùng hạng. Sethos được thêm nhãn
  "Shadowpiercing Shot" vì lý do này.
- **Chuyển đổi chỉ số (HP→ATK) chưa có chỗ đứng**: Hu Tao E ("ATK cộng thêm
  6.256% Max HP") và Trượng Hộ Ma ("ATK from HP") trước đây *vô tình* được
  tính vì prose đọc dòng buff của Hu Tao thành một đòn scale HP; nay đòn đó
  đúng là buff nên HP của Hu Tao không còn được tính gì — cả hai đều đúng về
  số liệu và đều thiếu cùng một cơ chế. Thuộc `character-kits.json` (Pha 2:
  `conversions`), và weapon passive cần cùng khung đó thay vì regex
  "buff|bonus" hiện tại. **Đã làm ở Pha 2 — mục 6.**
- **Basis chủ đạo đếm số dòng**, không cân theo hệ số: Chiori (ATK+DEF mỗi
  đòn) và Kokomi/Nilou/Dehya/Layla rơi về ATK vì hoà. Chỉ ảnh hưởng phân bổ
  substat; sửa bằng cân theo `hệ số × chỉ số điển hình` là việc riêng.
- `AbyssTextParser` **chưa xoá**: còn phục vụ 7 Nhà Lữ Hành (Pha 2 đã chuyển
  `buffs` sang đọc `talent-params.json`, nên đây là chỗ cuối).

## 6. Pha 2 — kết quả

### 6.1. Một hình dạng cho tri thức kit

`character-traits.json` đổi tên thành **`character-kits.json`** và mang thêm
ba thứ mà bảng talent của game *không nói được*, mỗi thứ là **tham chiếu** vào
`talent-params.json` (nhãn dòng đúng chữ game, hoặc chỉ số param) đọc ở đúng
cấp talent của nhân vật, kèm `note` trích chữ game và nêu rõ giả định:

| Khoá | Câu hỏi nó trả lời | Ví dụ |
|---|---|---|
| `hits.{skill,burst,combo,charged}` | Một lần dùng chiêu / một chuỗi đòn thường thật sự gồm những dòng nào, mỗi dòng mấy lần | Bennett E = `Press DMG` ×1; Raiden combo = 5 dòng Isshin của bảng burst + 300 × param3 (60 stack × 5 đòn) |
| `conversions` | Kit đổi chỉ số nào ra ATK | Hu Tao `ATK Increase\|{p} Max HP`, Noelle `ATK Bonus\|{p} DEF` — đổi *từ* gì là hậu tố game viết, file không được nói khác |
| `buffs` (`scope: party\|self`) | Talent cộng gì, cho ai | Bennett `ATK Bonus Ratio` (đội, phần ATK cơ bản), Xiao `Normal/Charged/Plunging Attack DMG Bonus` (mình) |

Hai quyết định thiết kế đáng ghi:

- **Slot ≠ category.** Reader tự suy thì "dòng đòn thường" vừa là *chuỗi đòn*
  (× `normalCombosPerRotation`) vừa là *bucket Normal Attack DMG*. Kit tách
  hai thứ: `AbyssDamageProfile.Term` có thêm `action` (combo/charged/ability
  — tần suất) bên cạnh `category` (buff). Isshin của Raiden: `action: combo`,
  `category: burst`. Không có cái này, kit đầu tiên chạy đã hạ Raiden 47% vì
  chuỗi đòn của cô bị đếm *một lần* như một chiêu.
- **Chuyển đổi là tỉ lệ, không phải số.** `AbyssStats.atkFromHPRate` nhân với
  HP *cuối cùng* của sheet, nên sands HP% / substat HP tự thành chỉ số damage
  của Hu Tao trong tìm kiếm — không cần luật "Hu Tao thì build HP". Vũ khí
  cùng loại (Hộ Ma "ATK from HP", Ngọc Cắt "ATK from HP", Engulfing "ATK from
  Energy Recharge over 100%") đi cùng khung (`weaponConversionRules`) — trước
  đây ba dòng đó không chứa chữ "buff|bonus" nên bị bỏ, và một lần tinh luyện
  Hộ Ma chỉ đáng đúng phần HP%.

Fallback nguyên vẹn: nhân vật không có entry, hoặc slot không ghi đè, đi theo
luật chung của `AbyssTalentReader`; slot ghi đè thì reader *không* báo "dòng
chưa phân loại" cho bảng đó nữa — kit đã phân loại bằng cách nói chuỗi đòn là
gì.

### 6.2. 21 kit đầu — chọn theo lỗi Pha 1 chỉ ra, không theo độ nổi tiếng

Mỗi kit viết từ chữ game (Yatta `talent.description`), trích trong `note`.

| Nhóm | Nhân vật | Kit nói gì |
|---|---|---|
| Biến thể một lần bấm | Bennett, Lisa, Beidou, Freminet | Press ×1; 3 Press + Hold stack 3; Base + 2 × "DMG Bonus on Hit Taken" (dòng "Bonus" mà là hệ số đòn); Upward Thrust + 4 Frost + Level 4 |
| Chế độ thay đòn thường | Raiden, Cyno, Tartaglia, Mavuika, Varka, Varesa, Xilonen, Kinich | Chuỗi đòn/đòn nặng lấy từ bảng E/Q của chế độ; Xilonen/Kinich `charged: []`; Cyno `burst: []` |
| Dòng là *phần* của đòn khác | Wanderer, Yoimiya, Wriothesley, Razor | `factor` × param (Blazing Arrow = 161.7% đòn thường); Razor: 4 đòn + 4 đòn sói (category burst) |
| Chuyển đổi | Hu Tao, Noelle | HP→ATK, DEF→ATK, uptime 1 (chế độ là cửa sổ sát thương) |
| Đòn nhảy là kit | Xiao | "Một chuỗi đòn thường" = một High Plunge + self-buff burst; thấp hơn thực (~6 vs 10–12 đòn nhảy/rotation) nhưng thay cho 0 |
| Chỉnh nhỏ | Iansan, Lauma, Lyney | Swift Stormflight là đòn nặng; Hold + Sanctuary; Prop Arrow + Pyrotechnic Strike, E với 5 stack |

Đo trên golden fixture (roster mẫu): **21/125 profile đổi**, đúng danh sách kit,
không nhân vật nào đổi basis. Điểm solo: Hu Tao ×1.86, Xilonen ×1.74, Yoimiya
×1.58, Wriothesley ×1.49, Raiden ×1.47, Cyno ×1.37; giảm: Tartaglia ×0.79
(burst Melee+Ranged không còn cộng đôi, Riptide Flash/Burst của tư thế cung bỏ),
Mavuika ×0.81, Xiao ×0.84, Bennett ×0.88. Đội đầu tầng 12 giữ nguyên
(Bennett/Diona/Hu Tao/Venti), điểm +72% — gần hết là ATK của Hu Tao gấp đôi
nhờ chuyển đổi, đúng với game (E cộng ~2k ATK ở 33k HP).

### 6.3. Cố ý chưa có kit, và vì sao

- **Furina**: Salon Members đánh theo chu kỳ, bảng game không ghi interval →
  số lần/lượt là tri thức Pha 3 (rotation). Reader chung đếm mỗi dòng một lần
  — thấp, nhưng không bịa số.
- **Columbina, Sandrone**: dòng biến thể theo phản ứng Lunar/Stellar — Pha 4.
- **Charlotte, Neuvillette, Furina, Lyney** (arkhe Spiritbreath Thorn): đòn
  theo chu kỳ 6–9s — Pha 3.
- **Navia**: bonus Crystal Shrapnel chỉ có trong chữ mô tả, không có trong
  bảng — cần `value` literal, để sau.
- **Mavuika** bonus Fighting Spirit cho đòn thường/nặng trong 7s Crucible,
  **Hu Tao** A4 (+33% Pyro dưới 50% HP), **Xiao** A1 (+5%/3s): buff có thời hạn
  hoặc điều kiện — Pha 5.
- Còn lại của mục 5.3 (basis chủ đạo đếm dòng, `AbyssTextParser` cho Nhà Lữ
  Hành) chưa đụng.

## 7. Pha 3 — kết quả

### 7.1. Nguồn số hạt: wiki, đối chiếu gcsim

Yatta có CD, năng lượng Q, gauge và ICD (`advancedProps` — dùng được cho Pha
4) nhưng **không có số hạt**. Hai nguồn cộng đồng đã xét:

| Nguồn | Có gì | Vấn đề |
|---|---|---|
| gcsim (MIT, commit `a086a05`) | 109/118 nhân vật, số hạt trong code Go kèm ICD và xác suất | Phải đọc code từng người để ra "mỗi lần E" |
| Genshin Impact Wiki | Template `{{Talent Note|particles|…}}` có cấu trúc trên trang kỹ năng: `2.25|3` (nhấn/giữ), `each of Oz's attacks|0.67` | 13 trang không có ghi chú |

Chọn wiki làm nguồn chính (`scripts/sync-abyss-particles.py`, lưu tham số
template nguyên văn + revid), gcsim để đối chiếu: **khoảng 50 nhân vật đã so
đều khớp** (0.67 của wiki = xác suất 67% trong gcsim; 2.25 của Bennett = 2 hoặc 3
với 25%). Dạng "mỗi sự kiện" không thể thành "mỗi lần E" chỉ bằng dữ liệu —
số đòn của Oz là tri thức kit — nên nằm ở `character-kits.json → energy`
kèm nguồn nhịp đánh (bảng talent, mô tả kỹ năng, hoặc hằng số gcsim).

### 7.2. Mô hình

Với mỗi thành viên i, không phụ thuộc trang bị:

- Số lần E: `s = min(maxSkillCastsPerRotation = 2, T / CD)`, kit ghi 1 cho E
  kiểu vào trạng thái.
- Năng lượng trước ER: mỗi hạt của j cho i giá trị 3 (cùng nguyên tố) hoặc 1,
  nhận đủ nếu i đứng sân lúc hạt tới, 60% nếu không. Hạt E tức thời tới khi
  người dùng còn trên sân; hạt triệu hồi tới người đang đứng sân — nên mỗi
  thành viên chỉ mang **hai** con số: năng lượng khi ngoài sân và khi trên sân.
- Số lần Q: `min(1, T / CD, năng lượng × ER / năng lượng Q)`.
- Sát thương = `s × E + Q × burst` (+ chuỗi đòn nếu đứng sân, nhân cửa sổ
  stance). Buff đội từ Q nhân số lần Q của người buff.

`offFieldUptime` bị xoá. Cát của support/shielder được tìm như mọi ô khác —
điểm giờ thấy "Q có sẵn không". Circlet Healing Bonus của healer vẫn ghim.

Tối ưu vẫn chính xác, không xấp xỉ: tổng = Σ ngoài sân + max theo X của (phần
thêm khi X đứng sân), vẫn một lần tính split mỗi thành viên.

### 7.3. Đo trên golden

Đội đầu cả bốn tầng **giữ nguyên** (Bennett/Diona/Hu Tao/Venti), điểm −2%
đến +1%; phần của Bennett và Venti tăng (hồi chiêu ngắn → 2 lần E). Điểm solo
đổi nhiều nhất đúng ở nhân vật ăn năng lượng: Cyno ×0.52 (và giờ tự chọn
Engulfing Lightning), Xiao ×0.63, Raiden ×0.75; tăng: Beidou ×1.32, Candace
×1.31, Skirk ×1.24 (E hồi nhanh).

### 7.4. Giới hạn — đã ghi, chưa làm

- **Thời gian đứng sân chưa có**: `normalCombosPerRotation`/`chargedAttacksPerRotation`
  vẫn là hằng số; mỗi lần dùng E/Q không trừ thời gian của người đứng sân. Cần
  frame data (gcsim có) — không bịa thời gian cast.
- **Hạt quái rơi = 0** (giả định thận trọng — đòi ER hơi cao). gcsim có bảng
  rơi theo ngưỡng HP từng quái; cần thời gian dọn (Pha 6).
- **Năng lượng ngoài hạt**: hồi năng lượng của Q Raiden, Favonius/Sacrificial,
  Emblem, cung mệnh — chưa mô hình hoá.
- **Cửa sổ stance chỉ gating đòn của người đứng sân**; Raiden ngoài Isshin
  đánh thường không được đếm.
- **Buff đội từ Q tính theo năng lượng ngoài sân** kể cả khi người buff đứng
  sân (tránh vòng lặp đội hình ↔ buff ↔ sát thương).
- **Trung vị** cho 10 nhân vật: 7 Nhà Lữ Hành, Linnea (không ghi chú, không có
  trong gcsim), Lohen và Zibai (sự kiện không có nhịp để đếm).

### 7.5. Kiểm tra sau Pha 3: golden chỉ nhìn 15 nhân vật

Câu hỏi "vì sao Hu Tao đứng đầu mọi tầng" hoá ra sai tiền đề: golden fixture
chạy trên `roster.example.json` (15 nhân vật), nơi Hu Tao là carry mạnh nhất.
Chạy tầng 12 trên **toàn bộ** 125 nhân vật mới lộ lỗi thật — Scarlet Proof là
bộ tốt nhất của 95/125 nhân vật và cả bốn thành viên đội đầu đều mặc nó. Không
lỗi nào trong số này là đánh giá về bộ; tất cả là tên bonus bị đưa vào "+%
sát thương mọi đòn":

| Lỗi | Ví dụ | Sửa |
|---|---|---|
| Bonus có chữ DMG không khớp luật nào → `dmgAll` | "Stellar Swirl DMG +40%" (Scarlet Proof), "Party Stellar Glimmer DMG +50%" → `partyDMG`, "Lunar-Charged DMG Bonus" trên vũ khí | Tên phản ứng không định giá (`AbyssBuildAssembler.unpriced`); `dmgAll` chỉ còn cho các dạng "DMG", "DMG Bonus", "DMG (…)", "DMG vs …" |
| Physical DMG → `dmgAll` | Bloodstained + Pale Flame 2+2 = +50% mọi đòn | Không định giá — không đòn nào là vật lý |
| "Party Incoming Healing/Shield Strength" → `partyDMG` | Tenacity +30% sát thương cả đội | Không định giá |
| Bonus 4 món đọc từ data **cộng thêm** ước lượng tay | Shimenawa 0.5 + 0.35; Obsidian Codex +40% CRIT cho người không phải Natlan | Ước lượng thay cho bonus 4 món đọc được |
| Ước lượng tay định giá phản ứng / nguyên tố khác như đòn của người mặc | VV 0.15, Thundering Fury 0.24 cho mọi đòn; Crimson Witch cho người không hệ Hỏa; Fragment of Harmonic Whimsy (+28%) cho người không có Bond of Life | VV, TF về 0; `requirement` thêm `pyro/hydro/geo/cryo/bond-of-life` |

Cùng lượt: Lohen (bảng E là chuỗi đòn của Masterstroke, bị đọc thành ~18.7×
một lần E) có kit như Tartaglia. Test ghim từng lỗi: `AbyssSetBonusRoutingTests`.

Sau khi sửa, trên toàn bộ nhân vật: bộ được chọn nhiều nhất là A Day Carved
from Rising Winds (55), Blizzard Strayer (17, chỉ hệ Băng), Vermillion (13);
đội đầu tầng 12 là Yoimiya/Bennett/Escoffier + support Anemo — khớp buff
"+75% đòn thường Hỏa" của tầng. Golden (15 nhân vật) giữ đội đầu, điểm −15%
đến −18%.

**Bài học cho các pha sau:** đo trên toàn bộ nhân vật, không chỉ golden.
Còn lại, đã biết: số chuỗi đòn thường cố định 6 mỗi rotation bất kể chuỗi dài
3 hay 6 đòn (thứ hạng nhạy với con số này — cần frame data); CRIT Rate của A
Day Carved chỉ dành cho Hexerei nhưng đang tính như điều kiện chung.

### 7.6. Benchmark gcsim — lần đo đầu

3,645 đội so được (nhân vật 5★ đều C0; 4★ giữ cung mệnh). **Spearman 0.19** —
thứ tự của mô hình chỉ liên quan yếu tới simulator. Độ lệch theo nhân vật (log
mô hình/gcsim, trừ trung vị) chỉ ra đúng hai lỗ cấu trúc:

| Hướng | Nhân vật | Nguyên nhân |
|---|---|---|
| Đánh giá cao | Diluc +0.62, Amber +0.61, Eula +0.53, Tartaglia +0.47, Yoimiya +0.45, Wriothesley +0.38, Hu Tao +0.34, Rosaria +0.29, Bennett +0.26 | `normalCombosPerRotation = 6` cho mọi người, bất kể chuỗi dài bao lâu |
| Đánh giá thấp | Neuvillette −0.43, Sethos −0.57, Tighnari −0.30, Varesa −0.50 | `chargedAttacksPerRotation = 2` — carry đòn nặng spam đòn nặng; đòn nhảy chưa có |
| Đánh giá thấp | Lauma −0.59, Columbina −0.46, Ineffa −0.39, Aino, Nicole | Phản ứng Lunar — Pha 4 |

### 7.7. Thời gian đứng sân từ frame data — Spearman 0.19 → 0.34

`normalCombosPerRotation = 6` và `chargedAttacksPerRotation = 2` bị xoá. Người
đứng sân tấn công trong **thời gian rotation còn lại** sau mọi lần cast của cả
đội, bằng vòng tấn công tốt nhất mở cho nhân vật:

- Độ dài chuỗi đòn thường, đòn nặng, cast E/Q: `frames.json`, sinh bằng
  `scripts/sync-abyss-frames.py` từ frame data gcsim (`attackFrames[i]
  [ActionAttack]`, `chargeFrames`, `aimedFrames[1]`, `skillFrames[ActionSwap]`…).
  109 nhân vật; 40 trường không nhận ra mẫu → trung vị, báo ở
  `diagnostics.framesEstimated`.
- Thời gian đứng sân của X = `rotationSeconds − Σ(cast ngoài sân của người khác,
  mỗi lần + swapSeconds) − cast của chính X`. `swapSeconds = 0.2` là giả định
  theo `swap_delay` mặc định của gcsim.
- Vòng tấn công: chuỗi đòn; chuỗi + đòn nặng; đòn nặng liên tục chỉ cho cung
  (mũi ngắm không tốn thể lực) hoặc kit `attack.loop = charged`.
- Kit: Neuvillette — Equitable Judgment 8 tick trong ~3.17s (gcsim
  `charge.go`, đủ 3 giọt nước); Xiao — một đòn nhảy ~1.1s.

Benchmark: **Spearman 0.336** (từ 0.192). Carry đánh thường chuỗi dài hết lệch
lớn (Hu Tao ra khỏi danh sách, Eula +0.53 → +0.24, Yoimiya +0.45 → +0.27),
Neuvillette từ −0.43 thành +0.25. Còn lệch: Sethos −0.49, Tighnari −0.30 (đòn
nặng nhiều mũi), Varesa −0.36 (đòn nhảy chưa có), các đội Lunar −0.3…−0.4 (Pha
4); Amber +0.57, Tartaglia +0.54.

Tác dụng phụ đã xử lý: đội top của hai nửa giờ hay dùng chung vài support, và
bước ghép hai nửa quét 182 triệu cặp trước khi gặp cặp hợp lệ (31s). Thêm cận
dưới chính xác theo từng id — quét bắt đầu sau đội nửa sau cuối cùng còn giữ
một id của đội nửa đầu — còn 0.12s.

## 8. Pha 4 — kết quả

### 8.1. Benchmark trước khi làm: lệch theo loại phản ứng

Nhóm độ lệch (log mô hình/gcsim, trừ trung vị) theo phản ứng của đội chỉ đúng
chỗ hai hằng số sai: Melt +0.25, Vaporize +0.16 (`amplifyingUptime = 0.55` cho
*mọi* đòn); Dendro+Electro −0.20…−0.28 (Aggravate/Spread **chưa từng được tính**
— `damage-formula.json.catalyze` chỉ được đọc lấy đường EM); Lunar-Charged −0.31.

### 8.2. Mô hình: số lần áp nguyên tố thay hằng số

- **`gauge.json`** (`scripts/sync-abyss-gauge.py`, Yatta `talent.advancedProps`):
  gauge (U) và nhóm ICD của từng hit, 118 nhân vật; 2 luật ICD lạ (Arlecchino,
  Chevreuse) ghi lại chứ không đoán.
- **`AbyssApplicationProfile`**: số lần áp mỗi chuỗi đòn / đòn nặng / lần E / lần
  Q theo luật ICD của game (hit đầu, rồi mỗi N hit hoặc mỗi T giây). Đòn thường
  chỉ áp nguyên tố nếu là catalyst, mũi sạc đầy của cung, hoặc kit
  `attack.infused` — 19 nhân vật, mỗi người kèm câu game "converted to Pyro DMG"
  / "infused with". Triệu hồi dùng `energy.eventsPerCast`; vùng/DoT có ICD theo
  thời gian áp một lần mỗi chu kỳ ICD suốt dòng Duration dài nhất. Bảng có dòng
  "Press" thì bỏ dòng Hold/Charge Level (Bennett: 1 hit mỗi lần E, không phải 6).
- **Theo từng người đứng sân** (`TeamDamageContext.variants`): đứng sân đổi đòn
  thường của ai có áp nguyên tố, nên mỗi ứng viên có biến thể riêng:
  - Vaporize/Melt: phần hit **áp nguyên tố** của người kích hoạt được khuếch
    đại, theo lượng aura (U) phía kia đặt ra so với lượng một lần kích hoạt tiêu
    (×2 chiều mạnh, ×0.5 chiều yếu);
  - Aggravate/Spread: mỗi lần áp của nhân vật Electro/Dendro cộng
    `1.15/1.25 × level multiplier × (1 + 5·EM/(EM+1200))` vào base damage;
  - phản ứng biến đổi: số lần = số lần áp của phía ít hơn trong cặp.
- Dòng talent **là** sát thương Lunar ("Lunar-Charged DMG" của Flins, Columbina)
  tính theo công thức Lunar trực tiếp: hệ số phản ứng, đường EM Lunar, không DMG
  bonus, không DEF.

### 8.3. Đo lại

**Spearman 0.336 → 0.368** (3,645 đội). Theo nhóm: Melt +0.25 → +0.17, Vaporize
+0.16 → +0.10, Dendro+Electro −0.28 → +0.06, Hyperbloom −0.10 → +0.15, Burgeon
+0.24 (không đổi), Lunar-Charged −0.31 → −0.31. `teamDamage` giờ cộng cả đội cho
từng ứng viên đứng sân (4×4 phép tính thay vì 4); lượt chạy mặc định ~16s → ~21s,
sau khi bỏ dictionary theo nguyên tố trong vòng nóng.

### 8.4. Còn lại

- **Lunar gián tiếp** (phản ứng Lunar do cả đội kích hoạt, chia 0.6/0.3/0.05/0.05
  theo người góp) chưa có — lý do chính đội Lunar-Charged vẫn −0.31 và Columbina
  −0.37, Ineffa −0.31.
- **Chưa phải timeline**: aura không phân rã theo thời gian, các phản ứng không
  tranh aura của nhau (Vaporize và Overloaded cùng dùng một lần áp Pyro).
- Quicken uptime là ước lượng thô (`2 × min(Dendro, Electro) / số lần áp`).
- Hyperbloom/Burgeon/Superconduct đang +0.15…+0.24: ICD riêng của phản ứng
  (tối đa 2 lần mỗi 0.5s trên một mục tiêu) và giới hạn lõi Bloom chưa có.

## 9. Chưa xác minh, cần làm trước Pha 4–5

- ~~Yatta có ghi hạt năng lượng không~~ — không; dùng wiki + gcsim (mục 7.1).
- Gauge và ICD: Yatta `talent.advancedProps` có `elementalGaugeTheory` ("1U",
  "2U", "1U, 2.1s") và `internalCooldown` ("Normal Attack, 2.5s/3 Hits") cho
  từng đòn — đủ cho Pha 4 nếu tên đòn ở đó khớp được với dòng của
  `talent-params.json` (tên không trùng hẳn: "Normal Attack 1-Hit" vs
  "1-Hit DMG").

## 10. Pha 5 — kết quả

### 10.1. Benchmark trước khi làm: nhóm theo vũ khí và bộ thánh di vật

Benchmark có thêm hai loại nhóm: `W:` theo vũ khí của đội (gcsim chọn) và `S:`
theo bộ mô hình chọn. Soát lại dữ liệu vũ khí đang đọc thì lỗi không nằm ở
uptime mà ở chính các dòng stat: `weapons/*.json` là bản tóm tắt văn xuôi —
The Catch 12% ST Nộ (game ghi 16%) và "Elemental Burst CRIT Rate" chảy vào crit
của *mọi* đòn; Kitain Cross Spear mang dòng của vũ khí khác; The Widsith, The
Stringless, Wandering Evenstar không có dòng nào. Bộ thánh di vật thì 34 mức
%DMG gán tay.

### 10.2. Dữ liệu: chữ game ở một file, ý nghĩa ở file kia

- **`passive-text.json`** (`scripts/sync-abyss-passives.py`, Yatta weapon
  `affix` R1–R5 và reliquary `affixList`): chữ game tiếng Anh của 236 vũ khí và
  63 bộ. Số nào đổi theo tinh luyện thì game bọc thẻ màu — mỗi thẻ thành một cột
  R1–R5.
- **`passives.json`** (viết tay, như `character-kits.json`): mỗi hiệu ứng là
  `stat`, `on` (loại đòn), `scope` (bản thân / cả đội / trừ người mang / người
  đứng sân), `trigger` (một hoặc nhiều điều kiện), `duration`, `stacks`,
  `cooldown`, `from` (tỉ lệ theo EM/HP/DEF/ER). `value` là **số R1** — engine
  tìm cột có R1 đó và đọc R2–R5; thời lượng, stack, hồi chiêu phải có trong chữ
  game. Không giải được → `diagnostics.passiveReferencesUnresolved`, ghim rỗng.
- Thử viết parser cho văn xuôi trước: nó sai nghĩa theo kiểu im lặng ("Taking DMG
  disables this effect for 5s" thành buff 5s; Elegy for the End gán nhầm thời
  lượng). Bản nháp 299 entry do 6 agent soạn theo cùng một brief, qua validator
  tự động với chữ game, rồi soát tay các vũ khí/bộ dùng nhiều nhất.

### 10.3. Engine: đồng hồ của người mang, cổng theo đội

- **`AbyssBuffTimeline`** tính số stack trung bình *trong lúc sát thương mà buff
  tăng xảy ra*, theo từng loại đòn, từ rotation solo của người mang (số lần E/Q,
  số hit mỗi lần cast, tỉ trọng sát thương đòn thường/nặng/E/Q): buff sau E phủ
  thời gian đánh thường theo sau nó; buff cộng stack theo hit leo dần qua các hit
  của một lần cast (vô nghĩa với E một hit, gần đầy với Q sáu hit); buff có thời
  lượng và hồi chiêu mà không tự tính thời gian thì bị chặn ở `duration/cooldown`
  (lá Sapwood 12s mỗi 20s). Buff cả đội tính theo phần rotation nó được duy trì.
- Điều kiện theo **người mang** quyết định ngay (Nightsoul, Bond of Life, loại
  vũ khí). Quy ước một mục tiêu, đầy máu như benchmark: không hạ quái, không dưới
  ngưỡng HP, không "≥2 kẻ địch".
- Điều kiện theo **đội** (aura nguyên tố, khiên, hồi máu, phản ứng, số thành viên
  cùng/khác nguyên tố, Moonsign Ascendant, Hexerei) không quyết được lúc dựng
  sheet — sheet dựng một lần cho mỗi nhân vật rồi chấm trong hàng trăm đội. Chúng
  đi theo sheet dưới dạng `AbyssGates` (8 ô cố định) và scorer mở cổng theo
  `AbyssTeamConditions` của từng thành viên. Cộng hưởng Nham (DMG khi có khiên)
  giờ theo đội có khiên thật, không phải 60%.
- Crit theo loại đòn (`critRateFor`/`critDMGFor`), tỉ lệ theo chỉ số khác gộp khi
  sheet hoàn chỉnh (`AbyssConversions`), buff cả đội của bộ 4 món khử trùng lặp
  theo đúng lượng người mặc thứ hai đã cộng.
- Hiệu năng: kiểu SIMD generic mới làm lượt chạy mặc định 21s → 65s trong build
  debug (mỗi subscript là một lần tra metadata); đóng gói điều kiện đội vào hai
  `UInt64`, lưu cổng bằng struct cố định, và tính sẵn phần đóng góp của mỗi bộ
  cho mỗi nhân vật → **19s**.
- Popover bộ thánh di vật liệt kê buff mô hình tính ("+7.5% Pyro DMG ×3 (có điều
  kiện)") thay cho "≈ +20% ST (ước lượng thủ công)".

### 10.4. Đo lại

**Spearman 0.368 → 0.394** (3,645 đội): 0.379 khi thay dữ liệu và timeline;
0.389 khi áp `duration/cooldown` cho buff không tự tính thời gian và sửa trigger
The Widsith (vào sân, 10s mỗi 30s — bản nháp ghi "đứng sân": +60% ATK suốt thời
gian đứng sân); 0.394 khi Finale of the Deep/Flowing Purity tự cấp Bond of Life
(vế "khi Bond of Life bị xoá" cần đội có hồi máu, không cần kit có Bond of Life).
Theo nhóm: Wriothesley +0.40 → +0.28 sau khi sửa The Widsith; Lunar-Charged
−0.31 → −0.28; Melt/Vaporize, Hyperbloom, Burgeon gần như không đổi (thuộc Pha 4).

### 10.5. Còn lại

- **Đòn sát thương thêm** của vũ khí/bộ chưa được tính: Sequence of Solitude
  (−0.39), Crescent Pike, The Viridescent Hunt, Cinnabar Spindle (cộng ST theo
  DEF), Echoes of an Offering, Ocean-Hued Clam, Song of Days Past.
- Kênh cả đội không mang CRIT, ER, HP hay bonus chỉ cho vài loại đòn (Xiphos
  30% ER cho đồng đội, Freedom-Sworn +16% đòn thường/nặng) — những vế đó bỏ qua.
- Cổng đội còn thô: "aura Pyro" mở khi đội có thành viên Pyro, chưa theo tỉ lệ
  thời gian aura tồn tại; "được hồi máu" mở khi đội có healer; hai điều kiện đội
  trên một hiệu ứng nhân với nhau. Buff cả đội có điều kiện đội vẫn bị khử trùng
  lặp theo bộ chỉ khi không có cổng.
- Uptime vẫn là **tỉ lệ**, chưa phải mô phỏng khung giờ: không biết thứ tự E–Q–đánh
  thường, stack giảm dần (The Daybreak Chronicles, Alley Hunter) lấy mức giữ đều.
- `character-kits.json.buffs[].uptime` (Bennett, Kujou Sara, Faruzan…) vẫn gán
  tay — timeline chưa đọc buff từ kit.

## 11. Pha 6 — kết quả

### 11.1. Nguồn HP: wiki, đối chiếu file game

Kế hoạch ghi "HP quái từ Yatta". Yatta có HP gốc và đường cong theo cấp của từng
quái (`monster/{id}`, `static/monsterCurve`), nhưng thiếu hai thứ La Hoàn cần:
**biến thể** — Battle-Hardened Chimeric Volkodlak Archer của tầng 12 là Voywolf
Hunter với hệ số HP 25.652, gấp 7 lần bản thường 3.6, và Yatta không có entry
Battle-Hardened nào — và **lịch tầng hiện tại** (dữ liệu `tower` của Yatta dừng
ở 2025). `scripts/sync-abyss-monster-hp.py` vì vậy đọc wiki:

- **Số lượng**: template `Domain Enemies` của trang chu kỳ (`Tên*số`, `//` tách
  đợt con). Trường `count` trong file chu kỳ là văn xuôi ("1 rồi 1 (≈8 tổng cả
  đợt)", "2 (biến thể)" cho một Construction Specialist Mek mà wiki ghi 1) nên
  không đọc.
- **HP**: template `Enemy Stats` trên trang quái, đúng biến thể; `HP = hp_ratio ×
  Module:Enemy Stats/HP[type][cấp]`. Bảng đó là đường cong HP của game × 13.584 —
  script tính lại HP của 27 quái có `gameId` từ file game (Yatta), lệch < 1% cả 27.
- **Hệ số tầng**: mục "Enemy HP" trang Spiral Abyss (tầng 8–11 ×2, tầng 12 ×2.5),
  khớp mã ẩn `LevelEntity_Monster_HpUp_Lv3/Lv5` trong dữ liệu `tower` của Yatta.

Từ chối (không đoán): tên không khớp, biến thể không rõ, trang chu kỳ nhắc HP
ngoài danh sách quái, HP lệch file game > 1%, và số lượng mà wiki ghi chú
"unsure" — **tầng 11** bị từ chối vì lẽ này, và giữ giả định HP bằng nhau
(`diagnostics.fightHPUnknown`).

### 11.2. Mô hình

- **Điểm phương án** = sát thương mỗi giây dọn hết HP cả hai nửa trong đúng tổng
  thời gian hai đội cần: `(H₁ + H₂) / (H₁/s₁ + H₂/s₂)`. Lớn nhất đúng khi
  `t₁ + t₂` nhỏ nhất; không có HP thì về lại trung bình điều hoà. Vẫn tăng theo cả
  hai điểm nên chặn nhánh của phép ghép đội giữ nguyên (test so với vét cạn).
- Tầng 12 mùa này: **nửa trước 14.4M HP, nửa sau 8.7M** — giả định cũ lệch hơn
  một nửa. 3.8M của nửa trước là 8 Ruin Scout.
- Kháng và cấp quái của một trận giờ **có trọng số theo HP** (thời gian dồn vào
  chỗ nhiều HP): tầng 12 cả tầng Cryo 26% → 33%, Electro 30% → 37%, cấp 98 → 97.
  Thiếu HP ở bất kỳ quái nào thì mọi quái nặng như nhau như trước.
- UI hiện **thời gian dọn** ("≈ 15:07 để dọn") cạnh điểm, cho phương án và từng
  nửa; chú thích nói rõ đây là thước so sánh (sát thương mô hình, một mục tiêu),
  không phải đồng hồ trong game.

### 11.3. Đo lại

Benchmark gcsim chấm đội trên tầng trung tính nên không đổi. Trên tầng 12 với
roster ví dụ, xếp lại cùng 5 phương án đầu bằng trung bình điều hoà thì #3 (Yelan
+ Xiangling | Raiden + Xingqiu) tụt xuống #5: nửa sau của nó mạnh (27.9k) nhưng
nửa sau chỉ có 8.7M HP, còn nửa trước 14.4M mới là chỗ tốn thời gian. Phương án
#1 cần ≈ 648s + 259s theo mô hình. Golden đổi 148
dòng (kháng/cấp tầng và điểm đội).

### 11.4. Còn lại

- **Một mục tiêu**: 8 Ruin Scout được tính như 8 lần một con; đội đánh lan không
  được lợi. Đây là giới hạn lớn nhất của thời gian dọn hiện tại.
- Khiên nguyên tố, pha bất tử, quái hồi thêm theo thời gian chưa vào thời gian.
- Kháng vẫn trung bình theo giá trị (có trọng số); chính xác hơn là trung bình
  hệ số kháng `ΣH / Σ(Hᵢ/mᵢ)` — cần đổi cấu trúc `resistances` sang hệ số.
- Tầng 11 chờ wiki chốt số lượng; chạy lại script là đủ.

## 12. Pha 7 — kết quả

### 12.1. Benchmark trước khi làm: đúng nhóm mục 8.4 đã ghi

Columbina −0.316, Ineffa −0.285, Aino −0.282, và nhóm `T:Lunar-Charged` −0.275
(3,645 đội) — khớp mục 8.4: "Lunar gián tiếp chưa có". Soát lại thì không chỉ
thiếu — phần "trực tiếp" đã có từ Pha 4 cũng sai theo hai cách độc lập.

### 12.2. Hai lỗi trong phần "trực tiếp", trước khi đụng tới phần "gián tiếp"

- **Chọn nhầm dòng talent.** Kỹ năng của Columbina liệt kê ba dòng "Gravity
  Interference: Lunar-Charged/Lunar-Bloom/Lunar-Crystallize DMG" — chữ game
  ghi cả ba vì phản ứng nào nổ ra tuỳ đội. `AbyssTalentReader` coi ba dòng đó
  là "biến thể của nhau" (giống "Low HP Skill DMG" so với "Skill DMG") và giữ
  dòng có số phần trăm thô lớn nhất — luôn là Lunar-Crystallize, bất kể đội có
  Thổ hay không. Một đội Lunar-Charged thật (Thuỷ + Điện) vì vậy bị tính sát
  thương của một phản ứng đội đó không bao giờ kích hoạt được. Sandrone,
  Odette (Stellar-Conduct/Stellar Swirl) cùng lỗi.
- **Không cổng theo đội.** Dòng talent *là* sát thương Lunar/Stellar (Flins,
  Qiqi) tính sát thương vô điều kiện, không kiểm tra đội có thật sự kích hoạt
  được phản ứng đó không (`AbyssTeamContext.enabledReactions`) — Flins vẫn ra
  sát thương Lunar-Charged trên một đội không có Thuỷ.

Sửa: dòng nào gọi tên một phản ứng thì giữ tên đó lại trong khoá gộp (không
còn bị coi là biến thể của dòng gọi tên phản ứng khác), nên cả ba dòng của
Columbina sống sót riêng lẻ; mỗi dòng có `reaction` được chấm 0 khi
`enabledReactions` của đội không chứa đúng phản ứng đó.

### 12.3. Phần "gián tiếp": có công thức trong `damage-formula.json`, chưa từng đọc

`damage-formula.json.lunarStellar.indirect` (ghi từ Pha 4) liệt kê công thức
riêng cho Lunar-Charged, Lunar-Crystallize và Stellar Swirl — phản ứng những
người *không* mang kit Lunar/Stellar cũng góp phần kích hoạt, tính theo **từng
người góp** (Elemental Mastery, CRIT, kháng theo nguyên tố của chính họ) chứ
không phải theo Elemental Mastery cao nhất đội như một phản ứng biến đổi
thường: `DMG cuối = Cao nhất×0.6 + Nhì×0.3 + Ba×0.05 + Tư×0.05` xếp theo sát
thương cá nhân giảm dần, đội ít hơn 4 người góp thì bỏ phần thiếu, giữ nguyên
hệ số phần còn lại. Trường này tồn tại từ Pha 4 nhưng không có code nào đọc nó
— `AbyssTeamContext.transformativeReactions` gộp Lunar-Charged/Lunar-Crystallize
chung với các phản ứng biến đổi cổ điển (một hit, không CRIT, chỉ Elemental
Mastery cao nhất đội), sai công thức.

Cùng lúc, `lunarStellar.indirect.appliesTo` không có Lunar-Bloom lẫn
Stellar-Conduct — hai phản ứng đó **chỉ trực tiếp**, một đội chỉ có được từ
nhân vật có kit gây đúng sát thương đó, không bao giờ từ áp nguyên tố trần.
Nhưng `transformativeReactions` cũ lại thêm cả hai vào mỗi khi đội đủ nguyên
tố + Moonsign/Tinh Vực Rực Rỡ — một đội Thảo+Thuỷ+Moonsign được cộng khống sát
thương Lunar-Bloom dù không ai mang kit gây nó.

Sửa: xoá Lunar-Charged/Lunar-Bloom/Lunar-Crystallize/Stellar-Conduct khỏi
`transformativeReactions` (Stellar Swirl giữ nguyên — đã đúng chỗ, chưa đổi
công thức); thêm `AbyssScorer.indirectLunarPricing`/`indirectLunarStellarDamage`
tính riêng Lunar-Charged và Lunar-Crystallize theo đúng công thức xếp hạng
0.6/0.3/0.05/0.05, cộng thẳng vào sát thương đội bên cạnh phần trực tiếp.
Stellar Swirl chưa được viết lại theo công thức gián tiếp riêng (hệ số của nó
tăng dần theo số đòn, phức tạp hơn và không có tín hiệu benchmark để đối
chiếu) — vẫn dùng xấp xỉ cũ.

### 12.4. Đo lại

**Spearman 0.394 → 0.416** (3,645 đội). Ineffa và Aino ra khỏi danh sách đánh
giá thấp hẳn (từ −0.285 và −0.282); Columbina −0.316 → −0.169; nhóm
`T:Lunar-Charged` không còn đủ lệch để lên báo cáo. Golden đổi hồ sơ sát thương
của Columbina, Sandrone, Odette, Qiqi (số dòng, hệ số, phản ứng đúng dòng) và
điểm/vũ khí chọn cho Columbina.

### 12.5. Còn lại

- **Stellar Swirl và Stellar-Conduct** chưa theo cùng chuẩn: Stellar-Conduct đã
  chuyển đúng "chỉ trực tiếp", nhưng Stellar Swirl vẫn tính theo mô hình phản
  ứng biến đổi cổ điển (một hit, Elemental Mastery cao nhất đội) thay vì công
  thức gián tiếp xếp hạng — không có đội Tinh Vực Rực Rỡ nào trong benchmark
  để đo, nên chưa đủ căn cứ viết công thức đúng và tin số ra.
- **Loại trừ lẫn nhau chưa xử lý cho Sandrone/Odette.** Kỹ năng của Sandrone
  liệt kê "Prism Shot DMG" (không tên phản ứng) cạnh "…Stellar-Conduct DMG" và
  "…Stellar Swirl DMG" — cùng một đòn, ba kết quả loại trừ nhau tuỳ đội. Bản
  sửa Pha 7 khiến dòng không tên phản ứng luôn cộng thêm bất kể đội có kích
  hoạt Stellar hay không, cộng dồn lên hai dòng có tên khi đội đủ điều kiện —
  chỉ đúng khi đội không kích hoạt được Stellar. Không xuất hiện trong benchmark
  (không đội Sandrone/Odette nào lệch đáng kể) nên chưa sửa.
- Người được ghi công kích hoạt phản ứng trong `reactionTriggerIndex` (UI) vẫn
  là người Elemental Mastery cao nhất đội — đúng cho phần biến đổi cổ điển,
  chỉ là xấp xỉ cho phần Lunar/Stellar gián tiếp giờ chia cho nhiều người.
