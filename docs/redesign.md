# Thiết kế lại mô hình damage — kế hoạch và tiến độ

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
== engine hôm qua*, chưa bao giờ chứng minh *engine == game*. Dự định ban đầu
là dựng benchmark ~20 đội theo số liệu cộng đồng (gcsim/gõ tay Akasha) — đã
thử và **không khả thi ngay**: `akasha.cv` chặn bot (403, Cloudflare),
không có API subdomain công khai. Không tạo số liệu benchmark bằng cách bịa;
xem mục 4 (Pha 0) về hướng thay thế đã chọn.

## 3. Lộ trình

| Pha | Việc | Xoá được hằng số nào | Trạng thái |
|---|---|---|---|
| **0** | Nhập kháng quái thật từ Yatta; đặt nền benchmark | `enemyOwnElementResistance` làm fallback thay vì luật chính | **Xong — xem mục 4** |
| 1 | Talent → `params` cấu trúc từ Yatta, thay 26 regex trong `AbyssTextParser` | — (gỡ nguồn lỗi lớn nhất) | Chưa bắt đầu |
| 2 | `character-kits.json` cho ~30 nhân vật hay dùng nhất; nhân vật chưa có kit rơi về mô hình cũ | — | Chưa bắt đầu |
| 3 | Dựng rotation + năng lượng | `offFieldUptime`, hack ER | Chưa bắt đầu |
| 4 | Gauge/ICD/phản ứng theo timeline | `amplifyingUptime`, `transformativeReactionsPerRotation` | Chưa bắt đầu |
| 5 | Timeline buff + stack | `conditionalUptime`, `assumedStacks`, phần lớn `setEffectApprox` | Chưa bắt đầu |
| 6 | Điểm = thời gian dọn — cần nhập HP quái từ Yatta (script Pha 0 cố tình **chưa** lấy HP: chưa có gì đọc nó, và một key không ai hỏi là đúng loại lỗ hổng im lặng đã dọn ở `physical_dmg`) | trung bình điều hoà giả định HP bằng nhau | Chưa bắt đầu |

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

## 5. Chưa xác minh, cần làm trước Pha 1

- Yatta có ghi **hạt năng lượng/kỹ năng** không (particle count mỗi hit) —
  cộng đồng có bảng riêng nếu Yatta không có; Pha 3 (năng lượng) cần số này.
- Format string `params` của Yatta (`"Blood Blossom DMG|{param3:P}"`) phân
  loại được bao nhiêu % tự động (P=percent, F2P...) — bao nhiêu % còn lại
  cần người xếp loại bằng tay khi viết `character-kits.json`.
