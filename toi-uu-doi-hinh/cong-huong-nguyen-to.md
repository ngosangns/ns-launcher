# Buff Đội (Team Bonus): Cộng Hưởng Nguyên Tố, Nguyệt Triệu, Hexerei, Nightsoul Burst

> Ngày lấy dữ liệu: 2026-09-08. Nguồn: trang "Team Bonus" (redirect từ
> "Elemental Resonance") trên Genshin Impact Wiki (Fandom), lấy nguyên văn
> qua MediaWiki API (`action=parse&prop=wikitext`); danh sách nhân vật
> Nguyệt Triệu/Hexerei lấy qua `action=query&list=categorymembers`
> (`Category:Moonsign Characters`, `Category:Hexerei Characters`). Đây là
> các buff **tự động kích hoạt theo thành phần đội hình** (không cần đeo
> thánh di vật/vũ khí gì đặc biệt) nên **luôn luôn đáng cân nhắc** khi ghép
> đội hình Trầm Thủy — dùng cùng
> [`Sources/NSLauncherApp/Resources/Abyss/team-bonus.json`](../Sources/NSLauncherApp/Resources/Abyss/team-bonus.json) để
> tính vào tổng buff của đội trước khi áp dụng
> [`cong-thuc-sat-thuong.md`](cong-thuc-sat-thuong.md).

## 1. Cộng Hưởng Nguyên Tố (Elemental Resonance)

Kích hoạt khi có **từ 2 nhân vật cùng nguyên tố trở lên** trong 4 vị trí đầu
đội hình (có nhiều hơn 2 cũng không tăng thêm hiệu lực). Áp dụng cả trong
Co-Op. Trừ Protective Canopy, mỗi cộng hưởng chỉ cần đúng 1 nguyên tố lặp
lại — một đội có thể kích hoạt **tối đa 2 cộng hưởng cùng lúc** (vd. đội
2 Pyro + 2 Hydro vẫn ăn cả Fervent Flames lẫn Soothing Water).

| Tên | Nguyên tố (số lượng) | Hiệu ứng |
|---|---|---|
| Fervent Flames | Pyro ×2 | Giảm 40% thời gian dính hiệu ứng Cryo. Tăng ATK +25%. |
| Soothing Water | Hydro ×2 | Giảm 40% thời gian dính hiệu ứng Pyro. Tăng HP tối đa +25%. |
| High Voltage | Electro ×2 | Giảm 40% thời gian dính hiệu ứng Hydro. Superconduct, Stellar-Conduct, Overloaded, Electro-Charged, Lunar-Charged, Quicken, Aggravate, hoặc Hyperbloom có 100% cơ hội tạo 1 Hạt Nguyên Tố Electro (hồi chuỗi 5s). |
| Shattering Ice | Cryo ×2 | Giảm 40% thời gian dính hiệu ứng Electro. Tăng CRIT Rate +15% khi đánh địch đang Đóng Băng (Frozen) hoặc dính Cryo. |
| Impetuous Winds | Anemo ×2 | Giảm 15% tiêu hao Thể Lực. Tăng Tốc Độ Di Chuyển +10%. Giảm hồi chiêu Kỹ Năng 5%. |
| Enduring Rock | Geo ×2 | Tăng 15% độ bền khiên. Ngoài ra khi nhân vật đang có khiên bảo vệ hoặc ở gần Moondrift (do phản ứng Lunar-Crystallize tạo ra): tăng 15% sát thương gây ra; gây sát thương lên địch giảm 20% kháng Geo của địch trong 15s. |
| Sprawling Greenery | Dendro ×2 | Tăng Tinh Thông Nguyên Tố (EM) +50. Sau khi kích hoạt Thiêu Đốt (Burning), Nảy Mầm Nhanh (Quicken), Nảy Mầm (Bloom), hoặc Lunar-Bloom: đồng đội gần đó +30 EM trong 6s. Sau khi kích hoạt Cảm Điện Kích Phát (Aggravate), Lan Toả (Spread), Kích Nổ Siêu Cấp (Hyperbloom), hoặc Sinh Trưởng Kịch Phát (Burgeon): đồng đội gần đó +20 EM trong 6s. Các hiệu ứng này tính thời lượng độc lập, có thể cộng dồn nếu kích hoạt nhiều loại phản ứng. |
| Protective Canopy | Đủ 4 nguyên tố khác nhau (không lặp) | Tăng Kháng Nguyên Tố (mọi hệ) +15%, Kháng Vật Lý +15%. |

**Ứng dụng chọn đội Trầm Thủy:** ưu tiên xếp đội theo cặp nguyên tố (2+2)
nếu không phá vỡ combo phản ứng chính, để ăn trọn 1-2 Cộng Hưởng miễn phí;
Protective Canopy (4 nguyên tố khác nhau, +15%/+15% kháng) là lựa chọn an
toàn cho đội hình sinh tồn khi không có combo phản ứng rõ ràng.

## 2. Nguyệt Triệu (Moonsign)

Cơ chế riêng của **nhân vật Nguyệt Triệu (Moonsign Characters)** — hiện tại
gồm **10 nhân vật, toàn bộ là người Nod-Krai**: Aino, Columbina, Flins,
Illuga, Ineffa, Jahoda, Lauma, Linnea, Nefer, Zibai (xem chi tiết từng
người trong `Sources/NSLauncherApp/Resources/Abyss/characters/mondstadt.json` /
`liyue.json`/`inazuma-fontaine.json` tuỳ quốc gia trong game — file
`nhan-vat/mondstadt.md` liệt kê nhóm Nod-Krai).

> **Lưu ý phân biệt:** Nguyệt Triệu **không giống** danh sách nhân vật có
> "Reaction Base DMG Bonus" cho Lunar/Stellar Glimmer trong
> `cong-thuc-sat-thuong.md` mục 5.3 — danh sách đó gồm cả một số nhân vật
> Nguyệt Triệu (Columbina, Lauma, Nefer, Flins, Ineffa, Zibai, Linnea) **và**
> nhóm Stellar Jubilee (Sandrone, Odette, Lữ Hành Băng) vốn KHÔNG phải nhân
> vật Nguyệt Triệu.

Đạt cấp độ Nguyệt Triệu (Moonsign Level) tương ứng số nhân vật Nguyệt Triệu
trong đội:

| Cấp | Số nhân vật Nguyệt Triệu | Hiệu ứng |
|---|---|---|
| Nascent Gleam | 1 | Toàn đội nhận hiệu ứng "Moonsign: Nascent Gleam" (tăng cường cụ thể theo từng nhân vật Nguyệt Triệu — xem cung mệnh/passive riêng của từng người). |
| Ascendant Gleam | 2+ | Toàn đội nhận thêm "Moonsign: Ascendant Gleam" (tăng cường Kỹ Năng/Bùng Nổ nhất định của nhân vật Nguyệt Triệu; hiệu ứng Nascent Gleam vẫn giữ). **Cộng thêm:** trong 20s sau khi một nhân vật KHÔNG phải Nguyệt Triệu thi triển Kỹ Năng/Bùng Nổ nguyên tố, tăng sát thương phản ứng Mặt Trăng (Lunar Reaction) của đồng đội gần đó theo chỉ số của chính nhân vật đó, tối đa +36% (không cộng dồn nhiều lần), cụ thể theo nguyên tố: Pyro/Electro/Cryo +0.9%/100 ATK; Hydro +0.6%/1000 HP tối đa; Geo +1%/100 DEF; Anemo/Dendro +2.25%/100 EM. |

**Ngưỡng chỉ số đạt buff tối đa (+36%) ở Ascendant Gleam:** Pyro/Electro/Cryo
4000 ATK · Hydro 60,000 HP tối đa · Geo 3600 DEF · Anemo/Dendro 1600 EM.

**Ứng dụng:** đội có ≥2 nhân vật Nguyệt Triệu (Ascendant Gleam) đáng cân
nhắc mạnh cho các tầng có Ley Line Disorder/Uyên Nguyệt Chúc Phúc liên quan
Lunar-Charged/Lunar-Bloom/Lunar-Crystallize (xem `quai-vat-la-hoan/` và
`Sources/NSLauncherApp/Resources/Abyss/abyss-monsters/`).

## 3. Hexerei

Cơ chế riêng của **nhân vật Hexerei (Hexenzirkel)** — hiện tại gồm **12
nhân vật**: Albedo, Durin, Fischl, Klee, Lohen, Mona, Nicole, Prune, Razor,
Sucrose, Varka, Venti. Yêu cầu mỗi nhân vật đã hoàn thành nhiệm vụ riêng
"Witch's Homework" để trở thành nhân vật Hexerei.

| Tên | Số nhân vật Hexerei | Hiệu ứng |
|---|---|---|
| Hexerei: Secret Rite | 2+ | Các nhân vật Hexerei trong đội được tăng cường thêm: kích hoạt "Witch's Eve Rite Passive" (passive ẩn riêng), thêm hiệu ứng Kỹ Năng/Cung Mệnh bổ sung tuỳ nhân vật. |

**Ứng dụng:** mang ≥2 trong 12 nhân vật trên cùng lúc để kích hoạt — ghi
chú chi tiết Witch's Eve Rite Passive của từng người nằm trong phần passive
ở `nhan-vat/mondstadt.md` (đã ghi chú riêng cho Albedo, Klee, Mona, Venti,
Fischl, Razor, Sucrose, Durin, Varka, Prune, Lohen, Nicole).

## 4. Nightsoul Burst (buff theo quốc gia trong game — Natlan)

Không hiển thị trong màn hình Buff Đội (khác Cộng Hưởng/Nguyệt Triệu/
Hexerei) nhưng vẫn là buff tự động theo thành phần đội: khi đội có **≥1
nhân vật người Natlan**, Nightsoul Burst kích hoạt định kỳ, chu kỳ rút ngắn
theo số nhân vật Natlan trong đội:

| Số nhân vật Natlan trong đội | Chu kỳ Nightsoul Burst |
|---|---|
| 1 | 18s |
| 2 | 12s |
| 3+ | 9s |

**Lưu ý:** một số nhân vật gốc gác Natlan theo cốt truyện nhưng **quốc gia
trong game không phải Natlan** (vd. Bennett, Lữ Hành Pyro) **không** được
tính vào số lượng này dù có thể tự vào trạng thái Nightsoul's Blessing.
Danh sách đầy đủ nhân vật Natlan (quốc gia trong game): xem
`Sources/NSLauncherApp/Resources/Abyss/characters/sumeru-natlan.json` (field `nationInGame` =
`"Natlan"`).
