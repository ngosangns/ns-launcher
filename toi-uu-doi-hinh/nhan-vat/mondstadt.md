<!--
Ngày lấy dữ liệu: 2026-09-08 (phiên bản game hiện hành: 7.0 "Everwinter Without Mercy", phát hành 12/08/2026).
Nguồn: api.ambr.top / gi.yatta.moe không truy cập được từ môi trường lấy dữ liệu (DNS/WebFetch bị chặn).
Toàn bộ số liệu trong file lấy trực tiếp từ wikitext gốc (bảng {{Talent Scaling}}, {{Character Ascensions and Stats}}) của
Genshin Impact Wiki (Fandom) qua MediaWiki API (action=query/parse, prop=revisions|wikitext) — dữ liệu này được cộng đồng
trích xuất thẳng từ file game (tương đương độ chính xác với Ambr/Yatta). Trang wiki tổng quát của mỗi nhân vật cũng được
dùng để lấy mô tả kỹ năng, cung mệnh, thông tin chung và ngày ra mắt.
Quy ước số liệu kỹ năng: "cấp 1 → cấp 10" (cấp 13 với các đòn có thể tăng thêm qua cung mệnh C3/C5). Chỉ số cơ bản lấy ở
cấp 1 (đột phá 0) và cấp 90 (đột phá 6, hoàn thiện) theo đúng quy ước README. Từ bản 6.0 "Luna I" trở đi, game cho phép
đột phá thêm tới cấp 100 bằng Sao Băng Vô Chủ (Masterless Stella Fortuna, cần nhân vật 5★ trùng đã max cung mệnh) — đây là
phần thưởng phụ hiếm gặp nên các bảng chỉ số dưới đây KHÔNG lấy mốc 100 làm chuẩn, chỉ dùng cấp 90 theo quy ước chung.
Một số nhân vật Mondstadt kinh điển (Albedo, Klee, Mona, Venti, Fischl, Razor, Sucrose...) đã được cập nhật thêm một
"Witch's Eve Rite Passive" mới (khả năng trở thành nhân vật hệ Hexerei, cộng hưởng với các nhân vật phe Hexenzirkel như
Durin/Varka/Prune/Lohen/Nicole) — các passive này đã được cập nhật đầy đủ bên dưới.
-->

# Mondstadt + Nod-Krai + Nhà Lữ Hành

Danh sách đầy đủ 24 nhân vật Mondstadt (bao gồm các nhân vật hệ Hexerei mới xuất hiện từ cốt truyện Hexenzirkel:
Durin, Varka, Prune, Lohen, Nicole), 9 nhân vật Nod-Krai, và Nhà Lữ Hành với cả 7 nguyên tố đã cộng hưởng
(Anemo/Geo/Electro/Dendro/Hydro/Pyro/Cryo).

**Ghi chú phân loại quốc gia:** một số nhân vật có "quốc gia trong game" (region hiển thị trong hồ sơ, quyết định
thưởng thám hiểm/set độ hiếm) khác với quê quán trong cốt truyện — file này phân loại theo **quốc gia trong game**
đúng theo cách chia của chính tựa game (vd. Durin/Varka/Prune/Lohen/Nicole → Mondstadt dù gốc gác Simulanka/Nod-Krai;
Nefer/Columbina → Nod-Krai dù gốc Sumeru/Snezhnaya). Nicole không có Region chính thức trong game (thuộc phe
Hexenzirkel độc lập) — xếp tạm vào Mondstadt do gắn với cốt truyện/nhóm nhân vật Mondstadt (Alice, Klee).

Nhân vật KHÔNG đưa vào file: Alice, Istaroth (NPC, chưa chơi được), Wonderland Manekin/Manekina (nhân vật chế độ
Miliastra Wonderland riêng biệt, không dùng trong Trầm Thủy), Zibai (quốc gia trong game = Liyue, xem `liyue.md`),
Sandrone/Odette/Alyosha (quốc gia trong game = Snezhnaya, xem `liyue.md`).

## Mục lục
- [Nhà Lữ Hành (Traveler)](#nhà-lữ-hành-traveler) — mọi nguyên tố
- Mondstadt 5★: [Albedo](#albedo) · [Diluc](#diluc) · [Jean](#jean) · [Klee](#klee) · [Mona](#mona) · [Venti](#venti) · [Eula](#eula) · [Durin](#durin) · [Varka](#varka) · [Lohen](#lohen) · [Nicole](#nicole)
- Mondstadt 4★: [Amber](#amber) · [Barbara](#barbara) · [Bennett](#bennett) · [Diona](#diona) · [Fischl](#fischl) · [Kaeya](#kaeya) · [Lisa](#lisa) · [Mika](#mika) · [Noelle](#noelle) · [Razor](#razor) · [Rosaria](#rosaria) · [Sucrose](#sucrose) · [Prune](#prune)
- Nod-Krai 5★: [Ineffa](#ineffa) · [Flins](#flins) · [Columbina](#columbina) · [Linnea](#linnea) · [Nefer](#nefer)
- Nod-Krai 4★: [Aino](#aino) · [Lauma](#lauma) · [Illuga](#illuga) · [Jahoda](#jahoda)

---

## Nhà Lữ Hành (Traveler)

**Nguyên tố:** Adaptive (đổi được Anemo/Geo/Electro/Dendro/Hydro/Pyro/Cryo) | **Vũ khí:** Kiếm | **Độ hiếm:** 5★ | **Quốc gia:** — (nhân vật chính) | **Ngày ra mắt:** 28/09/2020 (Anemo/Geo); Electro 21/07/2021; Dendro 24/08/2022; Hydro 16/08/2023; Pyro 01/01/2025; Cryo 12/08/2026 (bản 7.0)

Nhà Lữ Hành dùng chung một bộ chỉ số cơ bản và một bộ Đòn thường/Đòn nặng/Nhảy cho mọi nguyên tố; chỉ Kỹ năng nguyên tố,
Bùng nổ nguyên tố, các passive và cung mệnh là khác nhau theo từng nguyên tố. Ngoài ra, sau khi hoàn thành nhiệm vụ
"Welkin Moon's Homecoming" (do Columbina gỡ bỏ giới hạn phong ấn), Nhà Lữ Hành có thêm 1 "Additional Talent" cho mỗi
nguyên tố (buff cộng dồn theo số nguyên tố đã cộng hưởng) và được cộng vĩnh viễn 1 chỉ số phụ mỗi khi cộng hưởng lần
đầu với 1 nguyên tố tại Tượng Thần: Anemo +10% Tỉ lệ bạo kích, Geo +20% DEF, Electro +20% Tinh Thông Nguyên Tố Hồi,
Dendro +60 Tinh Thông Nguyên Tố, Hydro +20% HP, Pyro +20% ATK, Cryo +20% Tỉ lệ st bạo kích — các chỉ số này **cộng dồn**
kể cả khi đang đứng nguyên tố khác.

### Chỉ số cơ bản (dùng chung mọi nguyên tố)

| Cấp | HP | ATK | DEF | Chỉ số đột phá (ATK phụ) |
|---|---|---|---|---|
| 1 (đột phá 0) | 911.79 | 17.81 | 57.23 | — |
| 90 (đột phá 6) | 10,874.91 | 212.40 | 682.52 | 24.00% |

### Đòn thường — Foreign Ironwind / Foreign Blaze / Foreign Stream / ... (dùng chung mọi nguyên tố)

| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| Đòn 1 | 44.5% ATK | 87.9% ATK |
| Đòn 2 | 43.4% ATK | 85.9% ATK |
| Đòn 3 | 53.0% ATK | 105% ATK |
| Đòn 4 | 58.3% ATK | 115% ATK |
| Đòn 5 | 70.8% ATK | 140% ATK |
| Đòn nặng | Aether 55.9%+60.7% ATK / Lumine 55.9%+72.2% ATK | Aether 118%+128% ATK / Lumine 118%+153% ATK |
| Nhảy (rơi/thấp/cao) | 63.9% / 128% / 160% ATK | 126% / 252% / 315% ATK |

### Anemo (từ 28/09/2020)
- **Kỹ năng — Palm Vortex** (Foreign Windwrath): tạo xoáy khí liên tục gây sát thương Anemo trước mặt, có thể giữ để
  tăng dần AoE/DMG; hút nguyên tố lân cận (Elemental Absorption 1 lần/lượt).
- **Bùng nổ — Gust Surge**: triệu hồi lốc xoáy di chuyển về phía trước, hút và gây sát thương Anemo liên tục; cũng hút
  nguyên tố lân cận. Năng lượng 40, hồi chiêu 20s (ước tính theo mẫu chung Traveler).
- **Passive A1 Slitting Wind**: đòn cuối tổ hợp đánh thường tạo lưỡi gió gây 60% ATK sát thương Anemo diện rộng.
- **Passive A4 Second Wind**: hạ gục bằng Palm Vortex hồi 2% HP trong 5s (hồi 1 lần/5s).
- **Additional Talent — Foreign Windwrath**: nhận buff theo số nguyên tố đã cộng hưởng; khi đồng đội gây sát thương
  Pyro/Hydro/Cryo/Electro trúng địch, nhận 1 stack Blade of the Dawn Breeze (mỗi nguyên tố 1 stack); đạt ≥2 stack thì
  Đòn nặng tiếp theo biến thành **Whirlwind** (tăng DMG Anemo +60% ATK mỗi đòn, kèm 1 đòn gió nguyên tố tương ứng
  +50% ATK cho mỗi loại nguyên tố tiêu thụ), 15s/lần.
- **Cung mệnh:**
  1. Raging Vortex — Palm Vortex hút địch/vật thể trong bán kính 5m.
  2. Uprising Whirlwind — Tăng Nguyên Tố Hồi 16%.
  3. Sweeping Gust — Tăng cấp Gust Surge +3 (tối đa cấp 15).
  4. Cherishing Breezes — Giảm 10% sát thương nhận khi thi triển Palm Vortex.
  5. Vortex Stellaris — Tăng cấp Palm Vortex +3 (tối đa cấp 15).
  6. Intertwined Winds — Mục tiêu trúng Gust Surge giảm 20% kháng Anemo; nếu có hút nguyên tố, giảm thêm 20% kháng
     nguyên tố đó.

### Geo (từ 28/09/2020)
- **Kỹ năng — Starfell Sword** (Foreign Adamantine): tạo cột đá gây sát thương Geo, có thể giữ để tạo cột lớn hơn.
- **Bùng nổ — Wake of Earth**: tạo tường đá bao quanh gây sát thương Geo diện rộng, tường đá là chướng ngại Geo.
- **Cung mệnh:** C1 Stone's Persistence (giảm hồi chiêu Kỹ năng), C2 Ashen Nightstar (kích hoạt cột đá to hơn khi
  đứng gần), C3 tăng cấp Bùng nổ +3, C4 Rockfall (tường đá tồn tại lâu hơn/tự nổ khi hết hạn), C5 tăng cấp Kỹ năng +3,
  C6 The Earth Kingdom (đồng đội quanh tường đá tăng 30% Tỉ lệ bạo kích khi tấn công Geo — chi tiết đầy đủ tuỳ thuộc
  bản dịch chính thức trong game, số liệu tham khảo Fandom).

### Electro (từ 21/07/2021)
- **Kỹ năng — Lightning Blade** (Foreign Thundertrail): vung kiếm sấm sét gây sát thương Electro liên tục theo diện
  hình quạt trước mặt (giữ để duy trì).
- **Bùng nổ — Sinful Burial**: gọi sấm sét gây sát thương Electro diện rộng.
- **Cung mệnh:** C1 tăng ATK khi có Electro Sigil, C2 tăng Nguyên Tố Hồi, C3 tăng cấp Bùng nổ +3, C4 hồi năng lượng
  khi trúng Electro-Charged, C5 tăng cấp Kỹ năng +3, C6 tăng sát thương Electro-Charged/Overloaded gây ra bởi đội.

### Dendro (từ 24/08/2022)
- **Kỹ năng — Wreath of Verdance** (Foreign Verdalume): ném quả cầu Dendro gây sát thương AoE, để lại vùng hiệu ứng.
- **Bùng nổ — Nature's Wrath**: tạo trụ gỗ nổ liên tục gây sát thương Dendro diện rộng.
- **Cung mệnh:** C1 tăng Tinh Thông Nguyên Tố khi ở gần phản ứng Dendro, C2 giảm hồi chiêu Kỹ năng, C3 tăng cấp
  Bùng nổ +3, C4 hồi năng lượng khi kích hoạt phản ứng Dendro, C5 tăng cấp Kỹ năng +3, C6 tăng sát thương phản ứng
  liên quan Dendro của đội.

### Hydro (từ 16/08/2023)
- **Kỹ năng — Aquacrest Saber**: Nhấn bắn Torrent Surge gây sát thương Hydro; Giữ vào chế độ ngắm bắn liên tục
  Dewdrop (Suffusion: khi HP >50%, sát thương Dewdrop tăng theo Max HP nhưng tự trừ máu theo giây), kết thúc bắn
  Torrent Surge. Có Arkhe Pneuma: định kỳ bắn thêm Spiritbreath Thorn xuyên địch.
  - Torrent Surge: **189.28% ATK** (cấp 1) → **340.7% ATK** (cấp 10), hồi chiêu 10s.
  - Dewdrop/Spiritbreath Thorn: **32.8%** (cấp 1) → **59.04%** (cấp 10) (ATK+Max HP).
- **Bùng nổ — Rising Waters**: bong bóng nước bay chậm gây sát thương Hydro liên tục (8 lượt C0-C1 / 14 lượt C2+).
  **101.87%** (cấp 1) → **183.36%** (cấp 10) ATK/lượt, thời lượng 4s, năng lượng 80, hồi chiêu 20s.
- **Passive A1 Spotless Waters**: Dewdrop trúng địch tạo Sourcewater Droplet, nhặt hồi 7% HP (tối đa 4 giọt/lần dùng
  Kỹ năng, 1 giọt/giây).
- **Passive A4 Clear Waters**: nếu có tiêu hao HP qua Suffusion, Torrent Surge cuối gây thêm sát thương = 45% tổng HP
  đã tiêu (tối đa 5,000).
- **Additional Talent — Foreign Aqualis**: đồng đội đổi HP ±5% cho 1 stack Blade of Many Waters (tối đa 3, 1 lần/4s);
  đủ 3 stack thì Đòn nặng tiếp theo hoá **Tidebound**: +150% ATK sát thương Hydu mỗi đòn, nếu HP ≥50% tiêu 10% Max HP
  để +100% ATK sát thương, nếu <50% thì hồi 25% Max HP khi trúng; 15s/lần.
- **Cung mệnh:**
  1. Swelling Lake — Nhặt Sourcewater Droplet hồi 2 năng lượng (cần mở A1 trước).
  2. Trickling Purity — Bong bóng Rising Waters giảm 30% tốc độ di chuyển, +3s thời lượng.
  3. Turbulent Ripples — Tăng cấp Aquacrest Saber +3.
  4. Pouring Descent — Aquacrest Saber tạo khiên hấp thụ 10% Max HP (hiệu quả x2.5 với Hydro), làm mới khi Dewdrop
     trúng địch mỗi 2s.
  5. Churning Whirlpool — Tăng cấp Rising Waters +3.
  6. Tides of Justice — Nhặt Sourcewater Droplet hồi HP cho đồng đội máu thấp nhất = 6% Max HP của họ.

### Pyro (từ 01/01/2025, cơ chế Nightsoul của Natlan)
- **Kỹ năng — Flowfire Blade**: Nhấn — tạo Blazing Threshold theo dõi nhân vật đang chiến đấu, tự tấn công định kỳ;
  Giữ — gây sát thương AoE tức thì + tạo Scorching Threshold (đánh phối hợp khi nhân vật đang chiến đấu ra đòn, 3s/lần).
  Cả hai đưa Nhà Lữ Hành vào trạng thái Nightsoul's Blessing (42 điểm Nightsoul, tối đa 12s).
  - Blazing Threshold: **28.08%** (cấp 1) → **50.54%** (cấp 10) ATK/đòn. Hold DMG: **98.8%** → **177.84%** ATK.
    Scorching Threshold: **81.44%** → **146.59%** ATK. Hồi chiêu 18s.
- **Bùng nổ — Plains Scorcher**: dồn lửa thành 1 dấu ấn gây sát thương AoE Pyro hệ Nightsoul.
  **427.2%** (cấp 1) → **768.96%** (cấp 10) ATK; trong 4s sau đó hồi 7 điểm Nightsoul/giây. Năng lượng 70, hồi chiêu 18s.
- **Passive A1 True Flame of Incineration**: khi có >20 điểm Nightsoul, AoE tấn công của Blazing/Scorching Threshold
  tăng lên.
- **Passive A4 Embers Unspent**: nhân vật trong Threshold kích hoạt phản ứng Pyro hồi 5 năng lượng (12s/lần); đồng đội
  kích hoạt Nightsoul Burst hồi 4 năng lượng.
- **Additional Talent — Foreign Starfire**: đồng đội kích hoạt Nightsoul Burst cho 1 stack Blade of the Sacred Flame
  (tối đa 2); đủ 2 stack thì Đòn nặng tiếp theo hoá **Inferno**: +200% ATK sát thương Pyro hệ Nightsoul, 15s/lần.
- **Cung mệnh** (bộ đầu kích hoạt free khi đánh Lord of Eroded Primal Fire, bộ "Unlocked With Blazing Flint Ore" dùng
  vĩnh viễn mọi nơi sau khi cống nạp Blazing Flint Ore):
  1. Starfire's Flowing Light — Nhân vật đang chiến đấu trong Threshold +6% DMG (thêm 9% nếu đang Nightsoul's Blessing).
  2. Ever-Lit Candle — Trong 12s sau Flowfire Blade, đồng đội kích hoạt phản ứng Pyro hồi 14 điểm Nightsoul cho
     Nhà Lữ Hành (tối đa 28/lần dùng Kỹ năng).
  3. Relayed Beacon — Tăng cấp Flowfire Blade +3.
  4. Ravaging Flame — Sau Bùng nổ, +20% DMG Pyro trong 9s.
  5. The Fire Inextinguishable — Tăng cấp Plains Scorcher +3.
  6. The Sacred Flame Imperishable — Trong Nightsoul's Blessing, Đòn thường/nặng chuyển hệ Pyro không ghi đè, +40%
     Tỉ lệ st bạo kích các đòn này.

### Cryo (từ 12/08/2026, bản 7.0, cơ chế Stellar Glimmer của Snezhnaya)
- **Kỹ năng — Ice Fog Piercer**: đâm về phía trước gây sát thương Cryo, tạo Frostpierce Star bay theo đội bắn tinh
  thể băng định kỳ (Radiance: Stellar-Conduct — bắn phối hợp theo Đòn thường/nặng/nhảy, 0.2s/lần); trúng địch cho
  1 stack Frostglow (tối đa 8).
  - Skill DMG: **91.68%** (cấp 1) → **165.02%** (cấp 10) ATK. Ice Crystal: **21.39%** → **38.51%** ATK. Hồi chiêu 15s.
- **Bùng nổ — Frostbound Javelin**: phóng nhiều mũi lao băng gây sát thương Cryo; tiêu hết Frostglow để tăng DMG (đủ
  8 stack thì tăng thêm số lượt đòn).
  - Ice Javelin: **55.13%/lượt** (cấp 1) → **99.24%/lượt** (cấp 10) ATK, 3 lượt cơ bản. Năng lượng 60, hồi chiêu 15s.
- **Passive A1 Ever-Keen Frost**: (Stellar-Conduct) khi có Frostpierce Star, Đòn thường/nặng/nhảy hoá Cryo không ghi
  đè, +80% ATK sát thương.
- **Passive A4 Lucent Ice**: +8% ATK thành Tinh Thông Nguyên Tố (tối đa 160).
- **Stellar Jubilee Passive — Illusory Frostmirror**: vào trạng thái Radiance: Stellar-Conduct trong Polestar Field
  hoặc Radiance: Stellar Swirl 8s sau khi đồng đội kích hoạt Stellar Swirl; biến Superconduct/Cryo Swirl thành
  Stellar-Conduct/Stellar Swirl, DMG cơ bản +0.35%/100 ATK (tối đa +7%).
- **Additional Talent — Foreign Permafrost**: đồng đội gây DMG Stellar-Conduct/Swirl cho 1 stack Icepoint (tối đa 3,
  2s/lần); đủ 3 stack thì Đòn nặng tiếp theo hoá **Freezing Ice**: +140% ATK sát thương Cryo, +2 Frostglow, 15s/lần.
- **Cung mệnh:**
  1. Somber Freeze — Gây sát thương Stellar Glimmer hồi 5 năng lượng (0.5s/lần).
  2. Frostfall Reverberation — Trúng tinh thể băng của Ice Fog Piercer: nhân vật đang chiến đấu +60 Tinh Thông Nguyên
     Tố 5s (tăng 120 nếu kích hoạt phản ứng Stellar Glimmer).
  3. Glacial Shard — Tăng cấp Frostbound Javelin +3.
  4. Enduring Ice — Frostpierce Star +25% thời lượng.
  5. Bittercold Fog — Tăng cấp Ice Fog Piercer +3.
  6. Brumal Grimfrost — Mỗi Frostglow tiêu khi dùng Bùng nổ tăng 5% sát thương Stellar Glimmer của đồng đội 15s
     (tối đa +40%).

**Vai trò đội hình Trầm Thủy:** Hydro/Pyro/Cryo Traveler là DPS on-field linh hoạt gắn với phản ứng nguyên tố mới
(Hydro cho đội cần chủ động Vaporize/Hồi máu, Pyro/Cryo cho đội Nightsoul/Stellar Glimmer); Anemo/Dendro/Electro
Traveler thường đóng vai trò hỗ trợ hút nguyên tố hoặc kích hoạt phản ứng lan toả (Anemo Traveler + Hyperbloom/EC là
combo phổ biến); Geo Traveler hỗ trợ khiên/kháng. Vì chia sẻ base ATK cao và có buff cộng dồn theo nguyên tố đã mở,
Nhà Lữ Hành luôn là lựa chọn "chân ái" chống chỉ định đội hình linh hoạt ở Trầm Thủy khi thiếu nhân vật phù hợp.

---

## Albedo

**Nguyên tố:** Geo | **Vũ khí:** Kiếm | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 23/12/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Geo DMG Bonus |
|---|---|---|---|---|
| 1 | 1,029.59 | 19.55 | 68.21 | — |
| 90 | 13,225.58 | 251.14 | 876.15 | 28.8% |

### Bộ kỹ năng

**Đòn thường — Favonius Bladework - Weiss:** tối đa 5 đòn liên hoàn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 36.74% | 78.5% |
| 2-Hit | 36.74% | 78.5% |
| 3-Hit | 47.45% | 101.39% |
| 4-Hit | 49.75% | 106.3% |
| 5-Hit | 62.07% | 132.63% |
| Đòn nặng (2 đòn) | 47.3%+60.2% | 101.06%+128.63% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 135.3% / 270.54% / 337.92% |

**Kỹ năng — Abiogenesis: Solar Isotoma** (hồi chiêu 4s): tạo Solar Isotoma gây sát thương Geo diện rộng khi xuất
hiện, sinh Transient Blossom (theo DEF) khi địch trong vùng chịu sát thương (2s/lần); đứng giữa Solar Isotoma được
nâng lên bệ đá. Có thể giữ nút để chọn vị trí.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 130.4% ATK | 234.72% ATK (cấp 14: 293.4%) |
| Transient Blossom DMG | 133.6% DEF | 240.48% DEF (cấp 14: 300.6%) |

**Bùng nổ — Rite of Progeniture: Tectonic Tide** (năng lượng 40, hồi chiêu 12s): tinh thể Geo nổ tung trước mặt; nếu
có Solar Isotoma của Albedo trên sân, sinh thêm 7 Fatal Blossom nổ theo AoE.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Elemental Burst DMG | 367.2% ATK | 660.96% ATK (cấp 14: 826%) |
| Fatal Blossom (mỗi cái) | 72% ATK | 129.6% ATK (cấp 14: 162%) |

**Passive A1 — Calcite Might:** Transient Blossom gây thêm 25% DMG lên địch dưới 50% HP.
**Passive A4 — Homuncular Nature:** dùng Bùng nổ tăng 125 Tinh Thông Nguyên Tố cho đồng đội quanh trong 10s.
**Witch's Eve Rite Passive — Book of Blinding Light** (Hexerei): sau khi hoàn thành Witch's Homework: Beyond the
Lesson, Albedo trở thành nhân vật Hexerei. Kỹ năng trúng địch trong 20s sau khi dùng sẽ tạo Silver Isotoma sinh
Transient Blossom kể cả khi không có Solar Isotoma (tối đa 2 cái); tạo Solar Isotoma tăng DMG đòn đánh cho đồng đội
theo DEF (tối đa 12%), tạo Silver Isotoma tăng DMG cho đồng đội Hexerei (tối đa 30%).
**Utility Passive:** 10% cơ hội x2 nguyên liệu khi chế vũ khí đột phá.

### Cung mệnh
1. **Flower of Eden** — Transient Blossom hồi 1.2 năng lượng cho Albedo.
2. **Opening of Phanerozoic** — Transient Blossom cho stack Fatal Reckoning (tối đa 4); dùng Bùng nổ tiêu hết stack,
   mỗi stack +30% DEF vào DMG của Fatal Blossom và nổ Bùng nổ.
3. Tăng cấp Abiogenesis: Solar Isotoma +3 (tối đa 15).
4. **Descent of Divinity** — Đồng đội trong vùng Solar Isotoma +30% DMG Nhảy.
5. Tăng cấp Rite of Progeniture: Tectonic Tide +3 (tối đa 15).
6. **Dust of Purification** — Đồng đội trong vùng Solar Isotoma có khiên Kết Tinh (Crystallize) +17% DMG.

**Vai trò đội hình Trầm Thủy:** DPS phụ/hỗ trợ off-field theo DEF, dựng Solar Isotoma làm bệ nhảy liên tục kích
Nhảy để cày sát thương diện rộng. Combo phổ biến: Albedo + Xiangling/Bennett (Vaporize/Melt buff ATK), hoặc
Albedo + nhân vật Kết Tinh (C6) trong đội Geo/Hyperbloom.

---

## Diluc

**Nguyên tố:** Pyro | **Vũ khí:** Đại kiếm | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ bạo kích |
|---|---|---|---|---|
| 1 | 1,010.52 | 26.07 | 61.03 | — |
| 90 | 12,980.67 | 334.85 | 783.93 | 19.2% |

### Bộ kỹ năng

**Đòn thường — Tempered Sword:** tối đa 4 đòn liên hoàn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 89.7% | 177.31% |
| 2-Hit | 87.63% | 173.23% |
| 3-Hit | 98.81% | 195.33% |
| 4-Hit | 133.99% | 264.86% |
| Đòn nặng lặp / cuối | 68.8% / 124.7% | 136% / 246.5% |
| Nhảy rơi/thấp/cao | 89.51% / 178.97% / 223.55% | 176.93% / 353.78% / 441.89% |

**Kỹ năng — Searing Onslaught** (hồi chiêu 10s, dùng liên tiếp tối đa 3 lần): chém về phía trước gây sát thương Pyro.
| Đòn | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| 1-Hit | 94.4% | 169.92% (cấp 14: 212.4%) |
| 2-Hit | 97.6% | 175.68% (cấp 14: 219.6%) |
| 3-Hit | 128.8% | 231.84% (cấp 14: 289.8%) |

**Bùng nổ — Dawn** (năng lượng 40, hồi chiêu 12s): giải phóng lửa mạnh đẩy lùi địch, ngọn lửa hội tụ vào vũ khí triệu
hồi Phượng Hoàng bay xuyên địch gây sát thương lớn rồi nổ tung; kiếm được phú Pyro 8s.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Slashing DMG | 204% ATK | 367.2% ATK (cấp 14: 459%) |
| DoT | 60% ATK | 108% ATK (cấp 14: 135%) |
| Explosion DMG | 204% ATK | 367.2% ATK (cấp 14: 459%) |

**Passive A1 — Relentless:** Đòn nặng giảm 50% tiêu hao thể lực, +3s thời lượng.
**Passive A4 — Blessing of Phoenix:** Phú Pyro của Dawn kéo dài thêm 4s, +20% DMG Pyro trong thời gian đó.
**Utility Passive:** hoàn 15% quặng khi chế Đại kiếm.

### Cung mệnh
1. **Conviction** — +15% DMG lên địch trên 50% HP.
2. **Searing Ember** — Khi bị đánh: +10% ATK, +5% tốc độ đánh (10s, tối đa 3 stack, 1.5s/lần).
3. Tăng cấp Searing Onslaught +3.
4. **Flowing Flame** — Searing Onslaught cách nhau đúng nhịp 2s: đòn tiếp theo +40% DMG (2s).
5. Tăng cấp Dawn +3.
6. **Flaming Sword, Nemesis of the Dark** — Sau Searing Onslaught, 2 Đòn thường tiếp theo (6s) +30% DMG & tốc đánh;
   Searing Onslaught không ngắt tổ hợp Đòn thường.

**Vai trò đội hình Trầm Thủy:** DPS chính on-field Pyro thuần, dùng cả Kỹ năng lẫn Đòn thường mạnh. Combo phổ biến:
Diluc + Kazuha/Sucrose (Xoáy để lan Pyro), hoặc Diluc + hỗ trợ Hydro (Vaporize) như Xingqiu/Yelan.

---

## Jean

**Nguyên tố:** Anemo | **Vũ khí:** Kiếm | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ hồi máu |
|---|---|---|---|---|
| 1 | 1,143.98 | 18.62 | 59.83 | — |
| 90 | 14,695.09 | 239.18 | 768.55 | 22.16% |

### Bộ kỹ năng

**Đòn thường — Favonius Bladework:** tối đa 5 đòn liên hoàn; Đòn nặng hất tung địch.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 48.33% | 95.54% |
| 2-Hit | 45.58% | 90.1% |
| 3-Hit | 60.29% | 119.17% |
| 4-Hit | 65.88% | 130.22% |
| 5-Hit | 79.21% | 156.57% |
| Đòn nặng | 162.02% | 320.28% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Gale Blade** (hồi chiêu 6s): giải phóng bão nhỏ hất tung địch theo hướng ngắm, DMG lớn; Giữ để hút địch
về phía trước (tiêu thể lực liên tục, tối đa 4s).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 292% ATK | 525.6% ATK (cấp 14: 657%) |

**Bùng nổ — Dandelion Breeze** (năng lượng 80, hồi chiêu 20s): tạo Dandelion Field hất tung địch quanh, đồng thời
hồi máu tức thì lớn cho cả đội; vùng field tiếp tục hồi máu + phú Anemo liên tục 10s, gây DMG khi địch ra/vào vùng.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Elemental Burst DMG | 424.8% ATK | 764.64% ATK (cấp 14: 956%) |
| Field Entering/Exiting DMG | 78.4% ATK | 141.12% ATK (cấp 14: 176%) |
| Hồi máu tức thì | 251.2% ATK+1,540 | 452.16% ATK+3,388 (cấp 14: 565% ATK+4,544) |
| Hồi máu liên tục/s | 25.12% ATK+154 | 45.22% ATK+338 (cấp 14: 56.52% ATK+454) |

**Passive A1 — Wind Companion:** Đòn thường trúng có 50% cơ hội hồi máu cả đội = 15% ATK Jean.
**Passive A4 — Let the Wind Lead:** Dandelion Breeze hồi lại 20% năng lượng của chính nó.
**Utility Passive:** món ăn hồi phục nấu Hoàn Hảo có 12% cơ hội nhân đôi.

### Cung mệnh
1. **Spiraling Tempest** — Giữ Gale Blade >1s: tăng tốc hút, +40% DMG.
2. **People's Aegis** — Nhặt tinh cầu/hạt nguyên tố: cả đội +15% tốc di chuyển/đánh (15s).
3. Tăng cấp Dandelion Breeze +3.
4. **Lands of Dandelion** — Trong vùng Dandelion Field, địch -40% kháng Anemo.
5. Tăng cấp Gale Blade +3.
6. **Lion's Fang, Fair Protector of Mondstadt** — Trong vùng Dandelion Field giảm 35% sát thương nhận; ra khỏi vùng
   hiệu lực còn 3 đòn hoặc 10s.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ/hồi máu + hất tung/Xoáy hàng đầu, gần như bắt buộc trong đội cần cứu sinh AoE
lớn. Combo phổ biến: Jean + bất kỳ DPS nguyên tố nào (Xoáy tăng sát thương/giảm kháng), Jean + Bennett (đệm/khoả HP).

---

## Klee

**Nguyên tố:** Pyro | **Vũ khí:** Pháp khí | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 20/10/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Pyro DMG Bonus |
|---|---|---|---|---|
| 1 | 800.79 | 24.21 | 47.86 | — |
| 90 | 10,286.57 | 310.93 | 614.84 | 28.8% |

### Bộ kỹ năng

**Đòn thường — Kaboom!:** tối đa 3 đòn nổ diện rộng.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 72.16% | 129.89% |
| 2-Hit | 62.4% | 112.32% |
| 3-Hit | 89.92% | 161.86% |
| Đòn nặng | 157.36% | 283.25% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Jumpy Dumpty** (hồi chiêu 20s, 2 charge sẵn): bom nảy 3 lần gây sát thương Pyro mỗi lần, lần 3 vỡ thành
nhiều mìn (8 quả) nổ khi chạm địch hoặc hết thời gian.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Jumpy Dumpty DMG | 95.2% ATK | 171.36% ATK (cấp 14: 214.2%) |
| Mine DMG | 32.8% ATK | 59.04% ATK (cấp 14: 73.8%) |

**Bùng nổ — Sparks 'n' Splash** (năng lượng 60, hồi chiêu 15s, thời lượng 10s): liên tục triệu hồi tia lửa tấn công
địch quanh khi Klee tại chỗ.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Sparks 'n' Splash DMG | 42.64% ATK | 76.75% ATK (cấp 14: 95.94%) |

**Passive A1 — Pounding Surprise (buff Hexerei):** Jumpy Dumpty/Đòn thường trúng có 50% nhận Explosive Spark, tiêu
để Đòn nặng tiếp theo không tốn thể lực và +50% DMG.
**Passive A4 — Sparkling Burst:** Đòn nặng bạo kích hồi 2 năng lượng cho cả đội.
**Witch's Eve Rite Passive — Sparkborne Magic (Hexerei):** sau Witch's Homework: Of Leaves That Spark, Klee thành
Hexerei; gây DMG bằng Đòn thường/Kỹ năng/Bùng nổ nhận Boom Badge (tối đa 3 loại, 20s/loại); có 1/2/3 Boom Badge thì
Đòn nặng đặc biệt Boom-Boom Strike +15%/30%/50% DMG.
**Utility Passive:** hiện tài nguyên đặc sản Mondstadt trên minimap.

### Cung mệnh
1. **Chained Reactions** — Đòn/Kỹ năng có cơ hội gọi tia lửa gây 120% DMG của Sparks 'n' Splash.
2. **Explosive Frags** — Trúng mìn Jumpy Dumpty: địch -23% DEF (10s).
3. Tăng cấp Jumpy Dumpty +3.
4. **Sparkly Explosion** — Rời sân khi Sparks 'n' Splash còn hiệu lực: nổ gây 555% ATK sát thương Pyro diện rộng.
5. Tăng cấp Sparks 'n' Splash +3.
6. **Blazing Delight** — Trong Sparks 'n' Splash, hồi 3 năng lượng/3s cho cả đội (trừ Klee); kích hoạt Bùng nổ cho cả
   đội +10% DMG Pyro (25s).

**Vai trò đội hình Trầm Thủy:** DPS chính on-field cực mạnh nhờ hệ số cao + AoE rộng. Combo phổ biến: Klee + Xingqiu
(Vaporize Melt Nổ), hoặc Klee + Sucrose/Kazuha (gom mìn Jumpy Dumpty vào 1 điểm).

---

## Mona

**Nguyên tố:** Hydro | **Vũ khí:** Pháp khí | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Nguyên Tố Hồi |
|---|---|---|---|---|
| 1 | 810.32 | 22.34 | 50.86 | — |
| 90 | 10,409.02 | 287.01 | 653.27 | 32% |

### Bộ kỹ năng

**Đòn thường — Ripple of Fate:** tối đa 4 đòn nước bắn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 37.6% | 71.44% |
| 2-Hit | 36% | 68.4% |
| 3-Hit | 44.8% | 85.12% |
| 4-Hit | 56.16% | 106.7% |
| Đòn nặng | 149.72% | 285.07% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 120.27% / 240.48% / 300.37% |

**Alternate Sprint — Illusory Torrent:** lướt nhanh trên nước, phú Wet khi hiện lại.

**Kỹ năng — Mirror Reflection of Doom** (hồi chiêu 12s, thời lượng 5s): tạo Phantom hút thù, gây sát thương liên tục,
nổ khi hết hạn/bị phá.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| DoT | 32% ATK | 57.6% ATK (cấp 14: 72%) |
| Explosion DMG | 132.8% ATK | 239.04% ATK (cấp 14: 298.8%) |

**Bùng nổ — Stellaris Phantasm** (năng lượng 60, hồi chiêu 15s): tạo Illusory Bubble diện rộng, phú Wet, khoá cứng
địch yếu; trúng sát thương thì phá bong bóng gây DMG Hydro + dính Omen (tăng DMG nhận).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Illusory Bubble Explosion DMG | 442.4% ATK | 796.32% ATK (cấp 14: 995%) |
| DMG Bonus (Omen) | 42% | 60% (từ cấp 10 trở lên giữ nguyên 60%) |
| Omen Duration | 4s | 5s (từ cấp 7) |

**Passive A1 — "Come 'n' Get Me, Hag!":** Illusory Torrent ≥2s tự tạo Phantom (2s, DMG=50% Mirror Reflection).
**Passive A4 — Waterborne Destiny:** +Hydro DMG Bonus = 20% Nguyên Tố Hồi.
**Witch's Eve Rite Passive — Genesis of Starsigns (Hexerei):** sau Witch's Homework: Of Untested Insight, Mona thành
Hexerei; Đòn thường/nặng trúng cho 1 stack Astral Glow of Mercury (tối đa 3, 8s); đồng đội trúng Vaporize tiêu hết
stack, mỗi stack +5% DMG Vaporize; cũng kéo dài Omen thêm 2s/lần trúng đòn (tối đa +8s).
**Utility Passive:** 25% cơ hội hoàn nguyên liệu khi chế vũ khí.

### Cung mệnh
1. **Prophecy of Submersion** — Đồng đội đánh trúng địch dính Omen: +15% DMG Electro-Charged/Lunar-Charged/
   Vaporize/Hydro Xoáy/Lunar-Crystallize, +15% thời lượng Đóng Băng (8s).
2. **Lunar Chain** — Đòn thường trúng có 20% tự nối thêm 1 Đòn nặng (5s/lần).
3. Tăng cấp Stellaris Phantasm +3.
4. **Prophecy of Oblivion** — Đánh trúng địch dính Omen: cả đội +15% Tỉ lệ bạo kích.
5. Tăng cấp Mirror Reflection of Doom +3.
6. **Rhetorics of Calamitas** — Vào Illusory Torrent: Đòn nặng tiếp theo +60% DMG/giây di chuyển (tối đa +180%, 8s).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ tăng sát thương/nhân sát thương hàng đầu qua Omen (+60% DMG lên toàn đội đánh
trúng). Combo phổ biến: Mona + bất kỳ DPS Hydro/Electro nào (Vaporize/Electro-Charged buff), Mona National-style
(Hu Tao/Xiangling/Bennett/Mona) từng là đội huyền thoại.

---

## Venti

**Nguyên tố:** Anemo | **Vũ khí:** Cung | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Nguyên Tố Hồi |
|---|---|---|---|---|
| 1 | 819.86 | 20.48 | 52.05 | — |
| 90 | 10,531.48 | 263.10 | 668.64 | 32% |

### Bộ kỹ năng

**Đòn thường — Divine Marksmanship:** tối đa 6 đòn cung.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit (x2) | 20.38%+20.38% | 40.29%+40.29% |
| 2-Hit | 44.38% | 87.72% |
| 3-Hit | 52.37% | 103.53% |
| 4-Hit (x2) | 26.06%+26.06% | 51.51%+51.51% |
| 5-Hit | 50.65% | 100.13% |
| 6-Hit | 70.95% | 140.25% |
| Ngắm bắn thường/full | 43.86% / 124% | 86.7% / 223.2% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 120.27% / 240.48% / 300.37% |

**Kỹ năng — Skyward Sonnet** (hồi chiêu Nhấn 6s / Giữ 15s): Nhấn tạo Wind Domain tại vị trí địch hất tung + DMG
Anemo; Giữ tạo Wind Domain lớn hơn tại Venti, sau đó Venti bay lên không.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Press DMG | 276% ATK | 496.8% ATK (cấp 13: 586.5%) |
| Hold DMG | 380% ATK | 684% ATK (cấp 13: 807.5%) |

**Bùng nổ — Wind's Grand Ode** (năng lượng 60, hồi chiêu 15s, thời lượng 8s): mũi tên gió tạo Stormeye khổng lồ hút
địch, gây DMG Anemo liên tục; hút nguyên tố Hydro/Pyro/Cryo/Electro để gây thêm DMG tương ứng.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| DoT (mỗi lượt) | 37.6% ATK | 67.68% ATK (cấp 14: 84.6%) |
| DMG nguyên tố hút thêm | 18.8% ATK | 33.84% ATK (cấp 14: 42.3%) |

**Passive A1 — Embrace of Winds:** Giữ Skyward Sonnet tạo luồng gió nâng kéo dài 20s.
**Passive A4 — Stormeye:** hết Wind's Grand Ode hồi 15 năng lượng cho Venti (và cho toàn bộ nhân vật cùng nguyên tố
hút nếu có Elemental Absorption).
**Witch's Eve Rite Passive — Temporal Wind's Eulogy (Hexerei):** sau Witch's Homework: Of the Waking of Wind, Venti
thành Hexerei; trong Stormeye, 4s sau khi nhân vật đang chiến đấu kích hoạt Xoáy: +50% DMG cho họ, Stormeye +35%
DMG (Hexerei: Secret Rite: Đòn thường của Venti hoá Windsunder Arrow xuyên địch khi đội có ≥2 Hexerei).
**Utility Passive:** giảm 20% tiêu hao thể lực khi lượn dù cho cả đội.

### Cung mệnh
1. **Splitting Gales** (buff Hexerei) — Ngắm bắn bắn thêm 2 mũi tên phụ, mỗi mũi = 33% DMG mũi chính.
2. **Breeze of Reminiscence** — Skyward Sonnet giảm 12% kháng Anemo/Vật lý (10s), địch bị hất tung giảm thêm 12%.
3. Tăng cấp Wind's Grand Ode +3.
4. **Hurricane of Freedom** (buff Hexerei) — Nhặt tinh cầu/hạt nguyên tố: +25% DMG Anemo (10s).
5. Tăng cấp Skyward Sonnet +3.
6. **Storm of Defiance** (buff Hexerei) — Trúng Wind's Grand Ode: -20% kháng Anemo (và nguyên tố hút nếu có).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ gom địch/kiểm soát hàng đầu, DPS off-field khi hút nguyên tố. Combo phổ biến:
Venti + bất kỳ DPS AoE nào (gom địch để tối đa hoá sát thương diện rộng), Venti hút Pyro/Cryo cho combo Xoáy lan rộng.

---

## Eula

**Nguyên tố:** Cryo | **Vũ khí:** Đại kiếm | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 18/05/2021

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 1,029.59 | 26.63 | 58.45 | — |
| 90 | 13,225.58 | 342.03 | 750.88 | 38.4% |

### Bộ kỹ năng

**Đòn thường — Favonius Bladework - Edel:** tối đa 5 đòn liên hoàn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 89.73% | 177.38% |
| 2-Hit | 93.55% | 184.93% |
| 3-Hit (x2) | 56.8%+56.8% | 112.28%+112.28% |
| 4-Hit | 112.64% | 222.67% |
| 5-Hit (x2) | 71.83%+71.83% | 142%+142% |
| Đòn nặng lặp / cuối | 68.8% / 124.4% | 136% / 245.91% |
| Nhảy rơi/thấp/cao | 74.59% / 149.14% / 186.29% | 147.44% / 294.82% / 368.25% |

**Kỹ năng — Icetide Vortex** (hồi chiêu Nhấn 4s / Giữ 10s): Nhấn chém nhanh gây DMG Cryo, trúng cho 1 stack
Grimheart (tối đa 2, tăng DEF & kháng ngắt); Giữ tiêu hết Grimheart chém mạnh AoE, mỗi stack tiêu tạo 1 Icewhirl
Brand gây DMG Cryo lan rộng, giảm kháng Vật lý/Cryo của địch.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Press DMG | 146.4% ATK | 263.52% ATK (cấp 14: 329.4%) |
| Hold DMG | 245.6% ATK | 442.08% ATK (cấp 14: 552.6%) |
| Icewhirl Brand DMG | 96% ATK | 172.8% ATK (cấp 14: 216%) |

**Bùng nổ — Glacial Illumination** (năng lượng 80, hồi chiêu 20s): vung đại kiếm gây DMG Cryo, tạo Lightfall Sword
theo Eula tối đa 7s, tích năng lượng từ mọi đòn của Eula, sau đó rơi xuống nổ gây DMG Vật lý theo số năng lượng tích.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 245.6% ATK | 442.08% ATK (cấp 14: 553%) |
| Lightfall Sword Base DMG | 367.05% ATK | 725.56% ATK (cấp 14: 991.3%) |
| DMG mỗi năng lượng (tối đa 30) | 74.99% ATK | 148.24% ATK (cấp 14: 202.5%) |

**Passive A1 — Roiling Rime:** Tiêu 2 Grimheart lúc Giữ tạo thêm 1 Shattered Lightfall Sword nổ ngay = 50% DMG cơ bản.
**Passive A4 — Wellspring of War-Lust:** Dùng Bùng nổ làm mới hồi chiêu Icetide Vortex, +1 Grimheart.
**Utility Passive:** 10% cơ hội x2 khi chế nguyên liệu tài năng.

### Cung mệnh
1. **Tidal Illusion** — Tiêu Grimheart: +30% DMG Vật lý (6s, mỗi lần tiêu +6s, tối đa 18s).
2. **Lady of Seafoam** — Hồi chiêu Giữ Icetide Vortex = hồi chiêu Nhấn.
3. Tăng cấp Glacial Illumination +3.
4. **The Obstinacy of One's Inferiors** — Lightfall Sword +25% DMG lên địch <50% HP.
5. Tăng cấp Icetide Vortex +3.
6. **Noble Obligation** — Lightfall Sword khởi đầu 5 năng lượng; mọi đòn có 50% thêm 1 năng lượng.

**Vai trò đội hình Trầm Thủy:** DPS chính on-field bùng nổ (burst DPS) dựa vào Bùng nổ tích lũy Lightfall Sword.
Combo phổ biến: Eula + Kaeya/Rosaria (đóng băng/kháng Vật lý giảm), Eula + hỗ trợ tạo khiên/kháng ngắt do bản thân
thiếu tự vệ.

---

## Durin

**Nguyên tố:** Pyro | **Vũ khí:** Kiếm | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt (trong game; Simulanka trong cốt truyện) | **Ngày ra mắt:** 03/12/2025 (Luna III)

Nhân vật hệ Hexerei, cơ chế "Essential Transmutation" chuyển đổi giữa 2 trạng thái Confirmation of Purity (Đòn thường
gốc + Bùng nổ Principle of Purity) và Denial of Darkness (Đòn thường/Kỹ năng đặc biệt + Bùng nổ Principle of
Darkness).

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 967.62 | 27.00 | 64.02 | — |
| 90 | 12,429.60 | 346.81 | 822.35 | 38.4% |

### Bộ kỹ năng

**Đòn thường — Radiant Wingslash:** tối đa 4 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 45.65% | 90.24% |
| 2-Hit | 41% | 81.06% |
| 3-Hit (x2) | 29.16%+29.16% | 57.65%+57.65% |
| 4-Hit | 71.15% | 140.65% |
| Đòn nặng | 113.43% | 224.23% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Binary Form: Convergence and Division** (hồi chiêu 12s): kích hoạt Essential Transmutation (6s) — Nhấn
Kỹ năng vào Confirmation of Purity (Transmutation: Confirmation of Purity, AoE Pyro), Nhấn Đòn thường vào Denial of
Darkness (Transmutation: Denial of Darkness, 3 đòn liên tiếp). Cả hai đảo trạng thái và hồi năng lượng (6s/lần).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Confirmation of Purity DMG | 105.6% ATK | 190.08% ATK (cấp 13: 224.4%) |
| Denial of Darkness (3 đòn) | 72.24%+53.2%+64.64% | 130.03%+95.76%+116.35% (cấp 13: 153.51%+113.05%+137.36%) |
| Hồi năng lượng | 6 | 33 (cấp 13: 42) |

**Bùng nổ — Principle of Purity: As the Light Shifts / Principle of Darkness: As the Stars Smolder** (năng lượng 70,
hồi chiêu 18s): tuỳ trạng thái mà dùng bản Purity (Rồng Bạch Diễm theo dõi tấn công diện rộng) hay Darkness (Rồng Hắc
Ám tấn công đơn mục tiêu định kỳ).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Bùng nổ Purity (3 đòn) | 118.96%+96.4%+111.84% | 214.13%+173.52%+201.31% (cấp 13: 252.79%+204.85%+237.66%) |
| Bùng nổ Darkness (3 đòn) | 125.44%+101.76%+111.84% | 225.79%+183.17%+201.31% (cấp 13: 266.56%+216.24%+237.66%) |
| Dragon of White Flame DMG | 94.64% ATK | 170.35% ATK (cấp 13: 201.11%) |
| Dragon of Dark Decay DMG | 129.84% ATK | 233.71% ATK (cấp 13: 275.91%) |

**Passive A1 — Light Manifest of the Divine Calculus:** Rồng Bạch Diễm giảm kháng Pyro+nguyên tố phản ứng của địch
20% (6s); Rồng Hắc Ám +40% DMG Vaporize/Melt.
**Passive A4 — Chaos Formed Like the Night:** sau Bùng nổ, nhận 10 stack Primordial Fusion, mỗi stack tiêu bởi đòn
Rồng tăng 3% DMG/100 ATK (tối đa 75%).
**Witch's Eve Rite Passive — Ode to Ascension (Hexerei):** khi đội có ≥2 Hexerei, hiệu ứng Passive A1 tăng 75%
(trừ thời lượng).
**Utility Passive:** +25% phần thưởng thám hiểm Mondstadt.

### Cung mệnh
1. **Adamah's Redemption** — Sau Bùng nổ: bản Purity cho đồng đội 20 stack Cycle of Enlightenment (tiêu 1 stack/đòn
   để +60% ATK Durin); bản Darkness cho Durin 20 stack, Bùng nổ tiêu 2 stack/lần +150% ATK.
2. **Unground Visions** — 20s sau Bùng nổ, phản ứng Pyro liên quan cho cả đội +50% DMG nguyên tố liên quan (6s).
3. Tăng cấp Principle of Purity +3.
4. **Emanare's Source** — +40% DMG Bùng nổ; 30% không tiêu Cycle of Enlightenment.
5. Tăng cấp Binary Form +3.
6. **Dual Birth** — Bùng nổ xuyên 30% DEF địch; Purity giảm 30% DEF địch trúng Rồng Bạch Diễm (6s); Darkness xuyên
   thêm 40% DEF.

**Vai trò đội hình Trầm Thủy:** DPS phụ/hỗ trợ off-field linh hoạt Pyro, chuyển đổi 2 trạng thái để phù hợp đội
Vaporize/Melt hoặc buff ATK toàn đội. Combo phổ biến: Durin + Prune/Nicole (Hexerei buff cộng dồn), Durin + DPS
Hydro/Cryo tận dụng Vaporize/Melt.

---

## Varka

**Nguyên tố:** Anemo | **Vũ khí:** Đại kiếm | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 25/02/2026 (Luna V)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 981.92 | 27.46 | 61.92 | — |
| 90 | 12,613.29 | 352.79 | 795.45 | 38.4% |

### Bộ kỹ năng

**Đòn thường — Favonius Bladework: Dancing Radiance:** tối đa 5 đòn (song kiếm).
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 65.46% | 129.4% |
| 2-Hit (2 phần) | 23.99%+44.55% | 47.42%+88.06% |
| 3-Hit (2 phần) | 32.44%+60.24% | 64.12%+119.08% |
| 4-Hit (2 phần) | 55.43%+29.85% | 109.57%+59% |
| 5-Hit (2 phần) | 69.75%+37.56% | 137.88%+74.24% |
| Đòn nặng (2 phần) | 85.64%+46.11% | 169.29%+91.15% |
| Nhảy rơi/thấp/cao | 74.59% / 149.14% / 186.29% | 147.44% / 294.82% / 368.25% |

**Kỹ năng — Windbound Execution** (hồi chiêu Nhấn 16s / Giữ 8s): Nhấn nhảy chém vào chế độ Sturm und Drang (Đòn
thường/nặng tăng DMG, kiếm trái luôn Anemo, kiếm phải chuyển nguyên tố Pyro>Hydro>Electro>Cryo theo đội hình); nếu
có nguyên tố phù hợp, Kỹ năng hoá **Four Winds' Ascension** (AoE 2 nguyên tố) và có thể tung **Azure Devour** (Đòn
nặng đặc biệt miễn phí). Giữ để nhảy xa tuỳ thời gian giữ.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 278.4% ATK | 501.12% ATK (cấp 13: 591.6%) |
| Sturm und Drang 1-Hit | 81.82% | 161.75% (cấp 13: 196%) |
| Sturm und Drang 5-Hit | 87.19%+46.95% | 172.35%+92.8% (cấp 13: 208.84%+112.45%) |

**Bùng nổ — Northwind Avatar** (năng lượng 60, hồi chiêu 15s): chém đôi gây 2 lần DMG Anemo; nếu đội có nguyên tố
Pyro/Hydro/Electro/Cryo, đòn đầu hoá nguyên tố tương ứng.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Đòn 1 | 336.96% ATK | 606.53% ATK (cấp 13: 716.04%) |
| Đòn 2 | 181.44% ATK | 326.59% ATK (cấp 13: 385.56%) |

**Passive A1 — Dawn Wind's March:** mỗi 1,000 ATK +10% DMG Anemo & nguyên tố tương ứng (tối đa 25%); có ≥2 Anemo
hoặc ≥2 nhân vật cùng nguyên tố kia trong đội thì Đòn thường/nặng/Four Winds/Azure Devour trong Sturm und Drang
+140% DMG (220% nếu đủ cả hai điều kiện).
**Passive A4 — Wind's Vanguard:** Xoáy của đồng đội cho 1 stack Azure Fang's Oath (+7.5% DMG các đòn kể trên, tối
đa 4 stack).
**Witch's Eve Rite Passive — Dawn's Return (Hexerei):** đội có ≥2 Hexerei giảm 1s hồi chiêu Four Winds' Ascension
mỗi lần Đòn thường trúng trong Sturm und Drang.
**Utility Passive:** mỗi đồng đội gốc Mondstadt giảm 5% hồi chiêu bản Giữ của Windbound Execution.

### Cung mệnh
1. Thêm 1 lượt Four Winds' Ascension khi vào Sturm und Drang; nhận Lyrical Libation (Four Winds/Azure Devour tiếp
   theo +200% DMG).
2. Four Winds/Azure Devour đánh thêm 1 đòn = 800% ATK.
3. Tăng cấp Windbound Execution +3.
4. Trúng Xoáy: cả đội +20% DMG Anemo & nguyên tố liên quan (10s).
5. Tăng cấp Northwind Avatar +3.
6. Miễn phí thêm Four Winds/Azure Devour trong thời gian ngắn; Azure Fang's Oath +20% Tỉ lệ st bạo kích/stack.

**Vai trò đội hình Trầm Thủy:** DPS chính on-field linh hoạt nguyên tố (song kiếm gây 2 loại DMG cùng lúc), càng
mạnh khi đội có 2 nhân vật cùng nguyên tố phụ. Combo phổ biến: Varka + Prune (Hexerei, Anemo Xoáy), Varka + cặp đôi
Pyro/Hydro/Electro/Cryo để tối ưu +220% DMG.

---

## Lohen

**Nguyên tố:** Cryo | **Vũ khí:** Thương | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 09/06/2026 (Luna VII)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 1,000.99 | 26.81 | 61.03 | — |
| 90 | 12,858.21 | 344.42 | 783.93 | 38.4% |

### Bộ kỹ năng

**Đòn thường — Spear of Favonius — Broken Oath:** tối đa 5 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 53.99% | 106.73% |
| 2-Hit | 56.44% | 111.57% |
| 3-Hit (x3) | 25.42%×3 | 50.25%×3 |
| 4-Hit | 75.23% | 148.7% |
| 5-Hit (2 phần) | 36.86%+55.29% | 72.86%+109.29% |
| Đòn nặng (x2) | 65.88%×2 | 130.22%×2 |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Unforeseen Strike** (hồi chiêu 18s): vào chế độ Masterstroke (13s, Đòn thường/nặng/nhảy hoá Cryo);
đánh trúng tích Joy (đủ 100 hoá Kỹ năng đặc biệt **Etched Into Bone and Soul**, tối đa 3 lần); đồng đội gây DMG tích
Will to Win cho Lohen (tăng DMG của Etched Into Bone and Soul).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Etched Into Bone and Soul (x4) | 60%×4 | 108%×4 (cấp 13: 127.5%×4) |
| DMG tăng theo Will to Win | 0.4%/điểm (không đổi theo cấp) | |

**Bùng nổ — Manifest Judgment** (năng lượng 60, hồi chiêu 15s): loạt đâm liên tiếp, tiêu hết Will to Win để tăng DMG
theo lượng tiêu; nếu đang Masterstroke thì kéo dài thêm 1.65s.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG (x6) | 118.8%×6 | 213.84%×6 (cấp 13: 252.45%×6) |
| DMG tăng theo Will to Win | 0.4%/điểm | |

**Passive A1 — Moratorium on Questioning:** đồng đội gây DMG ≥3,000% ATK cơ bản của Lohen khi đang Masterstroke thì
tích thêm 60 Will to Win.
**Passive A4 — Flippant Masterpiece:** trong Masterstroke, đồng đội kích hoạt phản ứng Cryo: cả hai +15% ATK (8s).
**Witch's Eve Rite Passive — Unhealing Thorn (Hexerei):** đội có ≥2 Hexerei, Etched Into Bone and Soul/Bùng nổ trúng
khi Will to Win ≥50%: +40% DMG Đòn thường/nặng (6s).
**Utility Passive — When the Mood Strikes:** dùng Kỹ năng được "High Spirits" 9s (+1 cấp Kỹ năng); nếu đồng đội có
cấp talent ngang bằng thì +6s (18s/lần).

### Cung mệnh
1. Tăng giới hạn Will to Win lên 300%; đồng đội tích Will to Win x5 khi đang Unforeseen Strike.
2. Sau Etched Into Bone/Bùng nổ trong Masterstroke: nhận Evilsbane Blade (đòn tiếp theo thêm 500% ATK AoE + đồng đội
   +200 Tinh Thông Nguyên Tố 8s).
3. Tăng cấp Unforeseen Strike +3.
4. Bùng nổ trong Masterstroke tự max Will to Win; hồi năng lượng linh hoạt khi chuyển Masterstroke.
5. Tăng cấp Manifest Judgment +3.
6. Etched Into Bone/Bùng nổ không tiêu Will to Win (đổi thành max Joy); +175% Tỉ lệ st bạo kích các đòn liên quan.

**Vai trò đội hình Trầm Thủy:** DPS chính on-field Cryo tần suất cao, càng mạnh khi đồng đội gây sát thương lớn để
tích Will to Win. Combo phổ biến: Lohen + Nicole/Durin (Hexerei buff), Lohen + DPS phá giáp mạnh để tích Will to Win
nhanh.

---

## Nicole

**Nguyên tố:** Pyro | **Vũ khí:** Pháp khí | **Độ hiếm:** 5★ | **Quốc gia:** Mondstadt (không có Region chính thức — phe Hexenzirkel độc lập) | **Ngày ra mắt:** 20/05/2026 (Luna VII)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (ATK phụ) |
|---|---|---|---|---|
| 1 | 810.32 | 26.63 | 43.80 | — |
| 90 | 10,409.02 | 342.03 | 562.58 | 28.8% |

### Bộ kỹ năng

**Đòn thường — Allegoria:** tối đa 3 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 35.18% | 63.32% |
| 2-Hit | 29.63% | 53.34% |
| 3-Hit | 46.19% | 83.14% |
| Đòn nặng | 112.32% | 202.18% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Revelation: Uncreated Light** (hồi chiêu 16s): ban Grace of Kenosis cho đồng đội quanh (+ATK, gây DMG
Pyro diện rộng, tạo khiên Shield of Blazing Light hấp thụ theo ATK, hiệu quả x2.5 với Pyro).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 138.4% ATK | 249.12% ATK (cấp 13: 294.1%) |
| Grace of Kenosis (tỉ lệ ATK) | 8.25% ATK | 15% ATK (cấp 13: 17.7%) |
| Max ATK Bonus | 330 | 600 (cấp 13: 708) |
| Shield DMG Absorption | 221.18% ATK+1,387 | 398.13% ATK+3,051 (cấp 13: 470.02% ATK+3,814) |

**Bùng nổ — Revelation: Ladder of Divine Ascent** (năng lượng 60, hồi chiêu 15s, thời lượng 20s): gây DMG Pyro AoE,
vào chế độ Silent Contemplation — nhân vật đang chiến đấu đánh trúng thì Nicole triệu hồi Arcane Projection đánh phối
hợp theo nguyên tố của họ (3s/lần, tối đa 4 lần/lượt Bùng nổ).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 316.8% ATK | 570.24% ATK (cấp 13: 673.2%) |
| Arcane Projection DMG | 99% ATK nhân vật đang chiến đấu | 180% ATK (cấp 13: 212.4%) |

**Passive A1 — Methexis:** 20s sau Kỹ năng, nhân vật đang chiến đấu (≥3s hoặc là Hexerei) nâng Grace of Kenosis lên
Guidance of Theosis (+300 ATK cố định).
**Passive A4 — Philokalia:** đồng đội gây DMG nguyên tố trúng địch: Grace of Kenosis của Nicole tự nâng lên Guidance
of Theosis (8s).
**Witch's Eve Rite Passive — Light in the Darkness (Hexerei):** đội có ≥2 Hexerei, Arcane Projection của nhân vật
Hexerei +300% ATK Nicole sát thương.
**Utility Passive — Nepsis:** ngoài chiến đấu, Đòn nặng hoá "Emissarial Guidance" dò tài nguyên như La Bàn Kho Báu.

### Cung mệnh
1. Nhân vật đang chiến đấu đánh trúng: thêm 1 Arcane Projection: Unity = 600% ATK của họ (6s/lần).
2. Grace of Kenosis +300 ATK cố định thêm; Guidance of Theosis giảm 25% kháng nguyên tố tương ứng của địch (không
   chồng cùng nguyên tố); Kỹ năng cho khiên cho cả đội quanh.
3. Tăng cấp Revelation: Uncreated Light +3.
4. Nâng lên Guidance of Theosis: cho Pathfinder's Blessing (+70% ATK Nicole vào mọi loại DMG, 8 lần hoặc 20s).
5. Tăng cấp Revelation: Ladder of Divine Ascent +3.
6. Nicole lên Guidance of Theosis thì cả đội cũng lên theo (vĩnh viễn); DMG của nhân vật Guidance of Theosis xuyên
   40% DEF địch.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ buff ATK diện rộng + khiên + sát thương hộ tống (Arcane Projection biến DMG
đồng đội thành DMG bổ sung). Combo phổ biến: Nicole + Prune/Durin/Varka/Lohen (Hexerei full buff), Nicole + bất kỳ
DPS ATK-scale nào.

---

## Amber

**Nguyên tố:** Pyro | **Vũ khí:** Cung | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (ATK phụ) |
|---|---|---|---|---|
| 1 | 793.26 | 18.70 | 50.36 | — |
| 90 | 9,461.18 | 223.02 | 600.62 | 24% |

### Bộ kỹ năng

**Đòn thường — Sharpshooter:** tối đa 5 đòn cung.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1–2-Hit | 36.12% | 71.4% |
| 3-Hit | 46.44% | 91.8% |
| 4-Hit | 47.3% | 93.5% |
| 5-Hit | 59.34% | 117.3% |
| Ngắm bắn thường/full | 43.86% / 124% | 86.7% / 223.2% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Explosive Puppet** (hồi chiêu 15s): triệu hồi Baron Bunny hút thù, nổ khi hết hạn/bị phá gây DMG Pyro.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Inherited HP (%Max HP Amber) | 41.36% | 74.45% (cấp 14: 93.1%) |
| Explosion DMG | 123.2% ATK | 221.76% ATK (cấp 14: 277%) |

**Bùng nổ — Fiery Rain** (năng lượng 40, hồi chiêu 12s): mưa tên gây DMG Pyro liên tục (18 lượt bắn).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| DMG mỗi lượt | 28.08% ATK | 50.54% ATK (cấp 14: 63.2%) |
| Tổng DMG | 505.44% ATK | 909.79% ATK (cấp 14: 1,137%) |

**Passive A1 — Every Arrow Finds Its Target:** +10% Tỉ lệ st bạo kích, +30% AoE cho Fiery Rain.
**Passive A4 — Precise Shot:** Ngắm bắn trúng điểm yếu: +15% ATK (10s).
**Utility Passive:** giảm 20% tiêu hao thể lực lượn dù cho cả đội.

### Cung mệnh
1. Ngắm bắn thêm 1 mũi phụ = 20% DMG mũi chính.
2. Bắn trúng chân Baron Bunny bằng Ngắm bắn full: kích nổ thủ công +200% DMG.
3. Tăng cấp Fiery Rain +3.
4. Giảm 20% hồi chiêu Explosive Puppet, +1 charge.
5. Tăng cấp Explosive Puppet +3.
6. Fiery Rain: cả đội +15% tốc di chuyển & ATK (10s).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ hút thù/gây Pyro sớm game, ít dùng ở đội hình cao cấp nhưng vẫn hữu ích để mồi
Reverse Melt/Vaporize và hút damage cho đội mỏng máu.

---

## Barbara

**Nguyên tố:** Hydro | **Vũ khí:** Pháp khí | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ hồi máu |
|---|---|---|---|---|
| 1 | 820.61 | 13.36 | 56.08 | — |
| 90 | 9,787.42 | 159.30 | 668.87 | 24% |

### Bộ kỹ năng

**Đòn thường — Whisper of Water:** tối đa 4 đòn nước.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 37.84% | 68.11% |
| 2-Hit | 35.52% | 63.94% |
| 3-Hit | 41.04% | 73.87% |
| 4-Hit | 55.2% | 99.36% |
| Đòn nặng | 166.24% | 299.23% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Let the Show Begin♪** (hồi chiêu 32s, thời lượng 15s): tạo Melody Loop — Đòn thường/nặng trúng hồi máu
cả đội (theo Max HP), định kỳ tự hồi máu cho nhân vật đang chiến đấu, phú Wet.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Hồi máu/đòn trúng | 0.75% Max HP+72.2 | 1.35% Max HP+158.9 (cấp 13: 1.59% Max HP+198.63) |
| Hồi máu liên tục | 4% Max HP+385.18 | 7.2% Max HP+847.47 (cấp 13: 8.5% Max HP+1,059) |
| Droplet DMG | 58.4% ATK | 105.12% ATK (cấp 13: 124.1%) |

**Bùng nổ — Shining Miracle♪** (năng lượng 80, hồi chiêu 20s): hồi máu lớn tức thì cho cả đội.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Hồi máu | 17.6% Max HP+1,694 | 31.68% Max HP+3,727 (cấp 14: 39.6% Max HP+4,999) |

**Passive A1 — Glorious Season:** giảm 12% tiêu hao thể lực trong vùng Melody Loop.
**Passive A4 — Encore:** nhặt tinh cầu/hạt nguyên tố kéo dài Melody Loop +1s (tối đa +5s).
**Utility Passive:** món hồi phục nấu Hoàn Hảo 12% cơ hội x2.

### Cung mệnh
1. Tự hồi 1 năng lượng/10s.
2. Giảm 15% hồi chiêu Kỹ năng; nhân vật đang chiến đấu trong Kỹ năng +15% DMG Hydro.
3. Tăng cấp Shining Miracle♪ +3.
4. Đòn nặng trúng địch hồi 1 năng lượng (tối đa 5/lần).
5. Tăng cấp Let the Show Begin♪ +3.
6. Barbara không tại sân, đồng đội gục: tự hồi sinh 100% HP (15 phút/lần).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ hồi máu chủ lực cho đội cần sustain cao, đặc biệt hợp với Xiangling/Hu Tao
(cân bằng HP) hoặc bất kỳ đội nào cần cứu sinh liên tục.

---

## Bennett

**Nguyên tố:** Pyro | **Vũ khí:** Kiếm | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt (Natlan trong cốt truyện) | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Nguyên Tố Hồi |
|---|---|---|---|---|
| 1 | 1,039.44 | 16.03 | 64.66 | — |
| 90 | 12,397.40 | 191.16 | 771.25 | 26.68% |

### Bộ kỹ năng

**Đòn thường — Strike of Fortune:** tối đa 5 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 44.55% | 88.06% |
| 2-Hit | 42.74% | 84.49% |
| 3-Hit | 54.61% | 107.95% |
| 4-Hit | 59.68% | 117.98% |
| 5-Hit | 71.9% | 142.12% |
| Đòn nặng (2 phần) | 55.9%+60.72% | 110.5%+120.02% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Passion Overload** (hồi chiêu 5/7.5/10s): Nhấn chém nhanh 1 đòn; Giữ cấp 1 chém 2 đòn hất tung; Giữ cấp
2 chém 3 đòn kèm nổ hất tung cả Bennett (không sát thương lên Bennett).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Press DMG | 137.6% ATK | 247.68% ATK (cấp 14: 310%) |
| Charge Lv1 (2 đòn) | 84%+92% ATK | 151.2%+165.6% ATK (cấp 14: 189%+207%) |
| Charge Lv2 (2 đòn) | 88%+96% ATK | 158.4%+172.8% ATK (cấp 14: 198%+216%) |
| Explosion DMG | 132% ATK | 237.6% ATK (cấp 14: 297%) |

**Bùng nổ — Fantastic Voyage** (năng lượng 60, hồi chiêu 15s, thời lượng 12s): nhảy công gây DMG Pyro, tạo
Inspiration Field — nhân vật ≤70% HP hồi máu liên tục theo Max HP Bennett, >70% HP nhận ATK Bonus theo Base ATK
Bennett; phú Pyro cho nhân vật trong vùng.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 232.8% ATK | 419.04% ATK (cấp 14: 524%) |
| Hồi máu liên tục/s | 6% Max HP+577 | 10.8% Max HP+1,270 (cấp 14: 13.5% Max HP+1,703) |
| ATK Bonus | 56% Base ATK | 100.8% Base ATK (cấp 14: 126%) |

**Passive A1 — Rekindle:** giảm 20% hồi chiêu Passion Overload.
**Passive A4 — Fearnaught:** trong vùng Fantastic Voyage, Passion Overload giảm 50% hồi chiêu, Bennett không bị hất.
**Utility Passive:** giảm 25% thời gian thám hiểm Mondstadt.

### Cung mệnh
1. **Grand Expectation** — ATK Bonus của Fantastic Voyage bỏ giới hạn HP, +20% Base ATK.
2. HP <70%: +30% Nguyên Tố Hồi.
3. Tăng cấp Passion Overload +3.
4. Charge Lv1 dùng Đòn thường làm đòn 2: thêm 1 đòn phụ = 135% DMG đòn 2.
5. Tăng cấp Fantastic Voyage +3.
6. Kiếm/Đại kiếm/Thương trong vùng Fantastic Voyage: +15% DMG Pyro, vũ khí phú Pyro.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ buff ATK + hồi máu bậc nhất game, gần như universal cho mọi đội on-field DPS
vật lý/nguyên tố (ngoại trừ đội cần né Pyro). Combo kinh điển: Bennett + bất kỳ DPS ATK-scale + Xiangling/Kazuha.

---

## Diona

**Nguyên tố:** Cryo | **Vũ khí:** Cung | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 11/11/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Cryo DMG Bonus |
|---|---|---|---|---|
| 1 | 802.38 | 17.81 | 50.36 | — |
| 90 | 9,569.93 | 212.40 | 600.62 | 24% |

### Bộ kỹ năng

**Đòn thường — Kätzlein Style:** tối đa 5 đòn cung.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 36.12% | 71.4% |
| 2-Hit | 33.54% | 66.3% |
| 3-Hit | 45.58% | 90.1% |
| 4-Hit | 43% | 85% |
| 5-Hit | 53.75% | 106.25% |
| Ngắm bắn thường/full | 43.86% / 124% | 86.7% / 223.2% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Icy Paws** (hồi chiêu Nhấn 6s / Giữ 15s): Nhấn bắn 2 Icy Paw nhanh; Giữ lùi lại bắn 5 Icy Paw, khiên
+75% hấp thụ. Icy Paw trúng tạo khiên (hiệu quả x2.5 với Cryo).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| DMG mỗi Paw | 41.92% ATK | 75.46% ATK (cấp 14: 94.3%) |
| Khiên cơ bản | 7.2% Max HP+692.8 | 12.96% Max HP+1,524 (cấp 14: 16.2% Max HP+2,044) |

**Bùng nổ — Signature Mix** (năng lượng 80, hồi chiêu 20s, thời lượng 12s): tạo Drunken Mist gây DMG Cryo liên tục
và hồi máu liên tục cho nhân vật trong vùng.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 80% ATK | 144% ATK (cấp 14: 180%) |
| Continuous Field DMG | 52.64% ATK | 94.75% ATK (cấp 14: 118.4%) |
| Hồi máu liên tục | 5.34% Max HP+513 | 9.6% Max HP+1,129 (cấp 14: 12.01% Max HP+1,514) |

**Passive A1 — Cat's Tail Secret Menu:** nhân vật có khiên Icy Paws +10% tốc di chuyển, -10% tiêu hao thể lực.
**Passive A4 — Drunkards' Farce:** địch vào vùng Signature Mix -10% ATK (15s).
**Witch's Revelation Passive — Choice Treasures:** 20s sau Icy Paws, đồng đội kích hoạt Superconduct/Stellar-Conduct/
Cryo Xoáy/Stellar Xoáy: Diona tự bắn thêm 3 Icy Paw không tạo khiên (3.5s/lần); cũng vào Radiance: Stellar-Conduct/
Swirl khi hợp điều kiện.
**Utility Passive:** món hồi phục nấu Hoàn Hảo 12% cơ hội x2.

### Cung mệnh
1. Hết Signature Mix hồi 15 năng lượng.
2. +15% DMG & khiên Icy Paws; Paw trúng tạo thêm khiên phụ 50% cho đồng đội khác (5s).
3. Tăng cấp Signature Mix +3.
4. Trong vùng Signature Mix, giảm 60% thời gian sạc Ngắm bắn.
5. Tăng cấp Icy Paws +3.
6. Trong Signature Mix: HP ≤50% +30% tỉ lệ hồi máu nhận; HP >50% +200 Tinh Thông Nguyên Tố.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ khiên + hồi máu Cryo phổ biến, phù hợp mọi đội Cryo/Freeze cần khiên rẻ và
sustain nhẹ. Combo phổ biến: Diona + Kaeya/Chongyun (Đóng Băng), Diona + bất kỳ DPS Cryo chính nào.

---

## Fischl

**Nguyên tố:** Electro | **Vũ khí:** Cung | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (ATK phụ) |
|---|---|---|---|---|
| 1 | 770.46 | 20.48 | 49.79 | — |
| 90 | 9,189.30 | 244.26 | 593.79 | 24% |

### Bộ kỹ năng

**Đòn thường — Bolts of Downfall:** tối đa 5 đòn cung.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 44.12% | 87.21% |
| 2-Hit | 46.78% | 92.48% |
| 3-Hit | 58.14% | 114.92% |
| 4-Hit | 57.71% | 114.07% |
| 5-Hit | 72.07% | 142.46% |
| Ngắm bắn thường/full | 43.86% / 124% | 86.7% / 223.2% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Nightrider** (hồi chiêu 25s, thời lượng 10s): triệu hồi Oz tấn công liên tục gây DMG Electro (1 đòn/s).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| DMG khi triệu hồi | 115.44% ATK | 207.79% ATK (cấp 14: 260%) |
| DMG mỗi đòn Oz | 88.8% ATK | 159.84% ATK (cấp 14: 200%) |

**Bùng nổ — Midnight Phantasmagoria** (năng lượng 60, hồi chiêu 15s): Fischl hoá thân Oz, tăng tốc di chuyển, chạm
địch gây DMG Electro; hết hiệu lực Oz ở lại chiến trường (làm mới thời gian nếu đã có Oz).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Falling Thunder DMG | 208% ATK | 374.4% ATK (cấp 14: 468%) |

**Passive A1 — Stellar Predator:** Ngắm bắn full trúng Oz: Oz phản đòn Thundering Retribution = 152.7% DMG mũi tên.
**Passive A4 — Undone Be Thy Sinful Hex:** phản ứng Electro khi có Oz trên sân: Thundering Retribution = 80% ATK.
**Witch's Eve Rite Passive — Phantasmal Nocturne (Hexerei):** đội có ≥2 Hexerei, khi Oz tại sân: đồng đội kích hoạt
Overloaded +22.5% ATK (10s); kích hoạt Electro-Charged/Lunar-Charged +90 Tinh Thông Nguyên Tố (10s).
**Utility Passive:** giảm 25% thời gian thám hiểm Mondstadt.

### Cung mệnh
1. Oz không tại sân vẫn phản đòn Đòn thường trúng = 22% ATK.
2. Nightrider thêm 1 đòn = 200% ATK, +50% AoE.
3. Tăng cấp Nightrider +3.
4. Midnight Phantasmagoria thêm 222% ATK DMG Electro; hết hiệu lực hồi 20% HP.
5. Tăng cấp Midnight Phantasmagoria +3.
6. Oz tại sân thêm 2s thời lượng; đánh phối hợp = 30% ATK Fischl.

**Vai trò đội hình Trầm Thủy:** DPS off-field Electro cực bền (Oz gần như luôn tại sân), gần như bắt buộc trong mọi
đội cần nguồn Electro ổn định. Combo phổ biến: Fischl + bất kỳ DPS Hydro (Electro-Charged), Fischl + Raiden/Electro
support cho Hyperbloom/Aggravate.

---

## Kaeya

**Nguyên tố:** Cryo | **Vũ khí:** Kiếm | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt (Khaenri'ah trong cốt truyện) | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Nguyên Tố Hồi |
|---|---|---|---|---|
| 1 | 975.62 | 18.70 | 66.38 | — |
| 90 | 11,636.16 | 223.02 | 791.72 | 26.68% |

### Bộ kỹ năng

**Đòn thường — Ceremonial Bladework:** tối đa 5 đòn, đòn 5 dịch chuyển ra sau lưng địch.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 53.75% | 106.25% |
| 2-Hit | 51.69% | 102.17% |
| 3-Hit | 65.27% | 129.03% |
| 4-Hit | 70.86% | 140.08% |
| 5-Hit | 88.24% | 174.42% |
| Đòn nặng (2 phần) | 55.04%+73.1% | 108.8%+144.5% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Frostgnaw** (hồi chiêu 6s): chém lạnh gây DMG Cryo trước mặt.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 191.2% ATK | 344.16% ATK (cấp 14: 430%) |

**Bùng nổ — Glacial Waltz** (năng lượng 60, hồi chiêu 15s, thời lượng 8s): 3 mảnh băng xoay quanh gây DMG Cryo liên
tục theo đường di chuyển.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 77.6% ATK | 139.68% ATK (cấp 14: 175%) |

**Passive A1 — Cold-Blooded Strike:** Frostgnaw trúng hồi máu = 15% ATK Kaeya.
**Passive A4 — Glacial Heart:** địch bị Đóng Băng bởi Frostgnaw rơi thêm hạt nguyên tố (tối đa 2/lần).
**Utility Passive:** giảm 20% tiêu hao thể lực chạy nước rút cho cả đội.

### Cung mệnh
1. +15% Tỉ lệ st bạo kích Đòn thường/nặng lên địch dính Cryo.
2. Mỗi địch bị hạ trong Glacial Waltz kéo dài +2.5s (tối đa 15s).
3. Tăng cấp Frostgnaw +3.
4. HP <20%: tự tạo khiên hấp thụ 30% Max HP (20s, hiệu quả x2.5 Cryo, 60s/lần).
5. Tăng cấp Glacial Waltz +3.
6. Glacial Waltz thêm 1 mảnh băng, hồi 15 năng lượng khi dùng.

**Vai trò đội hình Trầm Thủy:** DPS off-field Cryo/tạo Đóng Băng đa năng, chi phí thấp nhưng hiệu quả cao trong đội
Freeze/Melt. Combo phổ biến: Kaeya + bất kỳ DPS Hydro (Đóng Băng), Kaeya + Chongyun/Diona.

---

## Lisa

**Nguyên tố:** Electro | **Vũ khí:** Pháp khí | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tinh Thông Nguyên Tố |
|---|---|---|---|---|
| 1 | 802.38 | 19.41 | 48.07 | — |
| 90 | 9,569.93 | 231.51 | 573.32 | 96 |

### Bộ kỹ năng

**Đòn thường — Lightning Touch:** tối đa 4 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 39.6% | 71.28% |
| 2-Hit | 35.92% | 64.66% |
| 3-Hit | 42.8% | 77.04% |
| 4-Hit | 54.96% | 98.93% |
| Đòn nặng | 177.12% | 318.82% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Violet Arc** (hồi chiêu Nhấn 1s / Giữ 16s): Nhấn bắn cầu sét dò tìm, trúng cho 1 stack Conductive (tối
đa 3); Giữ gọi sét diện rộng, tăng mạnh DMG theo stack Conductive tiêu (xoá stack).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Press DMG | 80% ATK | 144% ATK (cấp 13: 170%) |
| Hold DMG (0 stack) | 320% ATK | 576% ATK (cấp 13: 680%) |
| Hold DMG (3 stack) | 487.2% ATK | 876.96% ATK (cấp 13: 1,035.3%) |

**Bùng nổ — Lightning Rose** (năng lượng 80, hồi chiêu 20s, thời lượng 15s): triệu hồi Lightning Rose phóng sét liên
tục hất tung địch.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Discharge DMG | 36.56% ATK | 65.81% ATK (cấp 14: 82.3%) |

**Passive A1 — Induced Aftershock:** Đòn nặng trúng cũng tạo stack Conductive.
**Passive A4 — Static Electricity Field:** địch trúng Lightning Rose -15% DEF (10s).
**Utility Passive:** 20% cơ hội hoàn nguyên liệu khi pha chế thuốc.

### Cung mệnh
1. Giữ Violet Arc trúng địch hồi 2 năng lượng/địch (tối đa 10).
2. Giữ Violet Arc: +25% DEF, +kháng ngắt.
3. Tăng cấp Lightning Rose +3.
4. Lightning Rose bắn 1-3 tia mỗi lượt thay vì 1.
5. Tăng cấp Violet Arc +3.
6. Vào sân: phú 3 stack Conductive cho địch quanh (5s/lần).

**Vai trò đội hình Trầm Thủy:** DPS/khởi phát Electro linh hoạt, Giữ Kỹ năng gây sát thương lớn theo stack, phù hợp
đội Electro-Charged/Aggravate. Combo phổ biến: Lisa + DPS Hydro (Electro-Charged), Lisa + Fischl/Razor.

---

## Mika

**Nguyên tố:** Cryo | **Vũ khí:** Thương | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 21/03/2023

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (HP phụ) |
|---|---|---|---|---|
| 1 | 1,048.56 | 18.70 | 59.80 | — |
| 90 | 12,506.15 | 223.02 | 713.23 | 24% |

### Bộ kỹ năng

**Đòn thường — Spear of Favonius - Arrow's Passage:** tối đa 5 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 43.26% | 85.52% |
| 2-Hit | 41.5% | 82.04% |
| 3-Hit | 54.5% | 107.74% |
| 4-Hit (x2) | 27.61%×2 | 54.59%×2 |
| 5-Hit | 70.87% | 140.1% |
| Đòn nặng | 112.75% | 222.87% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Starfrost Swirl** (hồi chiêu 15s, thời lượng Soulwind 12s): ban Soulwind cho đội (+tốc đánh). Nhấn bắn
Flowfrost Arrow xuyên địch; Giữ ngắm bắn Rimestar Flare, nổ bắn Rimestar Shard vào tối đa 3 địch khác.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Flowfrost Arrow DMG | 67.2% ATK | 120.96% ATK (cấp 13: 142.8%) |
| Rimestar Flare DMG | 84% ATK | 151.2% ATK (cấp 13: 178.5%) |
| Rimestar Shard DMG | 25.2% ATK | 45.36% ATK (cấp 13: 53.55%) |
| Tốc đánh Soulwind | 13% | 22% (cấp 13: 25%) |

**Bùng nổ — Skyfeather Song** (năng lượng 70, hồi chiêu 18s, thời lượng 15s): hồi máu cả đội tức thì + ban trạng
thái Eagleplume (Đòn thường trúng hồi thêm máu định kỳ).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Hồi máu tức thì | 12.17% Max HP+1,172 | 21.9% Max HP+2,579 (cấp 13: 25.86% Max HP+3,223) |
| Eagleplume/đòn (2.5s/lần) | 2.43% Max HP+234 | 4.38% Max HP+515 (cấp 13: 5.17% Max HP+643) |

**Passive A1 — Suppressive Barrage:** Flowfrost/Rimestar Shard trúng nhiều địch cho stack Detector (+10% DMG Vật
lý khi tại sân, tối đa 3 stack).
**Passive A4 — Topographical Mapping:** nhân vật vừa có Eagleplume vừa có Soulwind bạo kích: +1 Detector, +1 giới
hạn stack.
**Utility Passive:** hiện tài nguyên đặc sản Mondstadt trên minimap.

### Cung mệnh
1. Soulwind giảm khoảng cách hồi máu của Eagleplume theo % tốc đánh tăng.
2. Flowfrost/Rimestar Flare trúng lần đầu: +1 Detector.
3. Tăng cấp Skyfeather Song +3.
4. Eagleplume hồi máu hồi 3 năng lượng (tối đa 5 lần/lượt Bùng nổ).
5. Tăng cấp Starfrost Swirl +3.
6. +1 giới hạn Detector; nhân vật có Soulwind +60% Tỉ lệ st bạo kích Vật lý.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ hồi máu + buff tốc đánh/Vật lý cho đội on-field, đặc biệt hợp đội Vật lý/Cryo
cần cả cứu sinh lẫn DPS phụ. Combo phổ biến: Mika + Eula/Diluc (buff Vật lý/tốc đánh).

---

## Noelle

**Nguyên tố:** Geo | **Vũ khí:** Đại kiếm | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (DEF phụ) |
|---|---|---|---|---|
| 1 | 1,012.09 | 16.03 | 66.95 | — |
| 90 | 12,071.16 | 191.16 | 798.55 | 30% |

### Bộ kỹ năng

**Đòn thường — Favonius Bladework - Maid:** tối đa 4 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 79.12% | 156.4% |
| 2-Hit | 73.36% | 145.01% |
| 3-Hit | 86.26% | 170.51% |
| 4-Hit | 113.43% | 224.23% |
| Đòn nặng lặp / cuối | 50.74% / 90.47% | 100.3% / 178.84% |
| Nhảy rơi/thấp/cao | 74.59% / 149.14% / 186.29% | 147.44% / 294.82% / 368.25% |

**Kỹ năng — Breastplate** (hồi chiêu 24s, thời lượng 12s): tạo khiên đá (theo DEF), Đòn thường/nặng trúng khi có
khiên có cơ hội hồi máu cả đội (theo DEF).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG | 120% DEF | 216% DEF (cấp 14: 270%) |
| Khiên hấp thụ | 160% DEF+769 | 288% DEF+1,693 (cấp 14: 360% DEF+2,271) |
| Hồi máu (cơ hội 50→60%) | 21.28% DEF+102 | 38.3% DEF+225 (cấp 14: 47.92% DEF+303) |

**Bùng nổ — Sweeping Time** (năng lượng 60, hồi chiêu 15s, thời lượng 15s): quét đá diện rộng, sau đó Đòn thường/
nặng/nhảy hoá Geo không ghi đè, AoE lớn hơn, +ATK theo DEF.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Burst DMG | 67.2% ATK | 120.96% ATK (cấp 14: 151%) |
| Skill DMG (đợt quét) | 92.8% ATK | 167.04% ATK (cấp 14: 209%) |
| ATK Bonus | 40% DEF | 72% DEF (cấp 14: 90%) |

**Passive A1 — Devotion:** Noelle không tại sân, nhân vật đang chiến đấu <30% HP: tự tạo khiên 400% DEF (20s, hiệu
quả x1.5, 60s/lần).
**Passive A4 — Nice and Clean:** mỗi 4 đòn Đòn thường/nặng trúng giảm 1s hồi chiêu Breastplate.
**Utility Passive:** món DEF nấu Hoàn Hảo 12% cơ hội x2.

### Cung mệnh
1. Sweeping Time+Breastplate cùng hiệu lực: cơ hội hồi máu Breastplate = 100%.
2. Giảm 20% tiêu hao thể lực Đòn nặng, +15% DMG Đòn nặng.
3. Tăng cấp Breastplate +3.
4. Breastplate hết hạn/bị phá: nổ 400% ATK DMG Geo diện rộng.
5. Tăng cấp Sweeping Time +3.
6. Sweeping Time +thêm 50% DEF vào ATK Bonus; hạ địch trong thời gian Bùng nổ +1s (tối đa 10s).

**Vai trò đội hình Trầm Thủy:** DPS on-field Vật lý/Geo theo DEF hiếm có, kiêm khiên + tự cứu cho cả đội — cực kỳ
tiết kiệm slot đội hình. Combo phổ biến: Noelle mono-DEF (Albedo/Gorou +DEF), hoặc Noelle làm khiên rẻ cho đội khác.

---

## Razor

**Nguyên tố:** Electro | **Vũ khí:** Đại kiếm | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Physical DMG Bonus |
|---|---|---|---|---|
| 1 | 1,002.97 | 19.59 | 62.95 | — |
| 90 | 11,962.41 | 233.64 | 750.77 | 30% |

### Bộ kỹ năng

**Đòn thường — Steel Fang:** tối đa 4 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 95.92% | 171.13% |
| 2-Hit | 82.63% | 147.42% |
| 3-Hit | 103.31% | 184.32% |
| 4-Hit | 136.05% | 242.72% |
| Đòn nặng lặp / cuối | 62.54% / 113.09% | 123.62% / 223.55% |
| Nhảy rơi/thấp/cao | 82.05% / 164.06% / 204.92% | 162.19% / 324.3% / 405.07% |

**Kỹ năng — Claw and Thunder** (hồi chiêu Nhấn 6s / Giữ 10s): Nhấn vung móng vuốt sấm, trúng cho 1 Electro Sigil
(tối đa 3, +Nguyên Tố Hồi); Giữ gây sát thương lớn diện rộng, tiêu hết Sigil hoá năng lượng.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Press DMG | 199.2% ATK | 358.56% ATK (cấp 14: 448%) |
| Hold DMG | 295.2% ATK | 531.36% ATK (cấp 14: 664%) |

**Bùng nổ — Lightning Fang** (năng lượng 80, hồi chiêu 20s, thời lượng 15s): triệu hồi Wolf Within đánh cùng Đòn
thường, tăng tốc đánh & kháng Electro, miễn nhiễm Electro-Charged, tắt Đòn nặng.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Elemental Burst DMG | 160% ATK | 288% ATK (cấp 14: 360%) |
| Soul Companion DMG | 24% DMG Đòn thường | 43.2% DMG Đòn thường (cấp 14: 54%) |
| Tốc đánh | +26% | +40% (từ cấp 10) |

**Passive A1 — Awakening:** giảm 18% hồi chiêu Claw and Thunder; Lightning Fang reset hồi chiêu Claw and Thunder.
**Passive A4 — Hunger:** Năng lượng <50%: +30% Nguyên Tố Hồi.
**Witch's Eve Rite Passive — Surge of Lightning (Hexerei):** đội có ≥2 Hexerei, Lightning Fang tăng thêm 70% ATK vào
DMG Wolf Within; khi Electro Sigil tràn trong lúc có Wolf Within, gọi sét lan rộng 150% ATK + hồi 7 năng lượng (1s/lần).
**Utility Passive:** giảm 20% tiêu hao thể lực chạy nước rút cho cả đội.

### Cung mệnh
1. Nhặt tinh cầu/hạt nguyên tố: +10% DMG (8s).
2. +10% Tỉ lệ st bạo kích lên địch <30% HP.
3. Tăng cấp Lightning Fang +3.
4. Nhấn Claw and Thunder trúng: -15% DEF địch (7s).
5. Tăng cấp Claw and Thunder +3.
6. Mỗi 10s, Đòn thường tiếp theo tự phóng sét = 100% ATK; ngoài Lightning Fang, sét trúng cho 1 Electro Sigil.

**Vai trò đội hình Trầm Thủy:** DPS on-field Electro/Vật lý bền bỉ, tự cấp năng lượng tốt. Combo phổ biến: Razor +
Fischl/Lisa (Electro-Charged/Aggravate), Razor + Bennett (buff ATK).

---

## Rosaria

**Nguyên tố:** Cryo | **Vũ khí:** Thương | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 06/04/2021

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (ATK phụ) |
|---|---|---|---|---|
| 1 | 1,030.32 | 20.12 | 59.51 | — |
| 90 | 12,288.65 | 240.01 | 709.82 | 24% |

### Bộ kỹ năng

**Đòn thường — Spear of the Church:** tối đa 5 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 52.46% | 103.7% |
| 2-Hit | 51.6% | 102% |
| 3-Hit (x2) | 31.82%×2 | 62.9%×2 |
| 4-Hit | 69.66% | 137.7% |
| 5-Hit (2 phần) | 41.62%+43% | 82.28%+85% |
| Đòn nặng | 136.74% | 270.3% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Ravaging Confession** (hồi chiêu 6s): dịch chuyển ra sau lưng địch, đâm + chém gây DMG Cryo (2 đòn).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG (2 đòn) | 58.4%+136% ATK | 105.12%+244.8% ATK (cấp 13: 124.1%+289%) |

**Bùng nổ — Rites of Termination** (năng lượng 60, hồi chiêu 15s, thời lượng 8s): chém quét diện rộng rồi tạo Ice
Lance đóng tại chỗ, định kỳ gây DMG Cryo lạnh.
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| Skill DMG (2 đòn) | 104%+152% ATK | 187.2%+273.6% ATK (cấp 14: 234%+342%) |
| Ice Lance DoT | 132% ATK | 237.6% ATK (cấp 14: 297%) |

**Passive A1 — Regina Probationum:** đánh sau lưng bằng Ravaging Confession: +12% Tỉ lệ st bạo kích (5s).
**Passive A4 — Shadow Samaritan:** dùng Bùng nổ: đồng đội (trừ Rosaria) +15% × Tỉ lệ st bạo kích Rosaria (10s, tối
đa +15%).
**Utility Passive:** ban đêm cả đội +10% tốc di chuyển.

### Cung mệnh
1. Bạo kích: +10% tốc đánh, +10% DMG Đòn thường (4s).
2. Ice Lance của Rites of Termination +4s thời lượng.
3. Tăng cấp Ravaging Confession +3.
4. Ravaging Confession bạo kích hồi 5 năng lượng (1 lần/lượt dùng).
5. Tăng cấp Rites of Termination +3.
6. Rites of Termination giảm 20% kháng Vật lý địch (10s).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ buff Tỉ lệ st bạo kích cho đội + DPS phụ Cryo giá rẻ. Combo phổ biến: Rosaria
+ bất kỳ DPS Vật lý/Cryo chính nào cần thêm crit rate.

---

## Sucrose

**Nguyên tố:** Anemo | **Vũ khí:** Pháp khí | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt | **Ngày ra mắt:** 28/09/2020

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Anemo DMG Bonus |
|---|---|---|---|---|
| 1 | 775.02 | 14.25 | 58.94 | — |
| 90 | 9,243.68 | 169.92 | 703.00 | 24% |

### Bộ kỹ năng

**Đòn thường — Wind Spirit Creation:** tối đa 4 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 33.46% | 60.24% |
| 2-Hit | 30.62% | 55.11% |
| 3-Hit | 38.45% | 69.21% |
| 4-Hit | 47.92% | 86.25% |
| Đòn nặng | 120.16% | 216.29% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Astable Anemohypostasis Creation - 6308** (hồi chiêu 15s): tạo Wind Spirit nhỏ hút địch/vật thể, hất
tung, gây DMG Anemo.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 211.2% ATK | 380.16% ATK (cấp 13: 448.8%) |

**Bùng nổ — Forbidden Creation - Isomer 75 / Type II** (năng lượng 80, hồi chiêu 20s, thời lượng 6s): Wind Spirit
lớn hút liên tục, hút nguyên tố Hydro/Pyro/Cryo/Electro để gây thêm DMG (3 đợt).
| Chỉ số | Cấp 1 | Cấp 10 (max 14) |
|---|---|---|
| DoT | 148% ATK | 266.4% ATK (cấp 14: 333%) |
| DMG nguyên tố hút thêm | 44% ATK | 79.2% ATK (cấp 14: 99%) |

**Passive A1 — Catalyst Conversion:** kích hoạt Xoáy/Stellar Xoáy: đồng đội cùng nguyên tố (trừ Sucrose) +50 Tinh
Thông Nguyên Tố (8s).
**Passive A4 — Mollis Favonius:** Kỹ năng/Bùng nổ trúng địch: đồng đội (trừ Sucrose) +20% Tinh Thông Nguyên Tố của
Sucrose (8s).
**Witch's Eve Rite Passive — Sevenfold Transmutation (Hexerei):** đội có ≥2 Hexerei, tạo Wind Spirit nhỏ: đồng đội
+5.71% DMG mọi loại (15s); tạo Wind Spirit lớn: đồng đội Hexerei +7.14% DMG (20s).
**Utility Passive:** 10% cơ hội x2 khi chế nguyên liệu tăng cấp.

### Cung mệnh
1. Astable Anemohypostasis Creation +1 charge.
2. Forbidden Creation +2s thời lượng.
3. Tăng cấp Astable Anemohypostasis Creation +3.
4. Mỗi 7 Đòn thường/nặng giảm 1-7s hồi chiêu Astable Anemohypostasis Creation.
5. Tăng cấp Forbidden Creation +3.
6. Forbidden Creation hút nguyên tố: cả đội +20% DMG nguyên tố đó trong thời gian hiệu lực.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ gom địch + buff Tinh Thông Nguyên Tố hàng đầu cho đội phản ứng (Xoáy/Bloom/
Electro-Charged). Combo phổ biến: Sucrose + bất kỳ đội cần Xoáy lan rộng và EM cao.

---

## Prune

**Nguyên tố:** Anemo | **Vũ khí:** Pháp khí | **Độ hiếm:** 4★ | **Quốc gia:** Mondstadt (trong game; Nod-Krai trong cốt truyện) | **Ngày ra mắt:** 20/05/2026 (Luna VII)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số đột phá (ATK phụ) |
|---|---|---|---|---|
| 1 | 811.49 | 18.52 | 48.64 | — |
| 90 | 9,678.67 | 220.89 | 580.14 | 24% |

### Bộ kỹ năng

**Đòn thường — Badaboom! Hexbuster Hammer:** tối đa 3 đòn búa.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 48.62% | 87.52% |
| 2-Hit | 48.28% | 86.91% |
| 3-Hit | 67.98% | 122.36% |
| Đòn nặng | 133.52% | 240.34% |
| Nhảy rơi/thấp/cao | 56.83% / 113.63% / 141.93% | 112.34% / 224.62% / 280.57% |

**Kỹ năng — Ring-A-Ding-Ding! Hexhunter Chime** (hồi chiêu 15s): đánh chuông Witchlure Bell gây DMG Anemo; nếu Xoáy
kích hoạt, 6s tiếp theo Kỹ năng hoá **Clang Clang! Witch-tribution Comes!** (búa hoá nguyên tố Xoáy, đá búa về phía
trước gây DMG nguyên tố đó).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Ring-A-Ding-Ding! DMG | 167.44% ATK | 301.39% ATK (cấp 13: 355.81%) |
| Clang Clang! DMG | 204.56% ATK | 368.21% ATK (cấp 13: 434.69%) |

**Bùng nổ — The Bell Tolls! The Hunt Is On!** (năng lượng 70, hồi chiêu 18s): rung chuông gây DMG Anemo, sau đó vào
chế độ Hunter-Seeker (chuông tự bay theo tấn công định kỳ, tối đa 6 lượt/12s).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 96.96% ATK | 174.53% ATK (cấp 13: 206.04%) |
| Witchlure Bell DMG/lượt | 70.44% ATK | 126.79% ATK (cấp 13: 149.69%) |

**Passive A1 — Verdict and Punishment:** trong chế độ Hunter-Seeker, Witchlure Bell trúng kích hoạt Xoáy: triệu hồi
Banehunter Oathhammer đánh 150% ATK nguyên tố tương ứng.
**Passive A4 — Tolling Synchronicity:** búa hoá nguyên tố trúng địch: đồng đội quanh +DMG theo phần ATK Prune vượt
2,000 (0.025%/điểm, tối đa 50%, 5s).
**Witch's Eve Rite Passive — Witchseeker's Vow (Hexerei):** đội có ≥2 Hexerei, nhân vật Hexerei dính Tolling Rally
kích hoạt phản ứng: Prune +60% ATK (5s); nếu là Xoáy, người kích hoạt +30% ATK (5s).
**Utility Passive:** 10% cơ hội nhận thêm 1 nguyên liệu tài năng khi chế tạo.

### Cung mệnh
1. Búa hoá nguyên tố trúng địch: hồi 2 năng lượng (1.8s/lần).
2. Trong Hunter-Seeker: +10% ATK, mỗi lần chuông/búa trúng +5% ATK (tối đa +40%).
3. Tăng cấp The Bell Tolls! The Hunt Is On! +3.
4. Búa hoá nguyên tố trúng địch: nảy sang địch khác gây 80% ATK nguyên tố tương ứng.
5. Tăng cấp Ring-A-Ding-Ding! Hexhunter Chime +3.
6. Hunter-Seeker +4s thời lượng; đồng đội dính Tolling Rally kích hoạt phản ứng: +350 ATK (5s).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ off-field Anemo chuyển đổi nguyên tố qua Xoáy, buff ATK toàn đội dựa trên
ATK cao của chính Prune. Combo phổ biến: Prune + Varka (Hexerei, cùng cần Xoáy), Prune + đội Xoáy đa nguyên tố.

---

# Nod-Krai

Cơ chế đặc trưng của các nhân vật Nod-Krai: **Moonsign** (chỉ số phe đội — tăng khi có nhân vật Nod-Krai trong đội,
mở khoá buff ở các mốc Nascent/Ascendant Gleam) và phản ứng **Lunar** (Lunar-Charged/Lunar-Bloom/Lunar-Crystallize —
biến thể "mặt trăng" của Electro-Charged/Bloom/Hydro-Crystallize, do các nhân vật Nod-Krai chuyển đổi).

## Ineffa

**Nguyên tố:** Electro | **Vũ khí:** Thương | **Độ hiếm:** 5★ | **Quốc gia:** Nod-Krai (trong game; Natlan trong cốt truyện) | **Ngày ra mắt:** 30/07/2025 (bản 5.8)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 981.92 | 25.70 | 64.44 | — |
| 90 | 12,613.29 | 330.07 | 827.73 | 19.2% |

### Bộ kỹ năng

**Đòn thường — Cyclonic Duster:** tối đa 4 đòn thương.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 34.84% | 68.86% |
| 2-Hit | 34.22% | 67.65% |
| 3-Hit (x2) | 22.76%×2 | 44.98%×2 |
| 4-Hit | 56.07% | 110.83% |
| Đòn nặng | 94.94% | 187.68% |
| Nhảy rơi/thấp/cao | 63.93% / 127.84% / 159.68% | 126.38% / 252.7% / 315.64% |

**Kỹ năng — Cleaning Mode: Carrier Frequency** (hồi chiêu 16s): gây DMG Electro diện rộng, tạo khiên (hiệu quả
x2.5 Electro) và triệu hồi Birgitta đánh phối hợp liên tục (2s/lần).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 86.4% ATK | 155.52% ATK (cấp 13: 183.6%) |
| Khiên hấp thụ | 221.18% ATK+1,387 | 398.13% ATK+3,051 (cấp 13: 470.02% ATK+3,814) |
| Birgitta Discharge DMG | 96% ATK | 172.8% ATK (cấp 13: 204%) |

**Bùng nổ — Supreme Instruction: Cyclonic Exterminator** (năng lượng 60, hồi chiêu 15s): bắn Birgitta gây DMG
Electro diện rộng, Birgitta ở lại sân (dùng lại làm mới thời gian).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 676.8% ATK | 1,218.24% ATK (cấp 13: 1,438.2%) |

**Passive A1 — Overclocking Circuit:** có mây sấm Lunar-Charged gần đó, Birgitta thêm 1 đòn = 65% ATK Lunar-Charged.
**Passive A4 — Panoramic Permutation Protocol:** dùng Bùng nổ: cả đội +6% ATK Ineffa thành Tinh Thông Nguyên Tố (20s).
**Moonsign Benediction Passive — Assemblage Hub:** đồng đội kích hoạt Electro-Charged hoá Lunar-Charged, mỗi 100 ATK
Ineffa +0.7% Base DMG Lunar-Charged (tối đa 14%); Ineffa trong đội +1 cấp Moonsign.
**Utility Passive:** 30% cơ hội nhận gia vị khi dùng món ăn.

### Cung mệnh
1. Kích hoạt khiên: đồng đội quanh +2.5%/100 ATK DMG Lunar-Charged (tối đa 50%, 20s).
2. Bùng nổ trúng: phú Punishment Edict lên 1 địch, sau trễ hoặc bị đánh gây 300% ATK Lunar-Charged diện rộng; Bùng
   nổ cũng tạo khiên cho đồng đội.
3. Tăng cấp Cleaning Mode: Carrier Frequency +3 (tối đa 15).
4. Đồng đội kích hoạt Lunar-Charged: hồi 5 năng lượng (4s/lần).
5. Tăng cấp Supreme Instruction: Cyclonic Exterminator +3 (tối đa 15).
6. Khi có hiệu ứng Carrier Flow Composite (C1): Ineffa gây 135% ATK Lunar-Charged diện rộng sau khi mây sấm đánh
   (3.5s/lần).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ khiên + khởi phát Lunar-Charged, gần như bắt buộc trong đội Lunar-Charged
(Hydro + Electro biến hoá). Combo phổ biến: Ineffa + Flins + 1 Hydro (Xingqiu/Yelan/Columbina) cho vòng lặp
Lunar-Charged liên tục.

---

## Flins

**Nguyên tố:** Electro | **Vũ khí:** Thương | **Độ hiếm:** 5★ | **Quốc gia:** Nod-Krai (trong game; Snezhnaya trong cốt truyện) | **Ngày ra mắt:** 30/09/2025 (Luna I)

Cơ chế biến hình: dùng Kỹ năng vào **Manifest Flame** (Đòn thường/nặng hoá Electro không ghi đè, không nhảy được),
trong đó Kỹ năng đổi thành **Northland Spearstorm** (AoE, hồi chiêu riêng 6s) và trong 6s sau đó Bùng nổ đổi thành
**Thunderous Symphony** (tốn ít năng lượng hơn).

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | CRIT DMG |
|---|---|---|---|---|
| 1 | 972.39 | 27.37 | 62.94 | — |
| 90 | 12,490.83 | 351.59 | 808.52 | 38.4% |

### Bộ kỹ năng

**Đòn thường — Pocztowy Demonspear:** tối đa 5 đòn thương (giữ nguyên khi ở Manifest Flame).
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 44.73% | 88.41% |
| 2-Hit | 45.15% | 89.25% |
| 3-Hit | 55.92% | 110.54% |
| 4-Hit (x2) | 32.04%×2 | 63.33%×2 |
| 5-Hit | 76.79% | 151.8% |
| Đòn nặng | 103.03% | 203.66% |
| Nhảy rơi | 63.93% | 126.38% |

**Kỹ năng — Ancient Rite: Arcane Light** (hồi chiêu 16s): vào Manifest Flame (10s). Trong đó, Kỹ năng đổi thành
**Northland Spearstorm** (hồi chiêu riêng 6s, không đổi theo hiệu ứng khác): quét thương AoE, 6s tiếp theo Bùng nổ
đổi thành Thunderous Symphony.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Northland Spearstorm DMG | 178.4% ATK | 321.12% ATK (cấp 13: 379.1%) |

**Bùng nổ — Ancient Ritual: Cometh the Night** (năng lượng 80, hồi chiêu 20s): gây DMG Electro tức thì, sau đó 2 đòn
DMG Lunar-Charged giai đoạn giữa + 1 đòn giai đoạn cuối (mạnh hơn).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Initial Skill DMG | 259.84% ATK | 467.71% ATK (cấp 13: 552.16%) |
| Middle Phase (×2) | 16.24% ATK | 29.23% ATK (cấp 13: 34.51%) |
| Final Phase | 116.93% ATK | 210.47% ATK (cấp 13: 248.47%) |
| Thunderous Symphony (30 năng lượng) | 71.46% ATK | 128.62% ATK (cấp 13: 151.84%) |
| Thunderous Symphony phụ (Moonsign Ascendant) | 103.94% ATK | 187.08% ATK (cấp 13: 220.86%) |

**Passive A1 — Symphony of Winter:** Moonsign Ascendant Gleam: Lunar-Charged của Flins +20% DMG.
**Passive A4 — Whispering Flame:** +8% ATK thành Tinh Thông Nguyên Tố (tối đa 160).
**Moonsign Benediction Passive — Old World Secrets:** đồng đội kích hoạt Electro-Charged hoá Lunar-Charged, mỗi 100
ATK Flins +0.7% Base DMG (tối đa 14%); Flins trong đội +1 cấp Moonsign.
**Utility Passive:** hiện tài nguyên đặc sản Nod-Krai trên minimap.

### Cung mệnh
1. Northland Spearstorm giảm hồi chiêu còn 4s; đồng đội kích hoạt Lunar-Charged hồi 8 năng lượng (5.5s/lần).
2. 6s sau Northland Spearstorm, Đòn thường tiếp theo +50% ATK Lunar-Charged diện rộng; Moonsign Ascendant Gleam:
   Electro trúng của Flins -25% kháng Electro địch (7s).
3. Tăng cấp Ancient Ritual: Cometh the Night +3.
4. +20% ATK; Whispering Flame nâng lên +10% ATK thành EM (tối đa 220).
5. Tăng cấp Ancient Rite: Arcane Light +3.
6. Lunar-Charged của Flins +35% DMG; Moonsign Ascendant Gleam: đồng đội quanh +10% DMG Lunar-Charged.

**Vai trò đội hình Trầm Thủy:** DPS on-field Electro dồn sát thương Lunar-Charged trực tiếp, cặp bài trùng với
Ineffa. Combo phổ biến: Flins + Ineffa + Hydro support (Xingqiu/Yelan/Columbina) cho đội Lunar-Charged mạnh nhất.

---

## Columbina

**Nguyên tố:** Hydro | **Vũ khí:** Pháp khí | **Độ hiếm:** 5★ | **Quốc gia:** Nod-Krai (trong game; Snezhnaya trong cốt truyện) | **Ngày ra mắt:** 14/01/2026 (Luna IV)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 1,143.98 | 7.45 | 40.09 | — |
| 90 | 14,695.09 | 95.67 | 514.93 | 19.2% |

### Bộ kỹ năng

**Đòn thường — Moondew Cascade:** tối đa 3 đòn nước; Đòn nặng có thể hoá **Moondew Cleanse** (3 đòn Dendro
Lunar-Bloom) khi có Verdant Dew.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 46.79% ATK | 84.23% ATK |
| 2-Hit | 36.63% ATK | 65.93% ATK |
| 3-Hit | 58.48% ATK | 105.27% ATK |
| Đòn nặng | 116.08% ATK | 208.94% ATK |
| Moondew Cleanse (×3) | 1.51% Max HP | 2.72% Max HP |
| Nhảy | 56.83% ATK | 112.34% ATK |

**Kỹ năng — Eternal Tides** (hồi chiêu 17s): gây DMG Hydro AoE, tạo Gravity Ripple theo dõi nhân vật đang chiến
đấu, gây DMG Hydro liên tục; tích Gravity khi đồng đội kích hoạt/gây DMG phản ứng Lunar; đủ Gravity (60) kích hoạt
**Gravity Interference** tuỳ loại Lunar tích nhiều nhất (Lunar-Charged: DMG Electro; Lunar-Bloom: 5 Moondew Sigil
DMG Dendro; Lunar-Crystallize: DMG Geo), tối đa 1 lần/6s.
| Chỉ số (theo Max HP) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 16.72% | 30.1% (cấp 13: 35.53%) |
| Gravity Ripple DoT | 9.36% | 16.85% (cấp 13: 19.89%) |
| Gravity Interference (Lunar-Charged) | 4.7% | 8.47% (cấp 13: 10%) |
| Gravity Interference (Lunar-Bloom, ×5) | 1.41% | 2.53% (cấp 13: 2.99%) |
| Gravity Interference (Lunar-Crystallize) | 8.82% | 15.88% (cấp 13: 18.75%) |

**Bùng nổ — Moonlit Melancholy** (năng lượng 60, hồi chiêu 15s): tạo Lunar Domain gây DMG Hydu tức thì, tăng DMG các
loại phản ứng Lunar cho nhân vật trong vùng (20s).
| Chỉ số (theo Max HP) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 32.24% | 58.03% (cấp 13: 68.51%) |
| Lunar Reaction DMG Bonus | 13% | 40% (cấp 13: 49%) |

**Passive A1 — Lunacy's Lure:** Gravity Interference kích hoạt: +5% Tỉ lệ st bạo kích (10s, tối đa 3 stack).
**Passive A4 — Law of the New Moon:** trong Lunar Domain, tuỳ loại Lunar kích hoạt mà cho hiệu ứng khác nhau
(Lunar-Charged: 33% cơ hội sét đánh thêm; Lunar-Bloom: tạo Moondrift Dew; Lunar-Crystallize: 33% Moondrift đánh thêm).
**Moonsign Benediction Passive — Moonlight, Lent Unto You:** đồng đội kích hoạt Electro-Charged/Bloom/Hydro-
Crystallize hoá Lunar tương ứng; mỗi 1,000 Max HP Columbina +0.2% Base DMG Lunar (tối đa 7%); Columbina trong đội
+1 cấp Moonsign.
**Utility Passive — Lunar Vigil:** đồng đội gục trong Nod-Krai/Frost Moon: Columbina tự hồi sinh họ (100s/lần, không
hoạt động trong Trầm Thủy).

### Cung mệnh
1. Kỹ năng tự kích hoạt Gravity Interference (15s/lần); Moonsign Ascendant Gleam: hiệu ứng khác theo loại Lunar tích
   nhiều nhất; đồng đội quanh +1.5% DMG Lunar.
2. +34% tốc tích Gravity; Gravity Interference cho Lunar Brilliance (+40% Max HP 8s); đồng đội +7% DMG Lunar.
3. Tăng cấp Eternal Tides +3; +1.5% DMG Lunar cho đội.
4. Gravity Interference hồi 4 năng lượng; DMG Gravity Interference +12.5%/2.5%/12.5% Max HP tuỳ loại; +1.5% DMG Lunar.
5. Tăng cấp Moonlit Melancholy +3; +1.5% DMG Lunar cho đội.
6. Trong Lunar Domain, phản ứng Lunar: +80% Tỉ lệ st bạo kích DMG nguyên tố liên quan (8s); +7% DMG Lunar cho đội.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ/DPS off-field trung tâm cho mọi đội Lunar (Lunar-Charged/Bloom/Crystallize),
buff DMG Lunar toàn đội cực mạnh qua cung mệnh. Combo phổ biến: Columbina + Ineffa/Flins (Lunar-Charged), Columbina
+ Lauma/Nefer (Lunar-Bloom), Columbina + Linnea (Lunar-Crystallize).

---

## Linnea

**Nguyên tố:** Geo | **Vũ khí:** Cung | **Độ hiếm:** 5★ | **Quốc gia:** Nod-Krai (trong game; Snezhnaya trong cốt truyện) | **Ngày ra mắt:** 08/04/2026 (Luna VI)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ st bạo kích |
|---|---|---|---|---|
| 1 | 770.28 | 11.17 | 70.60 | — |
| 90 | 9,894.70 | 143.51 | 906.89 | 19.2% |

### Bộ kỹ năng

**Đòn thường — Capture Protocol:** tối đa 3 đòn cung.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 59% ATK | 116.62% ATK |
| 2-Hit | 51.15% ATK | 101.11% ATK |
| 3-Hit | 81.63% ATK | 161.36% ATK |
| Ngắm bắn thường/full | 43.86% / 124% ATK | 86.7% / 223.2% ATK |
| Nhảy | 56.83% ATK | 112.34% ATK |

**Kỹ năng — Countermeasure: Lumi's Battle Cry!** (hồi chiêu 18s): Nhấn triệu hồi Lumi ở Super Power Form (Pound-
Pound Pummeler, gấp đôi đòn nếu có Moondrift); Bấm liên tục 5 lần trong thời gian ngắn cho Lumi chuyển Ultimate
Power Form dùng **Million Ton Crush** (Lunar-Crystallize AoE mạnh) rồi về Standard Power Form.
| Chỉ số (theo DEF) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Pound-Pound Pummeler (×2) | 96% | 172.8% (cấp 13: 204%) |
| Heavy Overdrive Hammer | 100% | 180% (cấp 13: 212.5%) |
| Million Ton Crush | 400% | 720% (cấp 13: 850%) |

**Bùng nổ — Memo: Survival Guide in Extreme Conditions** (năng lượng 60, hồi chiêu 15s): triệu hồi Lumi ở Super
Power Form để hồi máu cả đội (theo DEF Linnea), làm mới thời gian Lumi nếu đã có.
| Chỉ số (theo DEF) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Hồi máu tức thì | 160% DEF+770 | 288% DEF+1,695 (cấp 13: 340% DEF+2,119) |
| Hồi máu liên tục | 32% DEF+154 | 57.6% DEF+339 (cấp 13: 68% DEF+424) |

**Passive A1 — Field Observation Notes:** Lumi tại sân: địch quanh -15% kháng Geo (Moonsign Ascendant Gleam: thêm
-15%).
**Passive A4 — Universal Naturalist Archive:** nhân vật đang chiến đấu là Moonsign thì +5% DEF Linnea thành EM cho
họ; nếu không phải Moonsign thì Linnea tự tăng EM.
**Moonsign Benediction Passive — Habitat Survey:** đồng đội kích hoạt Hydro-Crystallize hoá Lunar-Crystallize; mỗi
100 DEF Linnea +0.7% Base DMG (tối đa 14%); Linnea trong đội +1 cấp Moonsign.
**Utility Passive — Master Adventurer:** ngoài chiến đấu, Ngắm bắn hoá mũi tên dò tài nguyên/khoáng vật đặc biệt.

### Cung mệnh
1. Kỹ năng/Moondrift Harmony cho 6 stack Field Catalog (tối đa 18); đồng đội gây DMG Lunar-Crystallize tiêu 1 stack
   +75% DEF DMG; Million Ton Crush tiêu tối đa 5 stack, mỗi stack +150% DEF DMG.
2. 8s sau Moondrift Harmony: đồng đội Hydro/Geo +40% Tỉ lệ st bạo kích; Million Ton Crush +150% Tỉ lệ st bạo kích.
3. Tăng cấp Countermeasure: Lumi's Battle Cry! +3.
4. 5s sau Moondrift Harmony: Linnea và nhân vật đang chiến đấu +25% DEF (cộng dồn khi Linnea tại sân).
5. Tăng cấp Memo: Survival Guide in Extreme Conditions +3.
6. Kỹ năng/Moondrift Harmony cho tối đa Field Catalog ngay; tiêu gấp đôi số stack nhưng DMG tăng 150%; Moonsign
   Ascendant Gleam: đồng đội +25% DMG Lunar-Crystallize.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ off-field Geo/hồi máu, trung tâm đội Lunar-Crystallize (Hydro-Crystallize).
Combo phổ biến: Linnea + Columbina (Lunar-Crystallize), Linnea + Noelle/Zhongli (Geo Crystallize khiên).

---

## Nefer

**Nguyên tố:** Dendro | **Vũ khí:** Pháp khí | **Độ hiếm:** 5★ | **Quốc gia:** Nod-Krai (trong game; Sumeru trong cốt truyện) | **Ngày ra mắt:** 22/10/2025 (Luna II)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số phụ |
|---|---|---|---|---|
| 1 | 988.97 | 26.81 | 62.22 | EM cơ bản 100, CRIT DMG — |
| 90 | 12,703.91 | 344.42 | 799.30 | EM cơ bản 100, CRIT DMG 38.4% |

### Bộ kỹ năng

**Đòn thường — Striking Serpent:** tối đa 4 đòn (đá).
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 38.07% ATK | 68.53% ATK |
| 2-Hit | 37.56% ATK | 67.62% ATK |
| 3-Hit (x2) | 25.24%×2 ATK | 45.43%×2 ATK |
| 4-Hit | 60.99% ATK | 109.79% ATK |
| Đòn nặng (Slither) | 130.88% ATK | 235.58% ATK |
| Nhảy | 56.83% ATK | 112.34% ATK |

**Kỹ năng — Senet Strategy: Dance of a Thousand Nights** (hồi chiêu 9s, 2 charge): xông lên gây DMG Dendro, vào
**Shadow Dance**; nếu có Verdant Dew, Đòn nặng hoá **Phantasm Performance** (Nefer + bóng đánh phối hợp, không tốn
thể lực).
| Chỉ số (ATK + EM) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 76.38%+152.77% | 137.49%+274.98% (cấp 13: 162.32%+324.63%) |
| Phantasm 1-Hit (Nefer) | 24.64%+49.28% | 44.35%+88.7% (cấp 13: 52.36%+104.72%) |
| Phantasm 2-Hit (Nefer) | 32.03%+64.06% | 57.66%+115.32% (cấp 13: 68.07%+136.14%) |
| Phantasm bóng (%EM, ×3 đòn) | 96% / 96% / 128% | 172.8% / 172.8% / 230.4% (cấp 13: 204/204/272%) |

**Bùng nổ — Sacred Vow: True Eye's Phantasm** (năng lượng 60, hồi chiêu 15s): gây DMG Dendro AoE, tiêu hết Veil of
Falsehood để tăng DMG.
| Chỉ số (ATK+EM) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| 1-Hit | 224.64%+449.28% | 404.35%+808.7% (cấp 13: 477.36%+954.72%) |
| 2-Hit | 336.96%+673.92% | 606.53%+1,213.05% (cấp 13: ~716%+1,432%) |

**Passive A1 — A Wager of Moonlight:** Moonsign Ascendant Gleam: Kỹ năng biến Dendro Core thành Seeds of Deceit;
Đòn nặng/Phantasm Performance hấp thụ Seeds cho Veil of Falsehood (tối đa 3, đủ 3 +100 EM 8s).
**Passive A4 — Daughter of the Dust and Sand:** trong Shadow Dance, Lunar-Bloom kích hoạt gần đó tăng Verdant Dew
nhận từ Slither (theo EM vượt 500, tối đa +50%).
**Moonsign Benediction Passive — Dusklit Eaves:** đồng đội kích hoạt Bloom hoá Lunar-Bloom; mỗi điểm EM Nefer
+0.0175% Base DMG (tối đa 14%); Nefer trong đội +1 cấp Moonsign.
**Utility Passive:** +25% phần thưởng thám hiểm Nod-Krai (20h).

### Cung mệnh
1. Base DMG Lunar-Bloom của Phantasm Performance +60% EM (cộng dồn với Veil of Falsehood).
2. Veil of Falsehood +5s thời lượng, tối đa 5 stack, Phantasm Performance +140% DMG gốc; dùng Kỹ năng nhận ngay 2
   stack; đủ 5 stack +200 EM thay vì 100.
3. Tăng cấp Senet Strategy: Dance of a Thousand Nights +3.
4. Trong Shadow Dance: +25% tốc nhận Verdant Dew; địch quanh -20% kháng Dendro (mất sau 4.5s khi rời/ra khỏi state).
5. Tăng cấp Sacred Vow: True Eye's Phantasm +3.
6. Phantasm Performance đòn 2 hoá 85% EM DMG Dendro AoE, thêm 1 đòn cuối 120% EM; Moonsign Ascendant Gleam: +15%
   DMG Lunar-Bloom.

**Vai trò đội hình Trầm Thủy:** DPS on-field Dendro EM-scale, tự cung Lunar-Bloom liên tục. Combo phổ biến: Nefer +
Lauma/Columbina (Lunar-Bloom), Nefer + nguồn Hydro/Electro ổn định để duy trì Bloom Core.

---

## Aino

**Nguyên tố:** Hydro | **Vũ khí:** Đại kiếm | **Độ hiếm:** 4★ | **Quốc gia:** Nod-Krai | **Ngày ra mắt:** 10/09/2025 (Luna I)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tinh Thông Nguyên Tố |
|---|---|---|---|---|
| 1 | 939.14 | 20.30 | 50.93 | — |
| 90 | 11,201.16 | 242.13 | 607.44 | 96 |

### Bộ kỹ năng

**Đòn thường — Bish-Bash-Bosh Repair:** tối đa 3 đòn; Đòn nặng quay liên tục rồi chém mạnh.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 66.5% ATK | 131.45% ATK |
| 2-Hit | 66.19% ATK | 130.84% ATK |
| 3-Hit (x2) | 49.22%×2 ATK | 97.29%×2 ATK |
| Đòn nặng lặp / cuối | 62.52% / 113.09% ATK | 123.59% / 223.55% ATK |
| Nhảy | 74.59% ATK | 147.44% ATK |

**Kỹ năng — Musecatcher** (hồi chiêu 10s): ném Musecatcher kéo Aino lại gần gây DMG Hydro, dừng lại gây thêm DMG
AoE Hydro; có thể Giữ để ngắm hướng ném.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Stage 1 DMG | 65.6% ATK | 118.08% ATK (cấp 13: 139.4%) |
| Stage 2 DMG | 188.8% ATK | 339.84% ATK (cấp 13: 401.2%) |

**Bùng nổ — Precision Hydronic Cooler** (năng lượng 50, hồi chiêu 13.5s, thời lượng 14s): triển khai thiết bị bắn
bóng nước định kỳ gây DMG Hydu.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Water Ball DMG | 20.11% ATK | 36.2% ATK (cấp 13: 42.74%) |

**Passive A1 — Modular Efficiency Protocol:** Moonsign Ascendant Gleam: Bùng nổ bắn nhanh hơn, AoE rộng hơn.
**Passive A4 — Structured Power Booster:** +DMG Bùng nổ = 50% EM.
**Moonsign Benediction Passive — Force Limit Analysis:** Aino trong đội +1 cấp Moonsign.
**Utility Passive:** hiện tài nguyên đặc sản Nod-Krai trên minimap.

### Cung mệnh
1. Dùng Kỹ năng/Bùng nổ: +80 EM cho Aino, +80 EM cho đồng đội quanh (15s, không chồng).
2. Aino không tại sân khi Bùng nổ còn hiệu lực: đồng đội đánh trúng địch, thiết bị bắn thêm 1 bóng = 25% ATK+100% EM
   Aino (5s/lần).
3. Tăng cấp Precision Hydronic Cooler +3.
4. Kỹ năng trúng địch hồi 10 năng lượng (10s/lần).
5. Tăng cấp Musecatcher +3.
6. 15s sau Bùng nổ: phản ứng Electro-Charged/Bloom/Lunar liên quan +15% DMG (Moonsign Ascendant Gleam: +20% nữa).

**Vai trò đội hình Trầm Thủy:** DPS off-field Hydro ổn định, dễ dùng cho mọi đội cần nguồn Hydro liên tục. Combo phổ
biến: Aino + Ineffa (mẹ con, cùng buff Moonsign), Aino + DPS Electro/Pyro/Cryo bất kỳ.

---

## Lauma

**Nguyên tố:** Dendro | **Vũ khí:** Pháp khí | **Độ hiếm:** 5★ | **Quốc gia:** Nod-Krai | **Ngày ra mắt:** 10/09/2025 (Luna I)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Chỉ số phụ |
|---|---|---|---|---|
| 1 | 829.39 | 19.85 | 52.05 | EM cơ bản 200, EM phụ — |
| 90 | 10,653.94 | 254.96 | 668.64 | EM cơ bản 200, EM phụ 115.2 |

### Bộ kỹ năng

**Đòn thường — Peregrination of Linnunrata:** tối đa 3 đòn; Đòn nặng vào Spirit Envoy (chạy tốc độ cố định 10s, có
thể nhảy 2 lần), thoát ra thì Đòn nặng hoá **Spiritcall Prayer** (AoE, hồi chiêu riêng 4s).
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 33.7% ATK | 60.66% ATK |
| 2-Hit | 31.8% ATK | 57.25% ATK |
| 3-Hit | 44.5% ATK | 80.09% ATK |
| Spiritcall Prayer | 129.04% ATK | 232.27% ATK |
| Nhảy | 56.83% ATK | 112.34% ATK |

**Kỹ năng — Runo: Dawnless Rest of Karsikko** (hồi chiêu 12s): Nhấn tạo Frostgrove Sanctuary (theo dõi, DMG Dendro
liên tục, giảm kháng Dendro/Hydro địch); Giữ (cần ≥1 Verdant Dew) tiêu hết Dew gây 1 đòn DMG thường + 1 đòn
Lunar-Bloom, mỗi Dew tiêu cho 1 stack Moon Song.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Press DMG | 121.6% ATK | 218.88% ATK (cấp 13: 258.4%) |
| Hold 1-Hit | 158.08% ATK | 284.54% ATK (cấp 13: 335.92%) |
| Hold 2-Hit (mỗi Dew) | 152% EM | 273.6% EM (cấp 13: 323% EM) |
| Frostgrove Sanctuary DMG | 96% ATK+192% EM | 172.8% ATK+345.6% EM (cấp 13: 204% ATK+408% EM) |

**Bùng nổ — Runo: All Hearts Become the Beating Moon** (năng lượng 60, hồi chiêu 15s): ban 18 stack Pale Hymn (tăng
DMG Bloom/Hyperbloom/Burgeon/Lunar-Bloom của đội); nếu có Moon Song, tiêu hết đổi thành 6 Pale Hymn/stack.
| Chỉ số (%EM) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Bloom/Hyperbloom/Burgeon DMG Bonus | 277.76% | 499.97% (cấp 13: 590.24%) |
| Lunar-Bloom DMG Bonus | 222.24% | 400.03% (cấp 13: 472.26%) |

**Passive A1 — Light for the Frosty Night:** 20s sau Kỹ năng, buff theo Moonsign (Nascent Gleam: Bloom/Hyperbloom/
Burgeon có thể bạo kích 15%/100%; Ascendant Gleam: Lunar-Bloom +10% Tỉ lệ st bạo kích/+20% CRIT DMG).
**Passive A4 — Cleansing for the Spring:** mỗi điểm EM: +0.04% DMG Kỹ năng (tối đa 32%), -0.02% hồi chiêu Đòn nặng
Spirit Envoy (tối đa 20%).
**Moonsign Benediction Passive — Nature's Chorus:** đồng đội kích hoạt Bloom hoá Lunar-Bloom; mỗi điểm EM +0.0175%
Base DMG (tối đa 14%); Lauma trong đội +1 cấp Moonsign.
**Utility Passive:** hiện tài nguyên đặc sản Nod-Krai trên minimap.

### Cung mệnh
1. Sau Kỹ năng/Bùng nổ, 20s: đồng đội kích hoạt Lunar-Bloom hồi 500% EM HP cho nhân vật đang chiến đấu (1.9s/lần);
   Spirit Envoy -40% tiêu thể lực, +5s thời lượng.
2. Bùng nổ tăng thêm: Bloom/Hyperbloom/Burgeon +500% EM, Lunar-Bloom +400% EM; Moonsign Ascendant Gleam: +40% DMG
   Lunar-Bloom cho đội.
3. Tăng cấp Runo: All Hearts Become the Beating Moon +3.
4. Frostgrove Sanctuary trúng địch hồi 4 năng lượng (5s/lần).
5. Tăng cấp Runo: Dawnless Rest of Karsikko +3.
6. Frostgrove Sanctuary thêm 1 đòn = 185% EM Lunar-Bloom (tối đa 8 lần/lượt, cho 2 Pale Hymn); Đòn thường tiêu 1
   Pale Hymn đổi 150% EM Lunar-Bloom; Moonsign Ascendant Gleam: +25% DMG Lunar-Bloom cho đội.

**Vai trò đội hình Trầm Thủy:** Hỗ trợ trung tâm đội Bloom/Lunar-Bloom, buff DMG phản ứng cực lớn theo EM. Combo phổ
biến: Lauma + Nefer/Columbina (Lunar-Bloom), Lauma + Nahida/Dendro core-Hyperbloom.

---

## Illuga

**Nguyên tố:** Geo | **Vũ khí:** Thương | **Độ hiếm:** 4★ | **Quốc gia:** Nod-Krai | **Ngày ra mắt:** 03/02/2026 (Luna IV)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tinh Thông Nguyên Tố |
|---|---|---|---|---|
| 1 | 1,002.97 | 16.03 | 68.21 | — |
| 90 | 11,962.41 | 191.16 | 813.57 | 96 |

### Bộ kỹ năng

**Đòn thường — Oathkeeper's Spear:** tối đa 4 đòn.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 47.37% ATK | 93.63% ATK |
| 2-Hit | 48.53% ATK | 95.92% ATK |
| 3-Hit (x2) | 31.43%×2 ATK | 62.13%×2 ATK |
| 4-Hit | 76.28% ATK | 150.78% ATK |
| Đòn nặng | 111.03% ATK | 219.47% ATK |
| Nhảy | 63.93% ATK | 126.38% ATK |

**Kỹ năng — Dawnbearing Songbird** (hồi chiêu 15s): triệu hồi chim Aedon lao thẳng (Nhấn) hoặc ngắm bắn (Giữ) gây
DMG Geo (theo EM+DEF).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Press DMG | 482.56% EM+241.28% DEF | 868.61% EM+434.3% DEF (cấp 13: 1,025.44%+512.72%) |
| Hold DMG | 603.2% EM+301.6% DEF | 1,085.76% EM+542.88% DEF (cấp 13: 1,281.8%+640.9%) |

**Bùng nổ — Shadowless Reflection** (năng lượng 60, hồi chiêu 15s, thời lượng 20s): thắp đèn gây DMG Geo, ban 21
stack Nightingale's Song; đòn Geo của nhân vật đang chiến đấu tiêu 1 stack để tăng DMG (theo EM Illuga, tăng thêm
nếu là Lunar-Crystallize).
| Chỉ số (theo DEF+EM) | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 827.2% EM+413.6% DEF | 1,488.96% EM+744.48% DEF (cấp 13: 1,757.8%+878.9%) |
| Geo DMG Bonus (mỗi lần tiêu) | 33.6 (theo EM) | 60.48 (cấp 13: 71.4) |
| Lunar-Crystallize Bonus | 225.92 (theo EM) | 406.66 (cấp 13: 480.08) |

**Passive A1 — Torchforger's Covenant:** dùng Kỹ năng/Bùng nổ: đồng đội +5% Tỉ lệ st bạo kích/+10% CRIT DMG DMG Geo
(20s; Moonsign Ascendant Gleam: thêm +50 EM).
**Passive A4 — Demonhunter's Dusk:** có 1/2/3 nhân vật Hydro/Geo: Nightingale's Song +7%/14%/24% EM DMG (Lunar-
Crystallize: +48%/96%/160% EM).
**Moonsign Benediction Passive — Unwithering in Winter:** Illuga trong đội +1 cấp Moonsign.
**Utility Passive:** ban đêm cả đội +10% tốc di chuyển.

### Cung mệnh
1. Kích hoạt phản ứng Geo: hồi 12 năng lượng (15s/lần).
2. Trong Haunted Night's Oriole-Song: mỗi 7 stack Nightingale's Song tiêu, Illuga triệu hồi Aedon đánh 1 địch = 400%
   EM+200% DEF (DMG Bùng nổ).
3. Tăng cấp Shadowless Reflection +3.
4. Trong Haunted Night's Oriole-Song: đồng đội đang chiến đấu +200 DEF.
5. Tăng cấp Dawnbearing Songbird +3.
6. Lightkeeper's Oath (A1) nâng +10% Tỉ lệ st bạo kích/+30% CRIT DMG; Moonsign Ascendant Gleam: +80 EM (cần mở A1).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ off-field buff DMG Geo/Lunar-Crystallize toàn đội, phù hợp đội Geo hoặc
Hydro-Crystallize. Combo phổ biến: Illuga + Linnea/Columbina (Lunar-Crystallize), Illuga + Noelle/Albedo (Geo mono).

---

## Jahoda

**Nguyên tố:** Anemo | **Vũ khí:** Cung | **Độ hiếm:** 4★ | **Quốc gia:** Nod-Krai | **Ngày ra mắt:** 03/12/2025 (Luna III)

### Chỉ số cơ bản

| Cấp | HP | ATK | DEF | Tỉ lệ hồi máu |
|---|---|---|---|---|
| 1 | 808.76 | 18.70 | 48.64 | — |
| 90 | 9,646.05 | 223.02 | 580.14 | 18.48% |

### Bộ kỹ năng

**Đòn thường — Strike While the Arrow's Hot:** tối đa 3 đòn cung.
| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 41.67% ATK | 82.38% ATK |
| 2-Hit (x2) | 19.23%×2 ATK | 38.02%×2 ATK |
| 3-Hit | 51.2% ATK | 101.2% ATK |
| Ngắm bắn thường/full | 43.86% / 124% ATK | 86.7% / 223.2% ATK |
| Nhảy | 56.83% ATK | 112.34% ATK |

**Kỹ năng — Savvy Strategy: Splitting the Spoils** (hồi chiêu 15s): xông vào địch, vào Shadow Pursuit — nếu địch
dính Pyro/Hydro/Electro/Cryo, hoá Purr-loined Treasure Flask theo nguyên tố đó (chỉ 1 lần/lượt), đầy bình tự xả gây
DMG Anemo (Moonsign Ascendant Gleam: xả từ từ bằng Fluffy Meowball, hồi năng lượng).
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Smoke Bomb DMG | 159% ATK | 286.2% ATK (cấp 13: 337.88%) |
| Unfilled Flask DMG | 190.8% ATK | 343.44% ATK (cấp 13: 405.45%) |
| Filled Flask DMG | 212% ATK | 381.6% ATK (cấp 13: 450.5%) |
| Fluffy Meowball DMG | 128% ATK | 230.4% ATK (cấp 13: 272%) |

**Bùng nổ — Hidden Aces: Seven Tools of the Hunter** (năng lượng 70, hồi chiêu 18s): triệu hồi 2 robot hồi máu liên
tục cho đội (theo ATK), gây DMG Anemo tức thì.
| Chỉ số | Cấp 1 | Cấp 10 (max 13) |
|---|---|---|
| Skill DMG | 207.2% ATK | 372.96% ATK (cấp 13: 440.3%) |
| Robot DMG | 17.27% ATK | 31.08% ATK (cấp 13: 36.69%) |
| Robot hồi máu | 79.87% ATK+501 | 143.77% ATK+1,102 (cấp 13: 169.73% ATK+1,377) |

**Passive A1 — Plan to Get Paid:** đội có ≥1 Pyro/Hydro/Electro/Cryo: robot tăng hiệu ứng theo nguyên tố nhiều nhất
(Pyro +30% DMG, Hydro +20% hồi máu, Electro +1 robot, Cryo -10% khoảng cách bắn).
**Passive A4 — Sweet Berry Bounty:** robot hồi máu cho nhân vật >70% HP: +100 EM (6s).
**Moonsign Benediction Passive — Rooftop Dash:** Jahoda trong đội +1 cấp Moonsign.
**Utility Passive:** giảm 25% thời gian thám hiểm Nod-Krai.

### Cung mệnh
1. Fluffy Meowball trúng có 50% nảy gây thêm DMG nguyên tố tương ứng.
2. Moonsign Ascendant Gleam: theo dõi thêm nguyên tố nhiều thứ 2 (tối đa 2 hiệu ứng cùng lúc, cần mở A1).
3. Tăng cấp Hidden Aces: Seven Tools of the Hunter +3.
4. Robot chuyển đổi nguyên tố: hồi 4 năng lượng.
5. Tăng cấp Savvy Strategy: Splitting the Spoils +3.
6. Moonsign Ascendant Gleam: bình đầy: đồng đội Moonsign quanh +5% Tỉ lệ st bạo kích/+40% CRIT DMG (20s).

**Vai trò đội hình Trầm Thủy:** Hỗ trợ hồi máu + gây sát thương đa nguyên tố linh hoạt tuỳ đội hình, dễ nhét vào mọi
đội 4 nguyên tố cơ bản. Combo phổ biến: Jahoda + đội đa nguyên tố (Pyro/Hydro/Electro/Cryo) để tối ưu hoá buff robot.

---
