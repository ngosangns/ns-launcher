<!--
Ngày lấy dữ liệu: 2026-09-08
Nguồn:
  - gi.yatta.moe API (api.ambr.top không truy cập được từ môi trường build, dùng
    Yatta — cùng nhóm phát triển với Ambr, cùng trích xuất trực tiếp từ file
    game) — dùng cho: chỉ số cơ bản (initValue cấp 1), hệ số đột phá (ascension
    addProps ở đột phá cuối/cấp 90), toàn bộ mô tả + hệ số scaling kỹ năng theo
    cấp, cung mệnh.
  - Chỉ số HP/ATK/DEF ở cấp 90 = initValue × hệ số đường cong trưởng thành ở
    cấp 90 (hằng số ước tính từ dữ liệu game: ~8.7385 cho nhân vật 5★, ~8.355
    cho nhân vật 4★, đối chiếu khớp với số liệu cộng đồng đã biết của Kamisato
    Ayaka/Raiden Shogun/Furina/Xingqiu trong phạm vi sai số làm tròn) cộng với
    addProps (hệ số đột phá cấp 90, lấy trực tiếp từ API — chính xác tuyệt
    đối, không phải ước tính).
  - Cấp kỹ năng: hiển thị cấp 1, cấp 10 (tối đa lên bằng nguyên liệu) và cấp
    13 khi nhân vật có cung mệnh (thường C3 hoặc C5) tăng thêm 3 cấp cho kỹ
    năng nguyên tố hoặc bùng nổ (xác định qua trường `linkedConstellations`
    của API, không suy đoán).
  - Đối chiếu chéo bằng kiến thức nền đã có (các nhân vật Inazuma/Fontaine đều
    phát hành trước 2026, nằm trong dữ liệu huấn luyện).
  - Danh sách nhân vật (region) xác nhận qua field "region" của API; Chiori có
    region "INAZUMA" dù làm việc tại Fontaine; Arlecchino có region "FATUI"
    (thuộc Snezhnaya/Fatui, KHÔNG thuộc Fontaine) nên không đưa vào file này.
-->

# Inazuma + Fontaine — Toàn bộ nhân vật

30 nhân vật: 17 Inazuma + 13 Fontaine (mọi độ hiếm, tính đến bản cập nhật gần
nhất trước 2026-09-08).

> **Bổ sung 2026-09-08:** Kaedehara Kazuha trước đó bị thiếu hoàn toàn khỏi
> file này (phát hiện khi dựng thuật toán gợi ý đội hình — anh được nhắc tên
> 8 lần trong phần gợi ý combo của các nhân vật khác nhưng không có mục
> riêng). Đã bổ sung đầy đủ từ `gi.yatta.moe/api/v2/en/avatar/10000047`.

## Mục lục

**Inazuma:** [Kamisato Ayaka](#kamisato-ayaka) · [Yoimiya](#yoimiya) ·
[Sayu](#sayu) · [Raiden Shogun](#raiden-shogun) · [Kujou Sara](#kujou-sara) ·
[Sangonomiya Kokomi](#sangonomiya-kokomi) · [Thoma](#thoma) · [Gorou](#gorou) ·
[Arataki Itto](#arataki-itto) · [Yae Miko](#yae-miko) ·
[Kamisato Ayato](#kamisato-ayato) · [Kuki Shinobu](#kuki-shinobu) ·
[Shikanoin Heizou](#shikanoin-heizou) · [Kirara](#kirara) · [Chiori](#chiori) ·
[Yumemizuki Mizuki](#yumemizuki-mizuki) · [Kaedehara Kazuha](#kaedehara-kazuha)

**Fontaine:** [Lynette](#lynette) · [Lyney](#lyney) · [Freminet](#freminet) ·
[Neuvillette](#neuvillette) · [Wriothesley](#wriothesley) ·
[Charlotte](#charlotte) · [Furina](#furina) · [Navia](#navia) ·
[Chevreuse](#chevreuse) · [Clorinde](#clorinde) · [Sigewinne](#sigewinne) ·
[Emilie](#emilie) · [Escoffier](#escoffier)

---

## Inazuma

### Kamisato Ayaka

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Cryo (Băng) | Kiếm 1 tay | 5★ | Inazuma | 2021-07-20 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1001 | 27 | 61 |
| 90 (đột phá 6) | 12858 | 342 | 784 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit DMG) +38.4%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Kamisato Art: Kabuki**: đánh thường tối đa 5 đòn kiếm; đòn
  nặng tiêu Thể lực tung 3 nhát kiếm khí; đòn nhảy gây sát thương AoE khi đáp
  đất.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 45.7% | 90.4% |
  | 2-Hit | 48.7% | 96.2% |
  | 3-Hit | 62.6% | 123.8% |
  | 4-Hit (×3) | 22.6% | 44.8% |
  | 5-Hit | 78.2% | 154.5% |
  | Đòn nặng (×3) | 55.1% | 109.0% |
  | Sát thương nhảy thấp/cao | 127.8%/159.7% | 252.7%/315.6% |

- **Kỹ năng nguyên tố — Kamisato Art: Hyouka** (CD 10s, không tốn năng
  lượng): triệu hồi băng nở rộ, hất tung địch quanh Ayaka và gây sát thương
  AoE Cryo. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 239.2% | 430.6% | 568.1% |

- **Đòn giữ/né đặc biệt — Kamisato Art: Senho** (cấp cố định 1): tiêu Thể
  lực để lướt trên mặt nước trong màn sương lạnh; khi thoát trạng thái, gây
  Cryo diện rộng quanh Ayaka và tráng Cryo lên đòn đánh trong thời gian ngắn.
  Tiêu 10 Thể lực để kích hoạt, hao 15 Thể lực/giây, thời gian tráng nguyên
  tố 5s.

- **Bùng nổ nguyên tố — Kamisato Art: Soumetsu** (CD 20s, 80 năng lượng):
  triệu hồi bão tuyết Frostflake Seki no To lướt về phía trước, liên tục chém
  gây Cryo DMG rồi nổ tung gây AoE Cryo DMG cuối màn. Cấp kỹ năng được C3
  tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương chém | 112.3% | 202.1% | 266.7% |
  | Sát thương nổ | 168.5% | 303.2% | 400.1% |
  | Thời lượng | 5.0s | 5.0s | 5.0s |

- **Passive 1 — Amatsumi Kunitsumi Sanctification**: sau khi dùng Hyouka,
  đòn thường/nặng của Ayaka tăng 30% sát thương trong 6s.
- **Passive 2 — Kanten Senmyou Blessing**: khi Cryo cuối đòn Senho trúng
  địch, Ayaka hồi 10 Thể lực và nhận 18% Cryo DMG Bonus trong 10s.
- **Passive 3 (chế tạo) — Fruits of Shinsa**: 10% cơ hội nhân đôi nguyên
  liệu đột phá vũ khí khi chế tạo.

**Cung mệnh (Constellation)**

1. **Snowswept Sakura** — đòn thường/nặng gây Cryo DMG có 50% cơ hội giảm CD
   Hyouka 0.3s (tối đa 1 lần/0.1s).
2. **Blizzard Blade Seki no To** — khi dùng Soumetsu, tung thêm 2
   Frostflake Seki no To nhỏ, mỗi cái gây 20% sát thương bão gốc.
3. **Frostbloom Kamifubuki** — tăng cấp Soumetsu thêm 3 (tối đa cấp 15 theo
   hệ thống, thực tế đạt 13).
4. **Ebb and Flow** — địch trúng Frostflake Seki no To của Soumetsu giảm
   30% DEF trong 6s.
5. **Blossom Cloud Irutsuki** — tăng cấp Hyouka thêm 3 (thực tế đạt 13).
6. **Dance of Suigetsu** — cứ 10s Ayaka nhận Usurahi Butou, tăng 298% sát
   thương đòn nặng; hiệu ứng biến mất 0.5s sau khi đòn nặng trúng địch rồi
   khởi động lại đếm giờ.

**Gợi ý đội hình Trầm Thủy**: DPS chính Cryo on-field dựa vào Hyouka +
Soumetsu để đóng băng diện rộng. Combo phổ biến: Đóng băng (Cryo-Hydu) với
Kokomi/Yelan, hoặc Tan chảy (Cryo-Pyro) với Xiangling/Bennett làm phụ trợ.

---

### Yoimiya

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Pyro (Hoả) | Cung | 5★ | Inazuma | 2021-08-10 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 791 | 25 | 48 |
| 90 (đột phá 6) | 10164 | 323 | 615 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Firework Flare-Up**: bắn cung tối đa 5 phát; đòn nặng là
  Aimed Shot chính xác hơn — tích đủ năng lượng lửa sẽ bắn mũi tên Pyro và
  có thể tạo Kindling Arrow rơi xuống gây sát thương bổ sung.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit (×2) | 35.6% | 63.6% |
  | 2-Hit | 68.4% | 122.0% |
  | 3-Hit | 88.9% | 158.6% |
  | 4-Hit (×2) | 46.4% | 82.8% |
  | 5-Hit | 105.9% | 188.9% |
  | Aimed Shot | 43.9% | 86.7% |
  | Aimed Shot sạc đầy | 124.0% | 223.2% |
  | Kindling Arrow | 16.4% | 29.5% |

- **Kỹ năng nguyên tố — Niwabi Fire-Dance** (CD 18s): tạo vòng pháo hoa
  quanh Yoimiya, đòn thường trong thời gian này biến thành Blazing Arrow, gây
  Pyro DMG tăng thêm. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Blazing Arrow DMG (% ST đòn thường) | 137.9% | 161.7% | 176.5% |
  | Thời lượng | 10.0s | 10.0s | 10.0s |

- **Bùng nổ nguyên tố — Ryuukin Saxifrage** (CD 15s, 60 năng lượng): nhảy
  lên bắn tên lửa gây AoE Pyro DMG, đánh dấu Aurous Blaze lên 1 địch — đồng
  đội (trừ Yoimiya) đánh trúng địch đánh dấu sẽ kích nổ gây thêm AoE Pyro
  DMG. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 127.2% | 229.0% | 302.1% |
  | Sát thương nổ Aurous Blaze | 122.0% | 219.6% | 289.8% |

- **Passive 1 — Tricks of the Trouble-Maker**: trong Niwabi Fire-Dance, mỗi
  phát đòn thường trúng địch tăng 2% Pyro DMG Bonus (tối đa 10 lớp, 3s/lớp).
- **Passive 2 — Summer Night's Dawn**: dùng Ryuukin Saxifrage cho đồng đội
  (trừ Yoimiya) +10% ATK trong 15s, cộng thêm 1%/lớp Trouble-Maker đang có.
- **Passive 3 (chế tạo) — Blazing Match**: 100% hoàn trả một phần nguyên
  liệu khi chế tạo đồ nội thất loại Trang trí/Vật phẩm/Cảnh quan.

**Cung mệnh (Constellation)**

1. **Agate Ryuukin** — Aurous Blaze kéo dài thêm 4s; hạ gục địch trong thời
   gian này giúp Yoimiya +20% ATK trong 20s.
2. **A Procession of Bonfires** — Pyro DMG chí mạng cho Yoimiya +25% Pyro
   DMG Bonus trong 6s (kích hoạt cả khi không ở tiền tuyến).
3. **Trickster's Flare** — tăng cấp Niwabi Fire-Dance thêm 3 (thực tế 13).
4. **Pyrotechnic Professional** — Aurous Blaze tự nổ giảm CD Niwabi
   Fire-Dance 1.2s.
5. **A Summer Festival's Eve** — tăng cấp Ryuukin Saxifrage thêm 3 (thực tế
   13).
6. **Naganohara Meteor Swarm** — trong Niwabi Fire-Dance, đòn thường có 50%
   cơ hội bắn thêm 1 Blazing Arrow gây 60% sát thương gốc.

**Gợi ý đội hình Trầm Thủy**: DPS chính Pyro bền bỉ dùng đòn thường liên
tục, không cần nhắm elemental burst spam. Combo phổ biến: Thuận Pyro (Pyro
mono/Pyro-Dendro Burning) hoặc Tan chảy (Pyro-Hydro) cùng Kokomi/Xingqiu hỗ
trợ khiên + hồi máu.

---

### Sayu

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Anemo (Phong) | Đại kiếm | 4★ | Inazuma | 2021-08-10 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 994 | 20 | 62 |
| 90 (đột phá 6) | 11860 | 244 | 745 |

Chỉ số đột phá phụ: **Tinh Thông Nguyên Tố (EM) +96** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Shuumatsuban Ninja Blade**: chém tối đa 4 đòn; đòn nặng
  xoay liên tục hao Thể lực rồi kết đòn mạnh.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 72.2% | 142.8% |
  | 4-Hit | 98.1% | 194.0% |
  | Đòn nặng xoay | 62.5% | 123.6% |
  | Đòn nặng kết thúc | 113.1% | 223.6% |

- **Kỹ năng nguyên tố — Yoohoo Art: Fuuin Dash** (CD 6–11s, thay đổi theo
  thời gian giữ): cuộn thành bánh xe gió lao vào địch gây Anemo DMG, hết giờ
  tung cước gió AoE.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Fuufuu Windwheel DMG | 36.0% | 64.8% |
  | Whirlwind Kick (bấm) | 158.4% | 285.1% |
  | Whirlwind Kick (giữ) | 217.6% | 391.7% |

- **Bùng nổ nguyên tố — Yoohoo Art: Mujina Flurry** (CD 20s, 80 năng
  lượng): gây Anemo DMG + hồi máu đồng đội gần đó theo ATK, triệu hồi
  Muji-Muji Daruma tự động tấn công hoặc hồi máu tuỳ HP đồng đội.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Sát thương kích hoạt | 116.8% | 210.2% |
  | Hồi máu kích hoạt | 92.2% ATK+577 | 165.9% ATK+1270 |
  | Sát thương Daruma | 52.0% | 93.6% |
  | Hồi máu Daruma | 79.9% ATK+500 | 143.8% ATK+1101 |

  *Sayu không có cung mệnh tăng cấp kỹ năng — tối đa cấp 10.*

- **Passive 1 — Someone More Capable**: khi Sayu on-field kích hoạt phản
  ứng Xoáy Cuốn (Swirl)/Xoáy Cuốn Sao, hồi 300 HP cho cả đội + 1.2 HP/điểm
  EM (1 lần/2s).
- **Passive 2 — No Work Today!**: Daruma khi hồi máu 1 người sẽ lan 20% HP
  đó cho người gần đó; tăng phạm vi tấn công của Daruma.
- **Passive 3 — Yoohoo Art: Silencer's Secret**: không làm giật mình sinh
  vật hoang dã khi có Sayu trong đội.

**Cung mệnh (Constellation)**

1. **Multi-Task no Jutsu** — Daruma bỏ qua giới hạn HP, vừa tấn công vừa
   hồi máu cùng lúc.
2. **Egress Prep** — Whirlwind Kick (bấm) +3.3% DMG; mỗi 0.5s giữ Fuuin
   Dash +3.3% DMG Whirlwind Kick (tối đa +66%).
3. **Eh, the Bunshin Can Handle It** — tăng cấp Mujina Flurry thêm 3.
4. **Skiving: New and Improved** — kích hoạt Swirl/Xoáy Cuốn Sao hồi 1.2
   năng lượng (1 lần/2s).
5. **Speed Comes First** — tăng cấp Fuuin Dash thêm 3.
6. **Sleep O'Clock** — Daruma hưởng lợi từ EM của Sayu: +0.2% ATK sát
   thương/điểm EM (tối đa +400% ATK) và +3 HP hồi/điểm EM (tối đa +6000 HP).

**Gợi ý đội hình Trầm Thủy**: Hỗ trợ tạo phản ứng Xoáy Cuốn (Swirl) lan
nguyên tố diện rộng kiêm hồi máu tự động qua Daruma, gần như không cần đứng
lại. Combo phổ biến: đội Xoáy Cuốn EM cao (Anemo-Electro/Anemo-Hydro) hoặc
đi cùng Traveler Anemo để tăng lan toả nguyên tố.

---

### Raiden Shogun

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Electro (Lôi) | Trường thương | 5★ | Inazuma | 2021-08-31 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1005 | 26 | 61 |
| 90 (đột phá 6) | 12907 | 337 | 789 |

Chỉ số đột phá phụ: **Tinh Anh Nguyên Tố (Energy Recharge) +32.0%** ở cấp
90.

**Bộ kỹ năng**

- **Đòn thường — Origin**: đâm thương tối đa 5 đòn; đòn nặng tiêu Thể lực
  vung thương lên cao.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 39.6% | 78.4% |
  | 5-Hit | 65.4% | 129.4% |
  | Đòn nặng | 99.6% | 196.9% |

- **Kỹ năng nguyên tố — Transcendence: Baleful Omen** (CD 10s, không tốn
  năng lượng): mở mảnh Euthymia gây Electro DMG quanh mình, ban Eye of
  Stormy Judgment cho đồng đội gần đó — đòn đánh trúng địch của người mang
  Eye sẽ kích hoạt đòn phối hợp Electro AoE và tăng DMG bùng nổ nguyên tố
  theo % năng lượng tối đa. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 117.2% | 211.0% | 278.4% |
  | Đòn phối hợp DMG | 42.0% | 75.6% | 99.8% |
  | Tăng DMG Burst /điểm NL | 0.22% | 0.30% | 0.30% |
  | Thời lượng Eye | 25.0s | 25.0s | 25.0s |

- **Bùng nổ nguyên tố — Secret Art: Musou Shinsetsu** (CD 18s, 90 năng
  lượng): tung Musou no Hitotachi gây AoE Electro DMG (tăng theo số lớp
  Resolve tiêu thụ), sau đó vào trạng thái Musou Isshin dùng đao chiến đấu.
  Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Musou no Hitotachi (DMG gốc) | 400.8% | 721.4% | 951.9% |
  | Resolve Bonus (khởi điểm/mỗi lớp) | 3.89%/0.73% ATK | 7.00%/1.31% ATK | 9.23%/1.72% ATK |
  | Thời lượng Musou Isshin | 7.0s | 7.0s | 7.0s |

- **Passive 1 — Wishes Unnumbered**: đồng đội gần đó nhận Orb/Particle
  nguyên tố giúp Chakra Desiderata +2 lớp Resolve (1 lần/3s).
- **Passive 2 — Enlightened One**: mỗi 1% Energy Recharge vượt 100% cho
  +0.6% hồi năng lượng khi thoát Musou Isshin và +0.4% Electro DMG Bonus.
- **Passive 3 (chế tạo) — All-Preserver**: giảm 50% Mora khi đột phá Kiếm
  và Trường thương.

**Cung mệnh (Constellation)**

1. **Ominous Inscription** — tích Resolve nhanh hơn; nhân vật Electro dùng
   Burst tích thêm 80% Resolve, nguyên tố khác +20%.
2. **Steelbreaker** — khi ở Musou Isshin, đòn đánh xuyên 60% DEF địch.
3. **Shinkage Bygones** — tăng cấp Musou Shinsetsu thêm 3.
4. **Pledge of Propriety** — hết Musou Isshin, đồng đội (trừ Raiden) +30%
   ATK trong 10s.
5. **Shogun's Descent** — tăng cấp Transcendence: Baleful Omen thêm 3.
6. **Wishbearer** — đòn Burst trong Musou Isshin giảm CD Burst đồng đội 1s
   khi trúng địch (1 lần/1s, tối đa 5 lần/lượt Musou Isshin).

**Gợi ý đội hình Trầm Thủy**: Hybrid hỗ trợ năng lượng + sub-DPS Electro
hàng đầu, gần như bắt buộc trong mọi đội cần xoay vòng burst liên tục. Combo
phổ biến: Quá Tải/Cảm Ứng Siêu Dẫn (Electro-Pyro/Electro-Cryo) hoặc đội tán
xạ (Electro-Anemo/Electro-Hydro) tận dụng Eye of Stormy Judgment.

---

### Kujou Sara

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Electro (Lôi) | Cung | 4★ | Inazuma | 2021-08-31 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 802 | 16 | 53 |
| 90 (đột phá 6) | 9575 | 196 | 628 |

Chỉ số đột phá phụ: **ATK% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Tengu Bowmanship**: bắn cung tối đa 5 phát; đòn nặng Aimed
  Shot tích điện, khi đang có Crowfeather Cover thì để lại Crowfeather sau
  khi trúng.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Aimed Shot | 43.9% | 86.7% |
  | Aimed Shot sạc đầy | 124.0% | 223.2% |

- **Kỹ năng nguyên tố — Tengu Stormcall** (CD 10s): lùi nhanh, nhận
  Crowfeather Cover 18s; Aimed Shot sạc đầy sẽ để lại Crowfeather kích hoạt
  Tengu Juurai: Ambush gây Electro DMG và cấp ATK Bonus theo ATK cơ bản của
  Sara cho người trong vùng.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Ambush DMG | 125.8% | 226.4% |
  | Tỉ lệ ATK Bonus (theo ATK cơ bản Sara) | 43.0% | 77.3% |
  | Thời lượng ATK Bonus | 6.0s | 6.0s |

- **Bùng nổ nguyên tố — Subjugation: Koukou Sendou** (CD 20s, 80 năng
  lượng): giáng Tengu Juurai: Titanbreaker gây AoE Electro DMG, sau đó tách
  thành 4 đợt Stormcluster, đều có thể cấp ATK Bonus như kỹ năng.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Titanbreaker DMG | 409.6% | 737.3% |
  | Stormcluster DMG (mỗi đợt) | 34.1% | 61.4% |

  *Sara không có cung mệnh tăng cấp kỹ năng — tối đa cấp 10.*

- **Passive 1 — Immovable Will**: trong Crowfeather Cover, thời gian sạc
  Aimed Shot giảm 60%.
- **Passive 2 — Decorum**: Tengu Juurai: Ambush trúng địch hồi 1.2 năng
  lượng toàn đội mỗi 100% Energy Recharge của Sara (1 lần/3s).
- **Passive 3 — Land Survey**: giảm 25% thời gian thám hiểm tại Inazuma.

**Cung mệnh (Constellation)**

1. **Crow's Eye** — Tengu Juurai cấp ATK hoặc trúng địch giảm CD Tengu
   Stormcall 1s (1 lần/3s).
2. **Dark Wings** — dùng Tengu Stormcall để lại Crowfeather yếu tại vị trí
   cũ, gây 30% sát thương gốc.
3. **The War Within** — tăng cấp Koukou Sendou thêm 3.
4. **Conclusive Proof** — Koukou Sendou tăng số đợt Stormcluster lên 6.
5. **Spellsinger** — tăng cấp Tengu Stormcall thêm 3.
6. **Sin of Pride** — nhân vật được Tengu Juurai cấp ATK có Electro DMG khi
   chí mạng +60% Crit DMG.

**Gợi ý đội hình Trầm Thủy**: Buffer ATK% chuyên biệt cho DPS Electro/dùng
phản ứng Electro (Quá Tải, Cảm Ứng Siêu Dẫn, Kết Tinh). Combo phổ biến: đi
cùng Raiden Shogun/Itto để cộng dồn ATK Bonus, hoặc đội Quá Tải Electro-Pyro.

---

### Sangonomiya Kokomi

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Hydro (Thuỷ) | Đồng | 5★ | Inazuma | 2021-09-21 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1049 | 18 | 51 |
| 90 (đột phá 6) | 13470 | 234 | 657 |

Chỉ số đột phá phụ: **Hydro DMG Bonus +28.8%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — The Shape of Water**: đánh 3 đòn hình cá bơi gây Hydro
  DMG; đòn nặng tiêu Thể lực gây AoE Hydro DMG sau thời gian ngắm.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 68.4% | 123.1% |
  | 3-Hit | 94.3% | 169.8% |
  | Đòn nặng | 148.3% | 267.0% |

- **Kỹ năng nguyên tố — Kurage's Oath** (CD 20s, không tốn năng lượng):
  triệu hồi Bake-Kurage gây Hydro DMG quanh mình theo chu kỳ và hồi máu đồng
  đội gần đó theo Max HP. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Hồi máu/nhịp | 4.4% MaxHP+424 | 7.9% MaxHP+932 | 9.3% MaxHP+1165 |
  | Sát thương gợn sóng | 109.2% | 196.5% | 232.0% |
  | Thời lượng | 12.0s | 12.0s | 12.0s |

- **Bùng nổ nguyên tố — Nereid's Ascension** (CD 18s, 70 năng lượng): gây
  Hydro DMG quanh mình rồi khoác Ceremonial Garment — tăng sát thương đòn
  thường/nặng/Bake-Kurage theo Max HP và hồi máu đồng đội khi đòn thường/nặng
  trúng địch. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 10.4% MaxHP | 18.7% MaxHP | 22.1% MaxHP |
  | Bonus đòn thường | 4.8% MaxHP | 8.7% MaxHP | 10.3% MaxHP |
  | Bonus đòn nặng | 6.8% MaxHP | 12.2% MaxHP | 14.4% MaxHP |
  | Hồi máu/đòn | 0.81% MaxHP+77 | 1.45% MaxHP+170 | 1.72% MaxHP+212 |

- **Passive 1 — Tamakushi Casket**: dùng Nereid's Ascension khi Bake-Kurage
  của mình còn tồn tại sẽ làm mới thời lượng Bake-Kurage.
- **Passive 2 — Song of Pearls**: khi khoác Ceremonial Garment, bonus DMG
  theo Max HP được cộng thêm 15% Healing Bonus của Kokomi.
- **Passive 3 — Princess of Watatsumi**: giảm 20% tiêu hao Thể lực khi bơi
  cho cả đội.
- **Passive 4 (mặc định mở khoá) — Flawless Strategy**: +25% Healing Bonus
  nhưng −100% Crit Rate.

**Cung mệnh (Constellation)**

1. **At Water's Edge** — khi khoác Ceremonial Garment, đòn thường cuối
   combo tung thêm cá bơi gây 30% Max HP Hydro DMG (không tính là ST đòn
   thường).
2. **The Clouds Like Waves Rippling** — tăng hồi máu cho mục tiêu ≤50% HP:
   Bake-Kurage +4.5% MaxHP, đòn thường/nặng +0.6% MaxHP.
3. **The Moon, A Ship O'er the Seas** — tăng cấp Nereid's Ascension thêm 3.
4. **The Moon Overlooks the Waters** — khi khoác Ceremonial Garment, tốc
   đánh thường +10% và đòn thường trúng địch hồi 0.8 năng lượng (1 lần/0.2s).
5. **All Streams Flow to the Sea** — tăng cấp Kurage's Oath thêm 3.
6. **Sango Isshin** — khi khoác Ceremonial Garment, đòn thường/nặng hồi máu
   (hoặc sẽ hồi máu) cho đồng đội ≥80% HP giúp Kokomi +40% Hydro DMG Bonus
   trong 4s.

**Gợi ý đội hình Trầm Thủy**: Support/sub-DPS hồi máu diện rộng theo % Max
HP, gần như không thể chết, thường build HP thay vì Crit. Combo phổ biến:
đóng băng (Hydro-Cryo) cùng Chongyun/Kaeya, hoặc Bắt Điện (Hydro-Electro)
làm nền tảng phản ứng cho cả đội.

---

### Thoma

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Pyro (Hoả) | Trường thương | 4★ | Inazuma | 2021-11-02 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 866 | 17 | 63 |
| 90 (đột phá 6) | 10336 | 202 | 751 |

Chỉ số đột phá phụ: **ATK% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Swiftshatter Spear**: đâm tối đa 4 đòn; đòn nặng lao về
  trước gây sát thương dọc đường.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 44.4% | 87.8% |
  | 4-Hit | 67.4% | 133.1% |
  | Đòn nặng | 112.7% | 222.9% |

- **Kỹ năng nguyên tố — Blazing Blessing** (CD 15s): bay lên đá gây AoE
  Pyro DMG, tự tráng Pyro lên mình và tạo khiên Blazing Barrier (hấp thụ
  Pyro DMG hiệu quả hơn 250%) theo Max HP. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 146.4% | 263.5% | 311.1% |
  | Khiên hấp thụ | 7.2% MaxHP+693 | 13.0% MaxHP+1526 | 15.3% MaxHP+1907 |
  | Khiên tối đa (stack) | 19.6% MaxHP+1887 | 35.3% MaxHP+4153 | 41.6% MaxHP+5191 |

- **Bùng nổ nguyên tố — Crimson Ooyoroi** (CD 20s, 80 năng lượng): xoay
  thương gây AoE Pyro DMG và khoác Scorching Ooyoroi — đòn thường của nhân
  vật đang chiến đấu kích hoạt Fiery Collapse gây AoE Pyro DMG + tạo thêm
  Blazing Barrier. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 88.0% | 158.4% | 187.0% |
  | Fiery Collapse DMG | 58.0% | 104.4% | 123.2% |
  | Thời lượng Ooyoroi | 15.0s | 15.0s | 15.0s |

- **Passive 1 — Imbricated Armor**: nhận/làm mới Blazing Barrier cho nhân
  vật đang chiến đấu +5% Shield Strength trong 6s (1 lần/0.3s, tối đa 5
  lớp).
- **Passive 2 — Flaming Assault**: Fiery Collapse +2.2% Max HP của Thoma
  vào sát thương.
- **Passive 3 — Snap and Swing**: câu cá tại Inazuma có 20% cơ hội câu
  được gấp đôi.

**Cung mệnh (Constellation)**

1. **A Comrade's Duty** — người được khiên bảo vệ (trừ Thoma) bị tấn công
   sẽ giảm CD cả 2 kỹ năng của Thoma 3s (1 lần/20s).
2. **A Subordinate's Skills** — Crimson Ooyoroi kéo dài thêm 3s.
3. **Fortified Resolve** — tăng cấp Blazing Blessing thêm 3.
4. **Long-Term Planning** — dùng xong Crimson Ooyoroi hồi 15 năng lượng.
5. **Raging Wildfire** — tăng cấp Crimson Ooyoroi thêm 3.
6. **Burning Heart** — nhận/làm mới Blazing Barrier giúp cả đội +15% sát
   thương đòn thường/nặng/nhảy trong 6s.

**Gợi ý đội hình Trầm Thủy**: Hỗ trợ khiên bền (theo Max HP) kiêm tráng
Pyro liên tục — rất mạnh trong đội cần chống ngắt chiêu và tự tạo phản ứng
Pyro. Combo phổ biến: Tan chảy (Pyro-Cryo) với Ayaka/Ganyu, hoặc đội Cháy
nổ (Pyro-Dendro) đứng cạnh tráng nguyên tố an toàn.

---

### Gorou

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Geo (Nham) | Cung | 4★ | Inazuma | 2021-12-14 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 802 | 15 | 54 |
| 90 (đột phá 6) | 9575 | 183 | 649 |

Chỉ số đột phá phụ: **Geo DMG Bonus +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Ripping Fang Fletching**: bắn cung tối đa 4 phát; đòn nặng
  Aimed Shot tích đá, sạc đầy gây Geo DMG.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Aimed Shot | 43.9% | 86.7% |
  | Aimed Shot sạc đầy | 124.0% | 223.2% |

- **Kỹ năng nguyên tố — Inuzaka All-Round Defense** (CD 10s): gây AoE Geo
  DMG và dựng General's War Banner, cấp buff theo số nhân vật Geo trong đội
  (1: +DEF, 2: +kháng ngắt chiêu, 3: +Geo DMG Bonus). Cấp kỹ năng được C3
  tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 107.2% | 193.0% | 227.8% |
  | DEF cộng thêm | 206.2 | 371.1 | 438.1 |
  | Geo DMG Bonus (nếu đủ 3 Geo) | 15.0% | 15.0% | 15.0% |

- **Bùng nổ nguyên tố — Juuga: Forward Unto Victory** (CD 20s, 80 năng
  lượng): gây AoE Geo DMG **theo DEF**, tạo General's Glory di chuyển theo
  nhân vật, cứ 1.5s gây thêm Crystal Collapse Geo DMG. Cấp kỹ năng được C5
  tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng (%DEF) | 98.2% | 176.8% | 208.7% |
  | Crystal Collapse DMG (%DEF) | 61.3% | 110.3% | 130.3% |
  | Thời lượng | 9.0s | 9.0s | 9.0s |

- **Passive 1 — Heedless of the Wind and Weather**: dùng xong Burst, đồng
  đội gần đó +25% DEF trong 12s.
- **Passive 2 — A Favor Repaid**: sát thương kỹ năng của Gorou cộng thêm
  theo DEF (Skill +156% DEF, Burst/Crystal Collapse +15.6% DEF).
- **Passive 3 — Seeker of Shinies**: hiện tài nguyên đặc thù Inazuma trên
  minimap.

**Cung mệnh (Constellation)**

1. **Rushing Hound: Swift as the Wind** — đồng đội trong vùng buff gây Geo
   DMG giúp giảm CD kỹ năng Gorou 2s (1 lần/10s).
2. **Sitting Hound: Steady as a Clock** — General's Glory kéo dài thêm 1s
   mỗi khi có phản ứng Kết Tinh gần đó (tối đa +3s).
3. **Mauling Hound: Fierce as Fire** — tăng cấp Inuzaka All-Round Defense
   thêm 3.
4. **Lapping Hound: Warm as Water** — ở trạng thái "Impregnable"/"Crunch",
   General's Glory hồi máu 50% DEF của Gorou mỗi 1.5s.
5. **Striking Hound: Thunderous Force** — tăng cấp Juuga: Forward Unto
   Victory thêm 3.
6. **Valiant Hound: Mountainous Fealty** — sau khi dùng kỹ năng/burst, Geo
   DMG của cả đội +10%/+20%/+40% Crit DMG tuỳ cấp buff banner.

**Gợi ý đội hình Trầm Thủy**: Support Geo chuyên biệt, tăng DEF/Geo DMG cho
đội toàn Geo hoặc mono-Geo. Combo phổ biến: đội Geo full (Itto/Ningguang/
Albedo) tận dụng Crunch buff, hoặc Kết Tinh (Geo-Electro/Geo-Hydro) tạo
khiên nguyên tố.

---

### Arataki Itto

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Geo (Nham) | Đại kiếm | 5★ | Inazuma | 2021-12-14 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1001 | 18 | 75 |
| 90 (đột phá 6) | 12858 | 227 | 959 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Fight Club Legend**: chém tối đa 4 đòn, đòn 2 và 4 trúng
  địch tích lớp Superlative Superstrength (tối đa 5 lớp, mỗi lớp tồn tại
  60s); đòn nặng (giữ) tung liên hoàn Arataki Kesagiri không tốn Thể lực
  nhưng tốn lớp Superstrength.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 79.2% | 156.6% |
  | 4-Hit | 117.2% | 231.7% |
  | Kesagiri liên hoàn | 91.2% | 180.2% |
  | Kesagiri đòn cuối | 190.9% | 377.4% |
  | Saichimonji Slash | 90.5% | 178.8% |

- **Kỹ năng nguyên tố — Masatsu Zetsugi: Akaushi Burst!** (CD 10s, không
  tốn năng lượng): ném bò Ushi gây Geo DMG, Ushi ở lại thu hút thù, kế thừa
  HP theo % Max HP Itto và mỗi lần bị đánh cho Itto 1 lớp Superstrength (1
  lần/2s). Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 307.2% | 553.0% | 652.8% |
  | HP kế thừa (theo Max HP Itto) | 100.0% | 100.0% | 100.0% |
  | Thời lượng Ushi | 6.0s | 6.0s | 6.0s |

- **Bùng nổ nguyên tố — Royal Descent: Behold, Itto the Evil!** (CD 18s,
  70 năng lượng): biến thành Oni King, đòn thường/nặng/nhảy chuyển hẳn
  thành Geo DMG, ATK cộng thêm theo DEF, tăng tốc đánh nhưng giảm 20% kháng
  nguyên tố + vật lý. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | ATK Bonus (%DEF) | 57.6% | 103.7% | 122.4% |
  | Tốc đánh | +10.0% | +10.0% | +10.0% |
  | Thời lượng | 11.0s | 11.0s | 11.0s |

- **Passive 1 — Arataki Ichiban**: liên hoàn Kesagiri mỗi nhát +10% tốc
  đánh cho nhát sau (tối đa +30%), tăng kháng ngắt chiêu.
- **Passive 2 — Bloodline of the Crimson Oni**: sát thương Kesagiri cộng
  thêm 35% DEF của Itto.
- **Passive 3 — Woodchuck Chucked**: 25% cơ hội nhận thêm gỗ khi chặt cây.

**Cung mệnh (Constellation)**

1. **Stay a While and Listen Up** — dùng Burst xong nhận ngay 2 lớp
   Superstrength, sau 1s nhận thêm 1 lớp/0.5s trong 1.5s.
2. **Gather 'Round, It's a Brawl!** — mỗi nhân vật Geo trong đội giảm CD
   Burst 1.5s và hồi 6 năng lượng cho Itto khi dùng Burst (tối đa −4.5s CD /
   +18 năng lượng).
3. **Horns Lowered, Coming Through** — tăng cấp kỹ năng thêm 3.
4. **Jailhouse Bread and Butter** — hết trạng thái Oni King, đồng đội gần
   đó +20% DEF và +20% ATK trong 10s.
5. **10 Years of Hanamizaka Fame** — tăng cấp Burst thêm 3.
6. **Arataki Itto, Present!** — đòn nặng +70% Crit DMG; Kesagiri có 50% cơ
   hội không tốn lớp Superstrength.

**Gợi ý đội hình Trầm Thủy**: DPS chính Geo dùng đòn nặng (Kesagiri) liên
tục, cần Gorou/Albedo hỗ trợ Geo DMG Bonus và né bớt giảm kháng của Burst.
Combo phổ biến: mono-Geo (Itto-Gorou-Albedo-Zhongli) hoặc Kết Tinh với
Electro/Hydro để có thêm khiên nguyên tố.

---

### Yae Miko

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Electro (Lôi) | Đồng | 5★ | Inazuma | 2022-02-15 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 807 | 26 | 44 |
| 90 (đột phá 6) | 10372 | 340 | 569 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Spiritfox Sin-Eater**: triệu hồi linh hồ ly, tối đa 3 đòn
  Electro DMG; đòn nặng tiêu Thể lực gây AoE Electro DMG sau thời gian ngắm.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 39.7% | 71.4% |
  | 3-Hit | 56.9% | 102.4% |
  | Đòn nặng | 142.9% | 257.2% |

- **Kỹ năng nguyên tố — Yakan Evocation: Sesshou Sakura** (CD 4s, 3 lần
  tích, không tốn năng lượng): để lại bùa Sesshou Sakura tự động phóng điện
  định kỳ; bùa gần nhau sẽ tăng cấp (tối đa cấp 4), tối đa 3 bùa cùng lúc.
  Cấp kỹ năng (của bùa) được C3 tăng thêm 3.

  | Chỉ số (Sesshou Sakura cấp bùa 4) | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương/nhịp | 118.5% | 213.3% | 251.8% |
  | Thời lượng bùa | 14.0s | 14.0s | 14.0s |

- **Bùng nổ nguyên tố — Great Secret Art: Tenko Kenshin** (CD 22s, 90 năng
  lượng): giáng sét gây AoE Electro DMG, đồng thời phá huỷ Sesshou Sakura
  gần đó thành Tenko Thunderbolt giáng thêm sét theo số bùa bị phá. Cấp kỹ
  năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 260.0% | 468.0% | 552.5% |
  | Tenko Thunderbolt (mỗi bùa phá) | 333.8% | 600.9% | 709.4% |

- **Passive 1 — The Shrine's Sacred Shade**: dùng Burst, mỗi bùa bị phá
  làm mới 1 lượt tích của kỹ năng.
- **Passive 2 — Enlightened Blessing**: mỗi điểm EM tăng 0.15% sát thương
  Sesshou Sakura.
- **Passive 3 — Meditations of a Yako**: 25% cơ hội nhận thêm 1 nguyên
  liệu tu luyện vùng miền khi chế tạo.
- **Passive 4 (mặc định) — Edict of Cleansing**: bùa kéo dài thêm 10s; khi
  đồng đội kích hoạt Cảm Ứng Siêu Dẫn, đòn sét kế tiếp của bùa tăng cường
  (80% ATK Yae Miko, thêm đòn 200% ATK dạng Stellar-Conduct nếu Kết Tinh
  Sao).

**Cung mệnh (Constellation)**

1. **Yakan Offering** — mỗi lần Tenko Thunderbolt kích hoạt, hồi 8 năng
   lượng cho Yae Miko.
2. **Fox's Mooncall** — Sesshou Sakura sinh ra ở cấp 2, cấp tối đa tăng
   lên 4 (không đổi so với mặc định nếu đã max), phạm vi tấn công +60%.
3. **The Seven Glamours** — tăng cấp kỹ năng thêm 3.
4. **Sakura Channeling** — sét của Sesshou Sakura trúng địch giúp cả đội
   +20% Electro DMG Bonus trong 5s.
5. **Mischievous Teasing** — tăng cấp Burst thêm 3.
6. **Forbidden Art: Daisesshou** — đòn sét của Sesshou Sakura xuyên 60%
   DEF địch.

**Gợi ý đội hình Trầm Thủy**: DPS Electro off-field mạnh nhất — đặt bùa rồi
đổi nhân vật, gần như không cần đứng lại. Combo phổ biến: Quá Tải
(Electro-Pyro) hoặc Cảm Ứng Siêu Dẫn/tán xạ Electro-Cryo cùng Kokomi/Yelan
làm nền hồi máu.

---

### Kamisato Ayato

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Hydro (Thuỷ) | Kiếm 1 tay | 5★ | Inazuma | 2022-03-29 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1068 | 23 | 60 |
| 90 (đột phá 6) | 13715 | 299 | 769 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit DMG) +38.4%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Kamisato Art: Marobashi**: chém tối đa 5 đòn; đòn nặng
  tiêu Thể lực lao tới thực hiện chém iai.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 45.0% | 88.9% |
  | 5-Hit | 75.6% | 149.5% |
  | Đòn nặng | 129.5% | 256.0% |

- **Kỹ năng nguyên tố — Kamisato Art: Kyouka** (CD 12s, không tốn năng
  lượng): dịch chuyển vào trạng thái Takimeguri Kanka (đòn thường chuyển
  hẳn thành AoE Hydro DMG, tích lớp Namisen), để lại ảo ảnh nước nổ tung khi
  gần địch hoặc hết giờ. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Shunsuiken 1-Hit | 52.9% | 104.6% | 126.7% |
  | Shunsuiken 3-Hit | 64.9% | 128.4% | 155.5% |
  | Namisen Bonus/lớp (%MaxHP) | 0.56% | 1.11% | 1.34% |
  | Ảo ảnh nước nổ | 101.5% | 200.6% | 243.1% |
  | Thời lượng Kanka | 6.0s | 6.0s | 6.0s |

- **Bùng nổ nguyên tố — Kamisato Art: Suiyuu** (CD 20s, 80 năng lượng): mở
  không gian tĩnh lặng, Bloomwater Blade liên tục rơi gây Hydro DMG và tăng
  sát thương đòn thường cho nhân vật trong vùng. Cấp kỹ năng được C5 tăng
  thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Bloomwater Blade DMG | 66.5% | 119.6% | 141.2% |
  | Bonus đòn thường | 11.0% | 20.0% | 20.0% |
  | Thời lượng | 18.0s | 18.0s | 18.0s |

- **Passive 1 — Kamisato Art: Mine Wo Matoishi Kiyotaki**: dùng Kyouka
  nhận 2 lớp Namisen; ảo ảnh nước nổ giúp Namisen đầy lớp.
- **Passive 2 — Kamisato Art: Michiyuku Hagetsu**: khi rời sân và NL <40,
  hồi 2 NL/giây.
- **Passive 3 — Kamisato Art: Daily Cooking**: 18% cơ hội nấu ăn ra món
  phụ.

**Cung mệnh (Constellation)**

1. **Kyouka Fuushi** — Shunsuiken +40% DMG lên địch ≤50% HP.
2. **World Source** — Namisen tối đa 5 lớp; từ 3 lớp trở lên +50% Max HP.
3. **To Admire the Flowers** — tăng cấp Kyouka thêm 3.
4. **Endless Flow** — dùng Suiyuu xong, đồng đội gần đó +15% tốc đánh
   thường trong 15s.
5. **Bansui Ichiro** — tăng cấp Suiyuu thêm 3.
6. **Boundless Origin** — sau Kyouka, đòn Shunsuiken kế tiếp tạo thêm 2
   đòn phụ, mỗi đòn 450% ATK (không tính Namisen).

**Gợi ý đội hình Trầm Thủy**: DPS chính Hydro cực nhanh, chỉ cần vài giây
trên sân (bấm kỹ năng rồi đổi người) nhờ Takimeguri Kanka tự đánh. Combo phổ
biến: Đóng băng (Hydro-Cryo) với Kamisato Ayaka/Shenhe, hoặc Bốc Hơi
(Hydro-Pyro) với Yoimiya/Klee.

---

### Kuki Shinobu

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Electro (Lôi) | Kiếm 1 tay | 4★ | Inazuma | 2022-06-21 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1030 | 18 | 63 |
| 90 (đột phá 6) | 12295 | 213 | 751 |

Chỉ số đột phá phụ: **HP% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Shinobu's Shadowsword**: chém tối đa 4 đòn; đòn nặng tung
  2 nhát kiếm nhanh.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 48.8% | 96.4% |
  | 4-Hit | 76.1% | 150.4% |
  | Đòn nặng (2 nhát) | 55.6%+66.8% | 110.0%+132.0% |

- **Kỹ năng nguyên tố — Sanctifying Ring** (CD 15s, tiêu 30% HP hiện tại,
  không hạ dưới 20% HP): tạo vòng cỏ gây Electro DMG quanh mình, vòng theo
  chân nhân vật đang chiến đấu, gây Electro DMG mỗi 1.5s và hồi máu theo Max
  HP Shinobu. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 75.7% | 136.3% | 160.9% |
  | Hồi máu/nhịp vòng | 3.0% MaxHP+289 | 5.4% MaxHP+636 | 6.4% MaxHP+795 |
  | Sát thương vòng/nhịp | 25.2% | 45.4% | 53.6% |

- **Bùng nổ nguyên tố — Gyoei Narukami Kariyama Rite** (CD 15s, 60 năng
  lượng): cắm kiếm tạo trường thanh tẩy gây Electro DMG liên tục theo Max HP
  Shinobu; nếu HP Shinobu ≤50% khi dùng, trường tồn tại lâu hơn. Cấp kỹ năng
  được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Tổng DMG (HP thường/≤50%) | 25.2%/43.3% MaxHP | 45.4%/77.9% MaxHP | 53.6%/91.9% MaxHP |
  | Thời lượng (thường/≤50%) | 2.0s/3.5s | 2.0s/3.5s | 2.0s/3.5s |

- **Passive 1 — Breaking Free**: HP ≤50% thì Healing Bonus +15%.
- **Passive 2 — Heart's Repose**: Sanctifying Ring hưởng lợi EM: hồi máu
  +75% EM, sát thương +25% EM.
- **Passive 3 — Protracted Prayers**: +25% phần thưởng thám hiểm Inazuma
  20 giờ.

**Cung mệnh (Constellation)**

1. **To Cloister Compassion** — Burst tăng phạm vi 50%.
2. **To Forsake Fortune** — Sanctifying Ring kéo dài thêm 3s.
3. **To Sequester Sorrow** — tăng cấp kỹ năng thêm 3.
4. **To Sever Sealing** — đòn thường/nặng/nhảy của người trong vòng
   Sanctifying Ring gây thêm Electro DMG AoE = 9.7% Max HP Shinobu (1
   lần/5s).
5. **To Cease Courtesies** — tăng cấp Burst thêm 3.
6. **To Ward Weakness** — tránh 1 lần tử vong khi HP về 1 (1 lần/60s); khi
   HP <25%, nhận 150 EM trong 15s (1 lần/60s).

**Gợi ý đội hình Trầm Thủy**: Support hồi máu + sát thương Electro theo %
Max HP, build HP thay vì Crit, phù hợp đội cần dùng nguyên tố Electro liên
tục mà không cần đứng sân lâu. Combo phổ biến: Quá Tải (Electro-Pyro)
Bennett-Xiangling, hoặc Cảm Ứng Siêu Dẫn/tán xạ với Kaeya/Ayaka.

---

### Shikanoin Heizou

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Anemo (Phong) | Đồng | 4★ | Inazuma | 2022-07-12 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 894 | 19 | 57 |
| 90 (đột phá 6) | 10663 | 225 | 684 |

Chỉ số đột phá phụ: **Anemo DMG Bonus +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Fudou Style Martial Arts**: đấm quyền tối đa 5 đòn gây
  Anemo DMG; đòn nặng đá quét gây Anemo DMG.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 37.5% | 67.5% |
  | 5-Hit | 61.4% | 110.6% |
  | Đòn nặng | 73.0% | 131.4% |

- **Kỹ năng nguyên tố — Heartstopper Strike** (CD 10s, không tốn năng
  lượng): bấm tung đòn Anemo DMG; giữ để tích lớp Declension tăng sát
  thương đòn kế (tối đa 4 lớp, mỗi lớp tồn tại 60s), đủ 4 lớp có thêm hiệu
  ứng Conviction. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 227.5% | 409.5% | 483.5% |
  | Bonus/lớp Declension | 56.9% | 102.4% | 120.9% |
  | Bonus Conviction (đủ 4 lớp) | 113.8% | 204.8% | 241.7% |

- **Bùng nổ nguyên tố — Windmuster Kick** (CD 12s, 40 năng lượng): nhảy lên
  đá tạo Vacuum Slugger nổ tung hút địch gây AoE Anemo DMG; nếu trúng địch
  dính Hydro/Pyro/Cryo/Electro sẽ gắn Windmuster Iris nổ theo nguyên tố đó.
  Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Vacuum Slugger DMG | 314.7% | 566.4% | 668.7% |
  | Windmuster Iris DMG | 21.5% | 38.6% | 45.6% |

- **Passive 1 — Paradoxical Practice**: kích hoạt Xoáy Cuốn on-field cho 1
  lớp Declension (1 lần/0.1s).
- **Passive 2 — Penetrative Reasoning**: Heartstopper Strike trúng địch,
  đồng đội (trừ Heizou) +80 EM trong 10s.
- **Passive 3 — Pre-Existing Guilt**: giảm 20% tiêu hao Thể lực khi chạy
  cho cả đội.

**Cung mệnh (Constellation)**

1. **Named Juvenile Casebook** — vào sân 5s đầu +15% tốc đánh thường, nhận
   1 lớp Declension (1 lần/10s).
2. **Investigative Collection** — Windmuster Kick hút mạnh hơn, kéo dài
   thêm 1s.
3. **Esoteric Puzzle Book** — tăng cấp Heartstopper Strike thêm 3.
4. **Tome of Lies** — nổ Windmuster Iris đầu tiên hồi 9 NL, mỗi nổ sau hồi
   thêm 1.5 NL (tối đa 13.5 NL/lượt).
5. **Secret Archive** — tăng cấp Windmuster Kick thêm 3.
6. **Curious Casefiles** — mỗi lớp Declension +4% Crit Rate cho
   Heartstopper Strike; khi có Conviction, +32% Crit DMG.

**Gợi ý đội hình Trầm Thủy**: Sub-DPS/hỗ trợ Xoáy Cuốn + cấp EM cho cả
đội, burst gây sát thương AoE tốt với chi phí năng lượng thấp. Combo phổ
biến: đội Xoáy Cuốn EM cao (Anemo-Electro/Anemo-Pyro) hoặc đi cùng Traveler
Anemo để tối ưu lan nguyên tố.

---

### Kirara

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Dendro (Thảo) | Kiếm 1 tay | 4★ | Inazuma | 2023-05-22 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1021 | 19 | 46 |
| 90 (đột phá 6) | 12186 | 223 | 546 |

Chỉ số đột phá phụ: **HP% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Boxcutter**: chém tối đa 4 đòn; đòn nặng tung 3 nhát vuốt
  nhanh.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 47.9% | 94.7% |
  | 4-Hit | 73.3% | 144.8% |

- **Kỹ năng nguyên tố — Meow-teor Kick** (CD 8–12s): nhảy đá gây AoE Dendro
  DMG và tạo Shield of Safe Transport (hấp thụ Dendro DMG hiệu quả hơn
  250%, theo Max HP), có chế độ Urgent Neko Parcel lao thẳng gây sát thương
  liên tục. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương đá | 104.0% | 187.2% | 221.0% |
  | Khiên hấp thụ | 10.0% MaxHP+962 | 18.0% MaxHP+2117 | 21.2% MaxHP+2646 |
  | Khiên tối đa | 16.0% MaxHP+1541 | 28.8% MaxHP+3391 | 34.0% MaxHP+4238 |

- **Bùng nổ nguyên tố — Secret Art: Surprise Dispatch** (CD 15s, 60 năng
  lượng): ném gói hàng gây AoE Dendro DMG rồi tách thành nhiều Cat Grass
  Cardamom nổ khi chạm địch hoặc hết giờ. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 570.2% | 1026.4% | 1211.8% |
  | Nổ Cardamom | 35.6% | 64.2% | 75.7% |

- **Passive 1 — Bewitching, Betwitching Tails**: trong Urgent Neko Parcel,
  mỗi lần va trúng địch tích 1 lớp Reinforced Packaging (tối đa 3), hết
  trạng thái mỗi lớp tạo 1 khiên phụ (20% hấp thụ so với khiên gốc).
- **Passive 2 — Pupillary Variance**: mỗi 1000 Max HP +0.4% DMG Meow-teor
  Kick và +0.3% DMG Surprise Dispatch.
- **Passive 3 — Cat's Creeping Carriage**: không làm giật mình gia cầm/thịt
  sống khi có Kirara trong đội.

**Cung mệnh (Constellation)**

1. **Material Circulation** — mỗi 8000 Max HP tạo thêm 1 Cardamom khi dùng
   Burst (tối đa +4).
2. **Perfectly Packaged** — trong Urgent Neko Parcel, va trúng đồng đội cấp
   Critical Transport Shield (40% khiên tối đa, hấp thụ Dendro 250%).
3. **Universal Recognition** — tăng cấp Meow-teor Kick thêm 3.
4. **Steed of Skanda** — người có khiên Kirara đánh trúng địch sẽ kích hoạt
   đòn phối hợp Cardamom nhỏ 200% ATK Kirara (1 lần/3.8s, dùng chung CD toàn
   đội).
5. **A Thousand Miles in a Day** — tăng cấp Burst thêm 3.
6. **Countless Sights to See** — dùng kỹ năng/Burst xong, đồng đội gần đó
   +12% All Elemental DMG Bonus trong 15s.

**Gợi ý đội hình Trầm Thủy**: Hỗ trợ khiên Dendro + kích hoạt phản ứng
Dendro (Bùng Phát/Cháy Nổ/Kết Tinh Rêu) off-field, build HP. Combo phổ
biến: Bùng Phát Toả Hương (Dendro-Hydro-Electro/Pyro) hoặc đội cần khiên
liên tục thay Zhongli.

---

### Chiori

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Geo (Nham) | Kiếm 1 tay | 5★ | Inazuma | 2024-03-11 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 890 | 25 | 74 |
| 90 (đột phá 6) | 11437 | 323 | 953 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Weaving Blade**: chém tối đa 4 đòn; đòn nặng tung 2 nhát
  kiếm nhanh.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 49.4% | 97.7% |
  | 4-Hit | 75.1% | 148.5% |
  | Đòn nặng (2 nhát) | 54.3%+54.3% | 107.4%+107.4% |

- **Kỹ năng nguyên tố — Fluttering Hasode** (CD 16s, không tốn năng
  lượng): lướt tới rồi triệu hồi automaton "Tamoto" chém quét gây AoE Geo
  DMG theo cả ATK và DEF; Tamoto tự đánh định kỳ trong thời gian tồn tại.
  Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Tamoto DMG | 82.1% ATK+102.6% DEF | 147.7% ATK+184.7% DEF | 174.4% ATK+218.0% DEF |
  | Đòn quét lên | 149.3% ATK+186.6% DEF | 268.7% ATK+335.9% DEF | 317.2% ATK+396.5% DEF |
  | Thời lượng Tamoto | 17.0s | 17.0s | 17.0s |

- **Bùng nổ nguyên tố — Hiyoku: Twin Blades** (CD 13.5s, 50 năng lượng):
  song kiếm tung chiêu gây AoE Geo DMG theo cả ATK và DEF. Cấp kỹ năng được
  C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 256.3% ATK+320.4% DEF | 461.4% ATK+576.7% DEF | 544.7% ATK+680.9% DEF |

- **Passive 1 — Tailor-Made**: sau đòn quét lên của Hasode, bấm kỹ năng để
  đổi người + cấp "Seize the Moment" (tăng DMG đòn tiếp theo), hoặc bấm đòn
  thường để kích hoạt "Tailoring".
- **Passive 2 — The Finishing Touch**: đồng đội tạo kết cấu Geo giúp Chiori
  +20% Geo DMG Bonus trong 20s.
- **Passive 3 — Brocaded Collar's Beauteous Silhouette**: đồng đội mặc
  trang phục/dù khác mặc định được +10% tốc di chuyển (không áp dụng trong
  Trầm Thủy).

**Cung mệnh (Constellation)**

1. **Six Paths of Sage Silkcraft** — phạm vi Tamoto +50%; nếu có Geo khác
   trong đội, Hasode triệu hồi thêm 1 Tamoto và kích hoạt luôn passive The
   Finishing Touch.
2. **In Five Colors Dyed** — sau Burst 10s, cứ 3s triệu hồi automaton "Kinu"
   gây 170% sát thương Tamoto (tính là DMG kỹ năng).
3. **Four Brocade Embellishments** — tăng cấp Hasode thêm 3.
4. **A Tailor's Three Courtesies** — sau hiệu ứng Tailor-Made, đòn
   thường/nặng/nhảy trúng địch triệu hồi Kinu gần đó (tối đa 3/lượt, 1
   lần/15s).
5. **Two Silken Plumules** — tăng cấp Burst thêm 3.
6. **Sole Principle Pursuit** — sau hiệu ứng Tailor-Made, giảm CD Hasode
   12s; đòn thường +235% DEF vào sát thương.

**Gợi ý đội hình Trầm Thủy**: DPS/sub-DPS Geo scale theo cả ATK và DEF, kết
hợp Zhongli/Gorou/Albedo để cộng dồn DEF và Geo DMG Bonus. Combo phổ biến:
mono-Geo hoặc Kết Tinh (Geo-Hydro/Geo-Electro) tận dụng passive Finishing
Touch.

---

### Yumemizuki Mizuki

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Anemo (Phong) | Đồng | 5★ | Inazuma | 2025-02-10 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 991 | 17 | 59 |
| 90 (đột phá 6) | 12735 | 215 | 757 |

Chỉ số đột phá phụ: **Tinh Thông Nguyên Tố (EM) +115.2** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Pure Heart, Pure Dreams**: 3 đòn Anemo DMG; đòn nặng tiêu
  Thể lực gây AoE Anemo DMG.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 52.3% | 94.1% |
  | 3-Hit | 71.4% | 128.5% |
  | Đòn nặng | 130.0% | 234.0% |

- **Kỹ năng nguyên tố — Aisa Utamakura Pilgrimage** (CD 15s, không tốn
  năng lượng): vào trạng thái Dreamdrifter bay lơ lửng, liên tục gây AoE
  Anemo DMG; sát thương Xoáy Cuốn/Xoáy Cuốn Sao được khuếch đại theo EM.
  Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 57.7% | 103.9% | 122.7% |
  | Sát thương liên tục | 44.9% | 80.8% | 95.4% |
  | Tăng DMG Xoáy Cuốn /100 EM | 18.00% | 45.00% | 54.00% |
  | Tăng DMG Xoáy Cuốn Sao /100 EM | 1.80% | 4.50% | 5.40% |

- **Bùng nổ nguyên tố — Anraku Secret Spring Therapy** (CD 15s, 60 năng
  lượng): hút địch gây AoE Anemo DMG và triệu hồi Mini Baku thả Yumemi
  Style Special Snack — đồng đội HP >70% nhặt sẽ nổ Munen Shockwave gây
  Anemo DMG, HP thấp thì hồi máu theo EM. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 94.1% | 169.3% | 199.9% |
  | Munen Shockwave DMG | 70.6% | 127.0% | 149.9% |
  | Hồi máu khi nhặt (HP thấp) | 130.6% EM+315 | 235.0% EM+692 | 277.4% EM+865 |

- **Passive 1 — Bright Moon's Restless Voice**: kích hoạt Xoáy Cuốn/Xoáy
  Cuốn Sao trong Dreamdrifter kéo dài trạng thái thêm 2.5s (tối đa 2
  lần/lượt).
- **Passive 2 — Thoughts by Day Bring Dreams by Night**: trong
  Dreamdrifter, đồng đội gây Pyro/Hydro/Cryo/Electro DMG giúp Mizuki +100
  EM trong 4s.
- **Passive 3 — All Ailments Banished**: đồ ăn hồi máu (không hồi sinh) có
  cơ hội hồi thêm 30% HP.
- **Passive 4 (mặc định) — Vast Be the Dream**: kích hoạt Xoáy Cuốn/Xoáy
  Cuốn Sao trong Dreamdrifter khiến đòn AoE định kỳ tiếp theo +1000% EM
  (1 lần/2.5s); nếu là Xoáy Cuốn Sao, gây thêm 1 đòn Anemo DMG riêng 1000%
  EM.

**Cung mệnh (Constellation)**

1. **In Mist-Like Waters** — trong Dreamdrifter, gắn hiệu ứng lên địch mỗi
   3.5s; Xoáy Cuốn/Xoáy Cuốn Sao xảy ra trong lúc đó gây thêm 1100%/550% EM.
2. **Your Echo I Meet in Dreams** — vào Dreamdrifter, mỗi điểm EM +0.04%
   Pyro/Hydro/Cryo/Electro DMG Bonus cho cả đội đến khi hết trạng thái.
3. **Till Dawn's Moon Ends Night** — tăng cấp kỹ năng thêm 3.
4. **Buds Warm Lucid Springs** — nhặt Snack từ Burst hồi thêm 5 năng lượng
   (tối đa 4 lần/lượt Burst).
5. **As Setting Moon Brings Year's End** — tăng cấp Burst thêm 3.
6. **The Heart Lingers Long** — trong Dreamdrifter, sát thương Xoáy Cuốn
   của đồng đội có thể chí mạng (Crit Rate cố định 30%, Crit DMG 100%); Xoáy
   Cuốn Sao +10%/+20% Crit Rate/DMG.

**Gợi ý đội hình Trầm Thủy**: Support/sub-DPS Anemo scale theo EM, kích hoạt
và khuếch đại Xoáy Cuốn liên tục trong lúc bay Dreamdrifter. Combo phổ
biến: đội Xoáy Cuốn EM cao (Anemo-Electro/Anemo-Dendro Catalyze) hoặc thay
thế Kazuha/Sucrose làm gom quái kiêm buff sát thương.

---

## Fontaine

### Lynette

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Anemo (Phong) | Kiếm 1 tay | 4★ | Fontaine | 2023-08-14 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1039 | 19 | 60 |
| 90 (đột phá 6) | 12404 | 232 | 712 |

Chỉ số đột phá phụ: **Anemo DMG Bonus +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Rapid Ritesword**: chém tối đa 4 đòn; đòn nặng tung 2 nhát
  kiếm nhanh.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 43.1% | 85.2% |
  | 4-Hit | 63.2% | 124.8% |
  | Đòn nặng (2 nhát) | 44.2%+61.4% | 87.4%+121.4% |

- **Kỹ năng nguyên tố — Enigmatic Feint** (CD 12s, không tốn năng lượng):
  bấm để tung Enigma Thrust gây Anemo DMG, hồi máu theo Max HP nhưng mất
  máu dần 4s sau; giữ để vào Pilfering Shadow di chuyển nhanh. Cấp kỹ năng
  được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Enigma Thrust DMG | 268.0% | 482.4% | 569.5% |
  | Surging Blade DMG | 31.2% | 56.2% | 66.3% |
  | Hồi máu | 25.0% MaxHP | 25.0% MaxHP | 25.0% MaxHP |

- **Bùng nổ nguyên tố — Magic Trick: Astonishing Shift** (CD 18s, 70 năng
  lượng): gây AoE Anemo DMG rồi triệu hồi Bogglecat Box hút thù, tự động
  tấn công; khi chạm Hydro/Pyro/Cryo/Electro sẽ nhiễm nguyên tố đó và bắn
  Vivid Shot theo nguyên tố. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 83.2% | 149.8% | 176.8% |
  | Bogglecat Box DMG | 51.2% | 92.2% | 108.8% |
  | Vivid Shot DMG | 45.6% | 82.1% | 96.9% |

- **Passive 1 — Sophisticated Synergy**: sau Burst 10s, càng nhiều nguyên
  tố khác nhau trong đội (1–4) thì cả đội càng +8/12/16/20% ATK.
- **Passive 2 — Props Positively Prepped**: Bogglecat Box đổi nguyên tố
  xong, Burst của Lynette +15% DMG đến hết thời lượng box.
- **Passive 3 — Loci-Based Mnemonics**: hiện Recovery Orb trên minimap,
  +25% Thể lực/HP nhận từ orb.

**Cung mệnh (Constellation)**

1. **A Cold Blade Like a Shadow** — Enigma Thrust trúng địch có
   Shadowsign tạo xoáy hút địch gần đó.
2. **Endless Mysteries** — Bogglecat Box bắn thêm 1 Vivid Shot mỗi lần bắn.
3. **Cognition-Inverting Gaze** — tăng cấp Astonishing Shift thêm 3.
4. **Tacit Coordination** — Enigmatic Feint +1 lượt tích.
5. **Obscuring Ambiguity** — tăng cấp Enigmatic Feint thêm 3.
6. **Watchful Eye** — dùng Enigma Thrust nhận Anemo Infusion + 20% Anemo
   DMG Bonus trong 6s.

**Gợi ý đội hình Trầm Thủy**: Support Xoáy Cuốn/gom quái kiêm buff ATK toàn
đội đa nguyên tố (thường đi cặp với Lyney/Freminet). Combo phổ biến: đội 4
nguyên tố (Lyney-Lynette-Freminet + 1 hỗ trợ) hoặc Xoáy Cuốn Anemo-Pyro/
Anemo-Cryo.

---

### Lyney

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Pyro (Hoả) | Cung | 5★ | Fontaine | 2023-08-14 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 858 | 25 | 42 |
| 90 (đột phá 6) | 11021 | 318 | 538 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Card Force Translocation**: bắn cung tối đa 4 phát; đòn
  nặng bắn Prop Arrow tốn 20% Max HP, triệu hồi Grin-Malkin Hat (kế thừa HP
  theo % ATK) tự bắn Pyrotechnic Strike và Spiritbreath Thorn định kỳ. Cấp
  kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | 1-Hit | 38.8% | 76.7% | 92.9% |
  | Prop Arrow DMG | 172.8% | 311.0% | 367.2% |
  | Pyrotechnic Strike (Hat tự bắn) | 212.0% | 381.6% | 450.5% |
  | Tiêu hao | 20.0% MaxHP | 20.0% MaxHP | 20.0% MaxHP |

- **Kỹ năng nguyên tố — Bewildering Lights** (CD 15s, không tốn năng
  lượng): xoá hết lớp Prop Surplus để gây AoE Pyro DMG (tăng theo số lớp
  xoá) và hồi máu theo % Max HP/lớp; nếu có Grin-Malkin Hat trên sân sẽ kích
  nổ luôn.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Sát thương kỹ năng | 167.2% | 301.0% |
  | Bonus/lớp Prop Surplus | 53.2% ATK | 95.8% ATK |
  | Hồi máu/lớp | 20.0% | 20.0% |

  *Bewildering Lights không có cung mệnh tăng cấp — tối đa cấp 10.*

- **Bùng nổ nguyên tố — Wondrous Trick: Miracle Parade** (CD 15s, 60 năng
  lượng): biến thành Grin-Malkin Cat gây Pyro DMG khi áp sát địch; hết giờ
  nổ pháo hoa AoE Pyro DMG, triệu hồi 1 Hat và +1 lớp Prop Surplus. Cấp kỹ
  năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 154.0% | 277.2% | 327.2% |
  | Nổ pháo hoa | 414.0% | 745.2% | 879.8% |

- **Passive 1 — Perilous Performance**: Prop Arrow tốn HP, Hat trúng địch
  hồi 3 NL và +80% ATK vào sát thương.
- **Passive 2 — Conclusive Ovation**: sát thương lên địch dính Pyro +60%,
  mỗi thành viên Pyro khác (trừ Lyney) +20% (tối đa +100%).
- **Passive 3 — Trivial Observations**: hiện tài nguyên đặc thù Fontaine
  trên minimap.

**Cung mệnh (Constellation)**

1. **Whimsical Wonders** — tối đa 2 Hat cùng lúc; Prop Arrow triệu hồi 2
   Hat và +1 lớp Prop Surplus (1 lần/15s).
2. **Loquacious Cajoling** — on-field cứ 2s tích 1 lớp Crisp Focus (+20%
   Crit DMG/lớp, tối đa 3 lớp).
3. **Prestidigitation** — tăng cấp đòn thường thêm 3.
4. **Well-Versed, Well-Rehearsed** — đòn nặng Pyro trúng địch giảm 20%
   Pyro RES trong 6s.
5. **To Pierce Enigmas** — tăng cấp Burst thêm 3.
6. **Guarded Smile** — bắn Prop Arrow kèm theo Pyrotechnic Strike phụ 80%
   sát thương gốc.

**Gợi ý đội hình Trầm Thủy**: DPS chính Pyro dạng "on-field ngắn, off-field
đánh hộ" qua Grin-Malkin Hat, cực mạnh khi có nhiều nguyên tố Pyro hỗ trợ.
Combo phổ biến: đội 4 nguyên tố cùng Lynette/Freminet, hoặc Tan chảy
(Pyro-Cryo)/Bốc hơi (Pyro-Hydro).

---

### Freminet

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Cryo (Băng) | Đại kiếm | 4★ | Fontaine | 2023-09-05 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1012 | 21 | 59 |
| 90 (đột phá 6) | 12077 | 255 | 709 |

Chỉ số đột phá phụ: **ATK% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Flowing Eddies**: chém tối đa 4 đòn; đòn nặng xoay liên
  tục hao Thể lực rồi kết đòn mạnh. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | 1-Hit | 84.2% | 166.5% | 201.8% |
  | 4-Hit | 123.8% | 244.7% | 296.6% |
  | Đòn nặng kết thúc | 113.1% | 223.6% | 270.9% |

- **Kỹ năng nguyên tố — Pressurized Floe** (CD 10s, không tốn năng lượng):
  đâm lên gây Cryo DMG, vào Pers Timer 10s biến kỹ năng thành Shattering
  Pressure — sát thương và tỉ lệ Cryo/Vật lý thay đổi theo Pressure Level
  (0–4) tích được từ đòn thường trong lúc chờ. Cấp kỹ năng được C5 tăng
  thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Đâm lên | 83.0% | 149.5% | 176.5% |
  | Shattering Pressure Lv0 | 200.5% | 360.9% | 426.0% |
  | Shattering Pressure Lv4 | 243.4% | 438.2% | 517.3% |

- **Bùng nổ nguyên tố — Shadowhunter's Ambush** (CD 15s, 60 năng lượng):
  gây AoE Cryo DMG, reset CD kỹ năng và vào Subnautical Hunter 10s (giảm
  70% CD kỹ năng, đòn thường tăng Pressure Level nhanh hơn).

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Sát thương kỹ năng | 318.4% | 573.1% |
  | Thời lượng | 10.0s | 10.0s |

  *Shadowhunter's Ambush không có cung mệnh tăng cấp — tối đa cấp 10.*

- **Passive 1 — Saturation Deep Dive**: dùng Shattering Pressure khi chưa
  đạt Level 4 giảm CD kỹ năng 1s.
- **Passive 2 — Parallel Condensers**: kích hoạt Kết Băng (Shatter) tăng
  40% DMG Shattering Pressure trong 5s.
- **Passive 3 — Deepwater Navigation**: giảm 35% tiêu hao Thể lực khi bơi
  cho cả đội.

**Cung mệnh (Constellation)**

1. **Dreams of the Foamy Deep** — Shattering Pressure +15% Crit Rate.
2. **Penguins and the Land of Plenty** — dùng Shattering Pressure hồi 2 NL
   (3 NL nếu ở Level 4).
3. **Song of the Eddies and Bleached Sands** — tăng cấp đòn thường thêm 3.
4. **Dance of the Snowy Moon and Flute** — kích hoạt Đóng Băng/Kết
   Băng/Cảm Ứng Siêu Dẫn +9% ATK trong 6s (tối đa 2 lớp).
5. **Nights of Hearth and Happiness** — tăng cấp Pressurized Floe thêm 3.
6. **Moment of Waking and Resolve** — kích hoạt các phản ứng trên +12%
   Crit DMG trong 6s (tối đa 3 lớp).

**Gợi ý đội hình Trầm Thủy**: Sub-DPS Cryo linh hoạt (Vật lý + Cryo pha
trộn), mạnh nhất khi giữ Pressure Level cao trước khi tung Shattering
Pressure. Combo phổ biến: Đóng băng (Cryo-Hydro) hoặc Kết Băng/Siêu Dẫn với
Electro để tận dụng passive tăng ATK/Crit DMG.

---

### Neuvillette

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Hydro (Thuỷ) | Đồng | 5★ | Fontaine | 2023-09-25 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1144 | 16 | 45 |
| 90 (đột phá 6) | 14695 | 208 | 576 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit DMG) +38.4%** ở cấp 90 (HP cao
nhất trò chơi ở cấp 90).

**Bộ kỹ năng**

- **Đòn thường — As Water Seeks Equilibrium**: 3 đòn Hydro DMG; giữ đòn
  nặng để tích Seal of Arbitration (hấp thụ Sourcewater Droplet quanh mình,
  hồi máu), thả ra gây Equitable Judgment theo % Max HP. Cấp kỹ năng được
  C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | 1-Hit | 54.6% | 98.2% | 116.0% |
  | Equitable Judgment (%MaxHP) | 7.32% | 14.47% | 17.53% |
  | Hồi máu/droplet | 16.0% MaxHP | 16.0% MaxHP | 16.0% MaxHP |

- **Kỹ năng nguyên tố — O Tears, I Shall Repay** (CD 12s, không tốn năng
  lượng): triệu hồi thác nước gây AoE Hydro DMG theo % Max HP, tạo 3
  Sourcewater Droplet.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Sát thương kỹ năng (%MaxHP) | 12.86% | 23.16% |
  | Spiritbreath Thorn DMG | 20.8% | 37.4% |

  *Kỹ năng không có cung mệnh tăng cấp — tối đa cấp 10.*

- **Bùng nổ nguyên tố — O Tides, I Have Returned** (CD 18s, 70 năng
  lượng): gây AoE Hydro DMG theo % Max HP, sau đó 2 thác nước nhỏ hơn giáng
  xuống tạo 6 Sourcewater Droplet. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng (%MaxHP) | 22.26% | 40.06% | 47.30% |
  | Thác nước phụ (%MaxHP) | 9.11% | 16.39% | 19.35% |

- **Passive 1 — Heir to the Ancient Sea's Authority**: đồng đội kích hoạt
  Bốc Hơi/Đóng Băng/Cảm Ứng Điện/Bùng Phát/Xoáy Cuốn Hydro/Kết Tinh Hydro
  cấp 1 lớp Past Draconic Glories (tối đa 3, mỗi lớp 30s) — Equitable
  Judgment DMG +110%/125%/160% tuỳ số lớp.
- **Passive 2 — Discipline of the Supreme Arbitration**: mỗi 1% HP hiện
  tại vượt 30% Max HP cho +0.6% Hydro DMG Bonus (tối đa +30%).
- **Passive 3 — Gather Like the Tide**: +15% tốc bơi dưới nước cho cả đội.

**Cung mệnh (Constellation)**

1. **Venerable Institution** — vào sân nhận ngay 1 lớp Past Draconic
   Glories; tăng kháng ngắt chiêu khi tích/thả đòn nặng.
2. **Juridical Exhortation** — mỗi lớp Past Draconic Glories +14% Crit DMG
   cho Equitable Judgment (tối đa +42%).
3. **Ancient Postulation** — tăng cấp đòn thường thêm 3.
4. **Crown of Commiseration** — Neuvillette on-field được hồi máu sẽ tạo
   thêm 1 Sourcewater Droplet (1 lần/4s).
5. **Axiomatic Judgment** — tăng cấp Burst thêm 3.
6. **Wrathful Recompense** — đòn nặng hút Droplet gần đó kéo dài thời gian,
   mỗi 2s bắn thêm 2 dòng nước phụ 10% Max HP Hydro DMG.

**Gợi ý đội hình Trầm Thủy**: DPS chính Hydro scale hoàn toàn theo Max HP,
gần như không cần Crit ban đầu (né info Crit DMG đột phá vẫn hữu ích khi đã
no HP). Combo phổ biến: Bốc Hơi/Đóng Băng với Bennett/Xiangling hoặc
Kokomi/Chevreuse để vừa buff Hydro DMG vừa cấp Droplet.

---

### Wriothesley

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Cryo (Băng) | Đồng | 5★ | Fontaine | 2023-10-17 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1058 | 24 | 59 |
| 90 (đột phá 6) | 13592 | 311 | 763 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit DMG) +38.4%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Forceful Fists of Frost**: đấm tối đa 5 đòn Cryo DMG; đòn
  nặng nhảy lên tung Vaulting Fist AoE. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | 1-Hit | 53.4% | 105.5% | 127.8% |
  | 5-Hit | 90.7% | 179.4% | 217.4% |
  | Đòn nặng | 153.0% | 275.3% | 325.0% |

- **Kỹ năng nguyên tố — Icefang Rush** (CD 16s, không tốn năng lượng): lao
  tới vào trạng thái Chilling Penalty (tăng kháng ngắt chiêu; nếu HP >50%,
  tăng sát thương Repelling Fists nhưng tiêu HP mỗi lần trúng).

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Repelling Fist tăng cường (%ST đòn thường) | 143.2% | 170.3% |
  | Tiêu HP | 4.5% MaxHP | 4.5% MaxHP |
  | Thời lượng | 10.0s | 10.0s |

  *Icefang Rush không có cung mệnh tăng cấp — tối đa cấp 10.*

- **Bùng nổ nguyên tố — Darkgold Wolfbite** (CD 15s, 60 năng lượng): đấm
  băng thẳng rồi Icicle Impact gây nhiều đợt AoE Cryo DMG, sau đó Surging
  Blade giáng xuống thêm sát thương. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng (×5 đợt) | 127.20% | 228.96% | 270.30% |
  | Surging Blade DMG | 42.40% | 76.32% | 90.10% |

- **Passive 1 — There Shall Be a Plea for Justice**: HP <60% nhận Gracious
  Rebuke, đòn nặng kế tiếp không tốn Thể lực, +50% DMG, hồi 30% Max HP khi
  trúng (1 lần/5s).
- **Passive 2 — There Shall Be a Reckoning for Sin**: trong Chilling
  Penalty, HP thay đổi tích 1 lớp Prosecution Edict (tối đa 5, mỗi lớp +6%
  ATK).
- **Passive 3 — The Duke's Grace**: 10% cơ hội nhân đôi nguyên liệu đột
  phá vũ khí khi chế tạo.

**Cung mệnh (Constellation)**

1. **Terror for the Evildoers** — đổi điều kiện Gracious Rebuke (đòn 5
   Repelling Fists khi HP<60% hoặc trong Chilling Penalty, 1 lần/2.5s);
   Rebuke: Vaulting Fist +200% DMG và kéo dài Chilling Penalty 4s khi trúng.
2. **Shackles for the Arrogant** — mỗi lớp Prosecution Edict +40% DMG
   Darkgold Wolfbite.
3. **Punishment for the Frauds** — tăng cấp đòn thường thêm 3.
4. **Redemption for the Suffering** — Rebuke: Vaulting Fist hồi 50% Max HP;
   hồi máu dư thừa cấp tốc đánh +20% (on-field) hoặc +10% cả đội (off-field)
   trong vài giây.
5. **Mercy for the Wronged** — tăng cấp Burst thêm 3.
6. **Esteem for the Innocent** — Rebuke: Vaulting Fist +10% Crit Rate,
   +80% Crit DMG, tạo thêm 1 mảnh băng phụ 100% sát thương gốc.

**Gợi ý đội hình Trầm Thủy**: DPS/sub-DPS Cryo chơi quanh vùng HP thấp để
kích Gracious Rebuke liên tục, cần nguồn sát thương/tự trừ máu hỗ trợ. Combo
phổ biến: Đóng băng (Cryo-Hydro) với Kokomi/Yelan hoặc Kết Băng-Siêu Dẫn với
Electro.

---

### Charlotte

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Cryo (Băng) | Đồng | 4★ | Fontaine | 2023-11-06 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 903 | 15 | 46 |
| 90 (đột phá 6) | 10772 | 173 | 546 |

Chỉ số đột phá phụ: **ATK% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Cool-Color Capture**: chụp ảnh tối đa 3 đòn Cryo DMG;
  đòn nặng gây AoE Cryo DMG sau khi chuẩn bị.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 49.8% | 89.7% |
  | 3-Hit | 64.6% | 116.3% |
  | Đòn nặng | 100.5% | 180.9% |

- **Kỹ năng nguyên tố — Framing: Freezing Point Composition** (CD 12s,
  không tốn năng lượng): bấm để chụp gây AoE Cryo DMG + đánh dấu Snappy
  Silhouette (tự nổ Cryo DMG định kỳ); giữ để vào Composition Mode. Cấp kỹ
  năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Photo DMG (bấm) | 67.2% | 121.0% | 142.8% |
  | Photo DMG (giữ) | 139.2% | 250.6% | 295.8% |
  | Snappy Silhouette (mỗi nhịp) | 39.2% | 70.6% | 83.3% |

- **Bùng nổ nguyên tố — Still Photo: Comprehensive Confirmation** (CD 20s,
  80 năng lượng): tạo Newsflash Field gây AoE Cryo DMG định kỳ và hồi máu
  liên tục cho đồng đội gần đó theo ATK Charlotte. Cấp kỹ năng được C3 tăng
  thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Hồi máu khi cast | 256.6% ATK+1609 | 461.8% ATK+3539 | 545.2% ATK+4424 |
  | Sát thương kỹ năng | 77.6% | 139.7% | 164.9% |
  | Hồi máu liên tục/nhịp | 9.2% ATK+57 | 16.6% ATK+126 | 19.6% ATK+158 |

- **Passive 1 — Moment of Impact**: hạ gục địch đánh dấu Focused
  Impression giảm CD kỹ năng 2s (tối đa 4 lần/12s).
- **Passive 2 — Diversified Investigation**: đội có 1/2/3 người Fontaine
  khác cho +5/10/15% Healing Bonus; có 1/2/3 người không phải Fontaine cho
  +5/10/15% Cryo DMG Bonus.
- **Passive 3 — First-Person Shutter**: Kích Hoạt ống kính đặc biệt thay
  đổi hiệu ứng giữ nút kỹ năng.

**Cung mệnh (Constellation)**

1. **A Need to Verify Facts** — Burst hồi máu ai đó sẽ đánh dấu hồi thêm
   80% ATK mỗi 2s trong 6s.
2. **A Duty to Pursue Truth** — Framing trúng 1/2/3+ địch cho Charlotte
   +10/20/30% ATK trong 12s.
3. **An Imperative to Independence** — tăng cấp Burst thêm 3.
4. **A Responsibility to Oversee** — Burst trúng địch đánh dấu +10% DMG và
   hồi 2 NL (tối đa 5 lần/20s).
5. **A Principle of Conscience** — tăng cấp Framing thêm 3.
6. **A Summation of Interest** — đòn thường/nặng trúng địch đánh dấu
   Focused Impression kích đòn phối hợp 180% ATK AoE Cryo DMG + hồi 42% ATK
   (1 lần/6s, tính là DMG Burst).

**Gợi ý đội hình Trầm Thủy**: Hỗ trợ hồi máu + Cryo DMG off-field, rất linh
hoạt cho đội cần cả khiên/hồi máu lẫn tráng Cryo. Combo phổ biến: Đóng băng
(Cryo-Hydro) hoặc Tan chảy (Cryo-Pyro), thường thay thế Bennett/Kokomi khi
cần thêm Cryo.

---

### Furina

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Hydro (Thuỷ) | Kiếm 1 tay | 5★ | Fontaine | 2023-11-06 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1192 | 19 | 54 |
| 90 (đột phá 6) | 15307 | 244 | 696 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Soloist's Solicitation**: chém tối đa 4 đòn; đòn nặng múa
  đơn gây sát thương Vật lý AoE và đổi Arkhe alignment.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 48.4% | 95.6% |
  | 4-Hit | 73.3% | 144.9% |
  | Đòn nặng | 74.2% | 146.7% |

- **Kỹ năng nguyên tố — Salon Solitaire** (CD 20s, không tốn năng lượng):
  tuỳ Arkhe hiện tại, triệu hồi 3 Salon Member tự tấn công gây Hydro DMG
  theo Max HP (Ousia) hoặc Singer of Many Waters hồi máu theo Max HP
  (Pneuma). Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số (Ousia) | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Bong bóng nổ (%MaxHP) | 7.9% | 14.2% | 16.7% |
  | Mademoiselle Crabaletta (%MaxHP) | 8.29% | 14.92% | 17.61% |
  | Singer hồi máu (Pneuma) | 4.80% MaxHP+462 | 8.64% MaxHP+1017 | 10.20% MaxHP+1271 |

- **Bùng nổ nguyên tố — Let the People Rejoice** (CD 15s, 60 năng lượng):
  gây AoE Hydro DMG theo % Max HP, đưa đồng đội vào Universal Revelry — HP
  đồng đội thay đổi tích điểm Fanfare cho Furina, Fanfare quy đổi thành DMG
  Bonus và Incoming Healing Bonus cho cả đội. Cấp kỹ năng được C3 tăng
  thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng (%MaxHP) | 11.4% | 20.5% | 24.2% |
  | Tỉ lệ Fanfare→DMG | 0.07% | 0.25% | 0.31% |
  | Tỉ lệ Fanfare→Healing Bonus | 0.01% | 0.10% | 0.13% |
  | Fanfare tối đa | 300 | 300 | 300 |

- **Passive 1 — Endless Waltz**: khi đồng đội được hồi máu dư thừa (không
  phải từ Furina), Furina hồi thêm 2% Max HP/2s cho đồng đội gần đó trong
  4s.
- **Passive 2 — Unheard Confession**: mỗi 1000 Max HP tăng 0.7% DMG Salon
  Member (tối đa +28%) và giảm 0.4% chu kỳ hồi máu Singer (tối đa −16%).
- **Passive 3 — The Sea Is My Stage**: giảm 30% CD kỹ năng Xenochromatic
  Fontemer Aberrant.

**Cung mệnh (Constellation)**

1. **"Love Is a Rebellious Bird..."** — dùng Burst nhận ngay 150 Fanfare;
   giới hạn Fanfare +100.
2. **"A Woman Adapts Like Duckweed..."** — trong Burst, Fanfare tích từ HP
   thay đổi +250%; mỗi điểm Fanfare vượt giới hạn +0.35% Max HP (tối đa
   +140%).
3. **"My Secret Is Hidden..."** — tăng cấp Burst thêm 3.
4. **"They Know Not Life..."** — Salon Member trúng địch hoặc Singer hồi
   máu cho Furina 4 NL (1 lần/5s).
5. **"His Name I Now Know..."** — tăng cấp Salon Solitaire thêm 3.
6. **"Hear Me — Let Us Raise the Chalice of Love!"** — dùng kỹ năng nhận
   "Center of Attention" 10s: đòn thường/nặng/nhảy chuyển hẳn Hydro DMG
   +18% Max HP sát thương, và tuỳ Arkhe hồi máu hoặc tăng sát thương thêm
   cho cả đội (tối đa 6 lần kích hoạt).

**Gợi ý đội hình Trầm Thủy**: Buffer sát thương toàn đội bậc nhất (qua
Fanfare) kiêm cấp HP khủng để chống chịu — gần như bắt buộc trong đội cần
%DMG bonus cực lớn. Combo phổ biến: bất kỳ đội DPS nào (Hydro-Pyro/Hydro-
Cryo) miễn có nguồn dao động HP để tích Fanfare nhanh.

---

### Navia

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Geo (Nham) | Đại kiếm | 5★ | Fontaine | 2023-12-18 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 985 | 27 | 62 |
| 90 (đột phá 6) | 12650 | 352 | 793 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit DMG) +38.4%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Blunt Refusal**: chém tối đa 4 đòn; đòn nặng xoay liên
  tục hao Thể lực rồi kết đòn mạnh.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 93.5% | 184.9% |
  | 4-Hit | 133.4% | 263.8% |
  | Đòn nặng kết thúc | 113.1% | 223.6% |

- **Kỹ năng nguyên tố — Ceremonial Crystalshot** (CD 9s, không tốn năng
  lượng): tích lớp Crystal Shrapnel khi có phản ứng Kết Tinh (tối đa 6 lớp,
  tồn tại 300s); khi bắn, tiêu hết lớp mở dù bắn nhiều viên đạn hoa hồng gây
  Geo DMG. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Rosula Shardshot (DMG gốc) | 394.8% | 710.6% | 839.0% |
  | Surging Blade DMG | 36.0% | 64.8% | 76.5% |

- **Bùng nổ nguyên tố — As the Sunlit Sky's Singing Salute** (CD 15s, 60
  năng lượng): bắn đại bác gây AoE Geo DMG rồi duy trì Cannon Fire Support
  bắn định kỳ; đại bác trúng địch cấp thêm lớp Crystal Shrapnel. Cấp kỹ
  năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 75.2% | 135.4% | 159.8% |
  | Cannon Fire Support DMG | 43.1% | 77.7% | 91.7% |
  | Thời lượng | 12.0s | 12.0s | 12.0s |

- **Passive 1 — Undisclosed Distribution Channels**: sau Ceremonial
  Crystalshot 4s, đòn thường/nặng/nhảy chuyển hẳn Geo DMG +40% DMG.
- **Passive 2 — Mutual Assistance Network**: mỗi thành viên
  Pyro/Electro/Cryo/Hydro cho +20% ATK (tối đa 2 lần = +40%).
- **Passive 3 — Painstaking Transaction**: +25% phần thưởng thám hiểm
  Fontaine 20 giờ.

**Cung mệnh (Constellation)**

1. **A Lady's Rules...** — mỗi lớp Crystal Shrapnel tiêu thụ hồi 3 NL và
   giảm CD Burst 1s (tối đa +9 NL/−3s).
2. **The President's Pursuit of Victory** — mỗi lớp tiêu thụ +12% Crit
   Rate cho phát bắn đó (tối đa +36%); trúng địch kích 1 phát Cannon Fire
   Support (tính DMG Burst).
3. **Businesswoman's Broad Vision** — tăng cấp kỹ năng thêm 3.
4. **The Oathsworn Never Capitulate** — Burst trúng địch giảm 20% Geo RES
   trong 8s.
5. **Negotiator's Resolute Negotiations** — tăng cấp Burst thêm 3.
6. **The Flexible Finesse...** — tiêu >3 lớp thì mỗi lớp vượt +45% Crit
   DMG cho phát bắn đó, lớp vượt được hoàn trả.

**Gợi ý đội hình Trầm Thủy**: DPS chính Geo cần phản ứng Kết Tinh liên tục
để giữ đầy lớp Crystal Shrapnel trước khi xả kỹ năng. Combo phổ biến: Kết
Tinh (Geo-Electro/Geo-Pyro) với Fischl/Xiangling, hoặc mono-Geo cùng Gorou.

---

### Chevreuse

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Pyro (Hoả) | Trường thương | 4★ | Fontaine | 2024-01-09 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1003 | 16 | 51 |
| 90 (đột phá 6) | 11968 | 193 | 605 |

Chỉ số đột phá phụ: **HP% +24.0%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Line Bayonet Thrust EX**: đâm tối đa 4 đòn; đòn nặng lao
  về trước gây sát thương.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 53.1% | 105.0% |
  | 4-Hit | 77.3% | 152.7% |
  | Đòn nặng | 121.7% | 240.6% |

- **Kỹ năng nguyên tố — Short-Range Rapid Interdiction Fire** (CD 15s,
  không tốn năng lượng): bấm bắn súng gây AoE Pyro DMG + hồi máu liên tục
  theo Max HP; giữ để ngắm bắn chính xác hơn (bắn Overcharged Ball nếu có).
  Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Bắn nhanh | 115.2% | 207.4% | 244.8% |
  | Bắn ngắm | 172.8% | 311.0% | 367.2% |
  | Overcharged Ball | 282.4% | 508.3% | 600.1% |
  | Hồi máu liên tục | 2.67% MaxHP+257 | 4.80% MaxHP+565 | 5.67% MaxHP+706 |

- **Bùng nổ nguyên tố — Ring of Bursting Grenades** (CD 15s, 60 năng
  lượng): bắn lựu đạn gây AoE Pyro DMG, tách thành nhiều mảnh nổ phụ. Cấp
  kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Lựu đạn chính | 368.2% | 662.7% | 782.3% |
  | Mảnh nổ phụ | 49.1% | 88.4% | 104.3% |

- **Passive 1 — Vanguard's Coordinated Tactics**: nếu đội chỉ gồm
  Pyro+Electro (có cả 2), đồng đội gần đó khi kích Quá Tải giảm 40% kháng
  Pyro/Electro của địch trong 6s.
- **Passive 2 — Vertical Force Coordination**: bắn Overcharged Ball xong,
  đồng đội Pyro/Electro gần đó +1% ATK/1000 Max HP Chevreuse (tối đa +40%)
  trong 30s.
- **Passive 3 — Double Time March**: giảm 20% tiêu hao Thể lực khi chạy
  cho cả đội.

**Cung mệnh (Constellation)**

1. **Stable Front Line's Resolve** — người có "Coordinated Tactics" kích
   Quá Tải hồi 6 NL (1 lần/10s).
2. **Sniper Induced Explosion** — giữ bắn trúng địch kích 2 vụ nổ phụ mỗi
   vụ 120% ATK (1 lần/10s, tính DMG kỹ năng).
3. **Practiced Field Stripping Technique** — tăng cấp kỹ năng thêm 3.
4. **The Secret to Rapid-Fire Multishots** — dùng Burst xong, giữ bắn
   (Hold) không vào CD trong 6s hoặc 2 lần bắn.
5. **Enhanced Incendiary Firepower** — tăng cấp Burst thêm 3.
6. **In Pursuit of Ending Evil** — sau 12s hồi máu từ kỹ năng, đồng đội
   hồi thêm 10% Max HP Chevreuse 1 lần; người được hồi nhận +20% Pyro/
   Electro DMG Bonus trong 8s (tối đa 3 lớp).

**Gợi ý đội hình Trầm Thủy**: Buffer + hồi máu chuyên biệt cho đội Quá Tải
(Pyro-Electro), giảm kháng địch và cấp ATK cho cả 2 nguyên tố. Combo phổ
biến: Quá Tải với Raiden Shogun/Yae Miko + Bennett/Xiangling.

---

### Clorinde

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Electro (Lôi) | Kiếm 1 tay | 5★ | Fontaine | 2024-06-03 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1009 | 26 | 61 |
| 90 (đột phá 6) | 12956 | 337 | 784 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Oath of Hunting Shadows**: chém tối đa 5 đòn; đòn nặng
  bắn súng ngắn theo hình quạt.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 54.1% | 106.9% |
  | 5-Hit | 90.0% | 177.9% |
  | Đòn nặng | 128.1% | 253.3% |

- **Kỹ năng nguyên tố — Hunter's Vigil** (CD 16s, không tốn năng lượng):
  vào Night Vigil 7.5s — đòn thường chuyển hẳn thành Swift Hunt (Electro
  DMG, cấp Bond of Life theo Max HP), dùng lại kỹ năng biến thành đòn lao
  Impale the Night (một phần chuyển hồi máu thành Bond of Life). Cấp kỹ
  năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Swift Hunt DMG | 26.8%/38.8% | 52.9%/76.7% | 64.1%/92.9% |
  | Bond of Life từ Swift Hunt | 35.0% MaxHP | 35.0% MaxHP | 35.0% MaxHP |
  | Impale the Night DMG | 33.0%/44.0%/25.1%×3 | 65.2%/86.9%/49.6%×3 | 79.0%/105.3%/60.2%×3 |
  | Thời lượng Night Vigil | 7.5s | 7.5s | 7.5s |

- **Bùng nổ nguyên tố — Last Lightfall** (CD 15s, 60 năng lượng): cấp Bond
  of Life theo Max HP rồi né đánh combo 5 đòn AoE Electro DMG. Cấp kỹ năng
  được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương (×5 đòn) | 126.9% | 228.4% | 269.6% |
  | Bond of Life nhận | 66.0% MaxHP | 120.0% MaxHP | 138.0% MaxHP |

- **Passive 1 — Dark-Shattering Flame**: đồng đội kích phản ứng liên quan
  Electro giúp đòn thường/Last Lightfall Electro DMG +20% ATK/lớp (tối đa 3
  lớp, tổng tối đa +1800 sát thương phẳng).
- **Passive 2 — Lawful Remuneration**: Bond of Life ≥100% Max HP, mỗi lần
  thay đổi +10% Crit Rate 15s (tối đa 2 lớp); Night Vigil chuyển 100% hồi
  máu thành Bond of Life.
- **Passive 3 — Night Vigil's Harvest**: hiện tài nguyên đặc thù Fontaine
  trên minimap.

**Cung mệnh (Constellation)**

1. **"From This Day..."** — trong Night Vigil, đòn thường Electro trúng
   địch triệu hồi Nightvigil Shade đánh phối hợp 2 đòn 30% ATK (1 lần/1.2s).
2. **"Now, As We Face..."** — Dark-Shattering Flame tăng lên +30% ATK/lớp
   (tối đa +2700 sát thương phẳng); đủ 3 lớp tăng kháng ngắt chiêu.
3. **"I Pledge to Remember..."** — tăng cấp Hunter's Vigil thêm 3.
4. **"To Enshrine Tears..."** — Last Lightfall DMG +2%/1% Bond of Life
   hiện tại (tối đa +200%).
5. **"Holding Dawn's Coming..."** — tăng cấp Last Lightfall thêm 3.
6. **"And So Shall I Never Despair"** — sau Hunter's Vigil 12s, +10% Crit
   Rate/+70% Crit DMG; trong Night Vigil giảm 80% sát thương nhận và triệu
   hồi Glimbright Shade đánh 200% ATK khi bị tấn công/dùng Impale.

**Gợi ý đội hình Trầm Thủy**: DPS chính Electro cơ chế Bond of Life (máu ảo
thay vì thật), cần nguồn hồi máu để chuyển hoá Bond of Life an toàn. Combo
phổ biến: Quá Tải (Electro-Pyro) hoặc Cảm Ứng Siêu Dẫn/tán xạ với
Furina/Bennett hỗ trợ hồi máu.

---

### Sigewinne

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Hydro (Thuỷ) | Cung | 5★ | Fontaine | 2024-06-26 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1039 | 15 | 39 |
| 90 (đột phá 6) | 13348 | 193 | 500 |

Chỉ số đột phá phụ: **HP% +28.8%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Targeted Treatment**: bắn cung tối đa 3 phát; đòn nặng
  Aimed Shot tích Hydro, sạc đầy bắn Mini-Stration Bubble định kỳ.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | Aimed Shot | 43.9% | 86.7% |
  | Aimed Shot sạc đầy | 124.0% | 223.2% |
  | Mini-Stration Bubble | 24.8% | 44.6% |

- **Kỹ năng nguyên tố — Rebound Hydrotherapy** (CD 18s, không tốn năng
  lượng): thổi Bolstering Bubblebalm nảy qua các địch gây Hydro DMG theo
  Max HP, mỗi lần nảy hồi máu đồng đội (trừ Sigewinne) theo Max HP; sau 5
  lần nảy tự hồi máu cho Sigewinne. Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương/lần nảy (%MaxHP) | 2.28% | 4.10% | 4.84% |
  | Hồi máu/lần nảy | 2.80% MaxHP+270 | 5.04% MaxHP+593 | 5.95% MaxHP+742 |
  | Hồi máu nảy cuối | 50.0% MaxHP | 50.0% MaxHP | 50.0% MaxHP |

- **Bùng nổ nguyên tố — Super Saturated Syringing** (CD 18s, 70 năng
  lượng): tấn công vùng trước mặt gây AoE Hydro DMG theo Max HP, hút tối đa
  2 Sourcewater Droplet. Cấp kỹ năng được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng (%MaxHP) | 11.8% | 21.2% | 25.0% |
  | Thời lượng | 2.5s | 2.5s | 2.5s |

- **Passive 1 — Requires Appropriate Rest**: sau kỹ năng 18s, +8% Hydro
  DMG Bonus và 10 lớp Convalescence — kỹ năng nguyên tố của đồng đội
  off-field tiêu 1 lớp để +DMG (theo Max HP Sigewinne trên 30000, tối đa
  +2800).
- **Passive 2 — Detailed Diagnosis, Thorough Treatment**: hồi máu tăng
  thêm theo tổng Bond of Life cả đội (mỗi 1000 HP Bond of Life +3% Healing,
  tối đa +30%).
- **Passive 3 — Emergency Dose**: dưới nước, HP đồng đội <50% tự hồi 50%
  Max HP nhưng giảm 10% kháng nguyên tố+vật lý 10s (1 lần/20s).

**Cung mệnh (Constellation)**

1. **"Can the Happiest of Spirits..."** — Bubblebalm nảy thêm 3 lần; 3 lần
   đầu không giảm kích thước; Convalescence đổi thành +100 DMG/1000 Max HP
   trên 30000 (tối đa +3500).
2. **"Can the Most Merciful of Spirits..."** — dùng kỹ năng/Burst tạo
   Bubbly Shield 30% Max HP (hấp thụ Hydro 250%); trúng địch giảm 35% Hydro
   RES trong 8s.
3. **"Can the Healthiest of Spirits..."** — tăng cấp kỹ năng thêm 3.
4. **"Can the Loveliest of Spirits..."** — Burst kéo dài thêm 3s.
5. **"Can the Most Joyful of Spirits..."** — tăng cấp Burst thêm 3.
6. **"Can the Most Radiant of Spirits..."** — hồi máu tăng Crit Rate/Crit
   DMG cho Burst theo Max HP (mỗi 1000 HP +0.4%/+2.2%, tối đa +20%/+110%)
   trong 15s.

**Gợi ý đội hình Trầm Thủy**: Healer bậc nhất scale theo Max HP, gần như
không thể để đội chết, kiêm buff sát thương kỹ năng off-field. Combo phổ
biến: bất kỳ đội cần healer bền (Hydro-bất kỳ), đặc biệt hợp với DPS scale
Bond of Life như Clorinde/Arlecchino.

---

### Emilie

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Dendro (Thảo) | Trường thương | 5★ | Fontaine | 2024-08-06 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1056 | 26 | 57 |
| 90 (đột phá 6) | 13568 | 335 | 730 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit DMG) +38.4%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Shadow-Hunting Spear (Custom)**: đâm tối đa 4 đòn; đòn
  nặng chém lên.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 48.6% | 96.0% |
  | 4-Hit | 75.1% | 148.5% |
  | Đòn nặng | 91.3% | 180.5% |

- **Kỹ năng nguyên tố — Fragrance Extraction** (CD 14s, không tốn năng
  lượng): tạo Lumidouce Case tự bắn Puff of Puredew gây Dendro DMG; hộp thu
  thập "Scent" toả ra từ địch dính Cháy (Burning), đủ 2 Scent thì lên cấp 2
  (bắn thêm 1 phát, tăng phạm vi/DMG). Cấp kỹ năng được C3 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 47.1% | 84.7% | 100.0% |
  | Lumidouce Case cấp 1 | 39.6% | 71.3% | 84.2% |
  | Lumidouce Case cấp 2 (×2) | 84.0% | 151.2% | 178.5% |
  | Thời lượng hộp | 22.0s | 22.0s | 22.0s |

- **Bùng nổ nguyên tố — Aromatic Explication** (CD 13.5s, 50 năng lượng):
  chuyển hộp thành Lumidouce Case cấp 3, liên tục thả Scented Dew gây Dendro
  DMG diện rộng trong thời gian ngắn, hết giờ tái tạo hộp cấp 1. Cấp kỹ năng
  được C5 tăng thêm 3.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Lumidouce Case cấp 3 DMG | 217.2% | 391.0% | 461.6% |
  | Thời lượng cấp 3 | 2.8s | 2.8s | 2.8s |

- **Passive 1 — Lingering Fragrance**: hộp cấp 2 đủ 2 Scent sẽ tự xả
  Cleardew Cologne gây 600% ATK Dendro DMG AoE (không tính DMG kỹ năng).
- **Passive 2 — Rectification**: sát thương lên địch đang Cháy +15%/1000
  ATK (tối đa +36%).
- **Passive 3 — Headspace Capture**: khi có Lumidouce Case trên sân, cả
  đội +85% kháng sát thương Cháy (Pyro).

**Cung mệnh (Constellation)**

1. **Light Fragrance Leaching** — Fragrance Extraction và Cleardew Cologne
   +20% DMG; đồng đội kích Cháy/gây Dendro DMG lên địch Cháy tạo thêm 1
   Scent (1 lần/2.9s).
2. **Lakelight Top Note** — kỹ năng/Burst/Cleardew Cologne trúng địch giảm
   30% Dendro RES trong 10s.
3. **Exquisite Essence** — tăng cấp kỹ năng thêm 3.
4. **Lumidouce Heart Note** — Burst kéo dài thêm 2s; giảm 0.3s chu kỳ đổi
   mục tiêu Scented Dew.
5. **Puredew Aroma** — tăng cấp Burst thêm 3.
6. **Marcotte Sillage** — dùng kỹ năng/Burst nhận Abiding Fragrance 5s: đòn
   thường/nặng chuyển hẳn Dendro DMG +300% ATK, tạo Scent (tối đa 4 lần, 1
   lần/12s).

**Gợi ý đội hình Trầm Thủy**: DPS off-field Dendro chuyên trị đội Cháy
(Burning), cần Pyro liên tục để nuôi Scent nâng cấp hộp. Combo phổ biến:
Cháy nổ (Dendro-Pyro-Anemo) với Xiangling/Yoimiya + Kazuha/Sucrose lan
nguyên tố.

---

### Escoffier

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Cryo (Băng) | Trường thương | 5★ | Fontaine | 2025-05-05 |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1039 | 27 | 57 |
| 90 (đột phá 6) | 13348 | 347 | 732 |

Chỉ số đột phá phụ: **Tỉ lệ chí mạng (Crit Rate) +19.2%** ở cấp 90.

**Bộ kỹ năng**

- **Đòn thường — Kitchen Skills**: đâm tối đa 3 đòn; đòn nặng đâm lên.

  | Chỉ số | Cấp 1 | Cấp 10 |
  |---|---|---|
  | 1-Hit | 51.6% | 101.9% |
  | 3-Hit | 33.0%+40.3% | 65.2%+79.7% |
  | Đòn nặng | 115.4% | 228.1% |

- **Kỹ năng nguyên tố — Low-Temperature Cooking** (CD bấm 15s / giữ 6s,
  không tốn năng lượng): bấm kích hoạt Cooking Mek chế độ Cold Storage gây
  AoE Cryo DMG, tự bắn Frosty Parfait định kỳ; giữ để vào chế độ khác. Cấp
  kỹ năng được C3 tăng thêm 3 *(API gắn cờ liên kết cung mệnh khác quy ước
  thông thường nhưng văn bản C3 xác nhận +3 cấp, tối đa cấp 15; số liệu cấp
  13 đã kiểm chứng khớp công thức scale)*.

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C3) |
  |---|---|---|---|
  | Sát thương kỹ năng | 50.4% | 90.7% | 107.1% |
  | Frosty Parfait DMG | 120.0% | 216.0% | 255.0% |
  | Thời lượng Cold Storage | 20.0s | 20.0s | 20.0s |

- **Bùng nổ nguyên tố — Scoring Cuts** (CD 15s, 60 năng lượng): thi triển
  dao pháp gây AoE Cryo DMG và hồi máu cả đội gần đó theo ATK. Cấp kỹ năng
  được C5 tăng thêm 3 (cùng lưu ý như trên).

  | Chỉ số | Cấp 1 | Cấp 10 | Cấp 13 (có C5) |
  |---|---|---|---|
  | Sát thương kỹ năng | 592.8% | 1067.0% | 1259.7% |
  | Hồi máu | 172.0% ATK+1079 | 309.7% ATK+2373 | 365.6% ATK+2966 |

- **Passive 1 — Better to Salivate Than Medicate**: sau Burst, Rehab Diet
  9s tự hồi máu đồng đội mỗi giây theo 138.24% ATK.
- **Passive 2 — Inspiration-Immersed Seasoning**: đội có 1/2/3/4
  Hydro/Cryo thì kỹ năng/Burst trúng địch giảm 5/10/15/55% kháng Hydro+Cryo
  trong 12s.
- **Passive 3 — Constant Off-the-Cuff Cookery**: giữ kỹ năng kích hoạt chế
  độ nấu ăn phụ hấp thụ nguyên tố tạo món ăn đặc biệt.

**Cung mệnh (Constellation)**

1. **Pre-Dinner Dance for Your Taste Buds** — đội đủ 4 Hydro/Cryo thì dùng
   kỹ năng/Burst cho cả đội +60% Crit DMG Cryo trong 15s.
2. **Fresh, Fragrant Stew Is an Art** — kích hoạt Cold Storage Mode nhận 5
   lớp Cold Dish; đồng đội gây Cryo DMG tiêu 1 lớp để +240% ATK Escoffier
   vào sát thương.
3. **The Bakery Magic of Caramel Browning** — tăng cấp kỹ năng thêm 3.
4. **Secret Rosemary Recipe** — Rehab Diet +6s; có cơ hội (theo Crit Rate)
   hồi thêm 100% HP và 2 NL mỗi lần hồi máu (tối đa 7 lần/lượt).
5. **Symphony of a Thousand Sauces** — tăng cấp Burst thêm 3.
6. **Tea Parties Bursting With Color** — Cold Storage Mode: đồng đội đánh
   trúng địch kích thêm 1 Frosty Parfait đặc biệt 500% ATK Escoffier (1
   lần/0.5s, tối đa 6 lần/lượt, tính DMG kỹ năng).

**Gợi ý đội hình Trầm Thủy**: Support hồi máu + buff giảm kháng Hydro/Cryo
mạnh nhất cho đội Đóng Băng, gần như thay thế hoàn toàn nhu cầu healer khác.
Combo phổ biến: Đóng băng (Cryo-Hydro) toàn Hydro/Cryo với
Neuvillette/Ayaka/Ganyu để tối đa hoá passive giảm kháng.

---

---

## Kaedehara Kazuha

**Thông tin chung**

| Nguyên tố | Vũ khí | Độ hiếm | Quốc gia | Ngày ra mắt |
|---|---|---|---|---|
| Anemo | Sword | 5★ | Inazuma | 29/06/2021 (bản 1.6) |

**Chỉ số cơ bản**

| Cấp | HP | ATK | DEF |
|---|---|---|---|
| 1 | 1039.12 | 23.09 | 62.82 |
| 90 (đột phá 6) | 13,348.07 | 296.58 | 806.98 |

Chỉ số đột phá phụ (cấp 90): **Elemental Mastery +115.2**

**Bộ kỹ năng**

*Đòn thường — Garyuu Bladework*

| Đòn | Cấp 1 | Cấp 10 |
|---|---|---|
| 1-Hit | 44.98% | 88.91% |
| 2-Hit | 45.24% | 89.42% |
| 3-Hit ×2 | 25.80%+30.96% | 51.00%+61.20% |
| 4-Hit | 60.72% | 120.02% |
| 5-Hit ×3 | 25.37% | 50.15% |
| Trọng kích ×2 | 43.00%+74.65% | 85.00%+147.56% |
| Nhảy rơi | 81.83% | 161.76% |
| Nhảy thấp/cao | 163.63%/204.39% | 323.46%/404.02% |

*Kỹ năng — Chihayaburu* (Hồi chiêu: 6s bấm nhanh / 9s giữ): hút gió gây DMG
Anemo diện rộng rồi nâng Kazuha lên không, cho phép dùng ngay Đòn nhảy đặc
biệt **Midare Ranzan**. Nếu chạm Hydro/Pyro/Cryo/Electro khi thi triển, hút
nguyên tố đó (Elemental Absorption, 1 lần/lượt dùng).

| Chỉ số | Cấp 1 | Cấp 10 (max 13 nhờ C3) |
|---|---|---|
| Bấm nhanh — Skill DMG | 192% ATK | 345.6% ATK |
| Giữ — Skill DMG | 260.8% ATK | 469.44% ATK |

*Bùng nổ — Kazuha Slash* (Năng lượng: 60 | Hồi chiêu: 15s): tạo vùng **Autumn
Whirlwind** tồn tại 8s, gây DMG Anemo ban đầu rồi DMG Anemo liên tục; vùng hút
Hydro/Pyro/Cryo/Electro chạm phải và gây thêm sát thương nguyên tố đó.

| Chỉ số | Cấp 1 | Cấp 10 (max 13 nhờ C5) |
|---|---|---|
| Slashing DMG | 262.4% ATK | 472.32% ATK |
| DoT (mỗi nhịp) | 120% ATK | 216% ATK |
| Sát thương nguyên tố cộng thêm | 36% ATK | 64.8% ATK |

**Passive A1 — Soumon Swordsmanship:** nếu Chihayaburu hút được nguyên tố,
Midare Ranzan dùng ngay sau đó gây thêm **200% ATK** sát thương thuộc nguyên tố
đã hút (tính là sát thương Đòn nhảy).
**Passive A4 — Poetics of Fuubutsu:** khi kích hoạt Khuếch Tán (Swirl) hoặc
**Stellar Swirl**, toàn đội nhận **+0.04% DMG Bonus** của nguyên tố bị cuốn
trên **mỗi điểm EM** của Kazuha, trong 8s; bonus các nguyên tố khác nhau cộng
dồn song song.
**Utility Passive — Cloud Strider:** giảm 20% tiêu hao thể lực khi chạy cho
toàn đội.

**Cung mệnh**
1. Scarlet Hills — giảm 10% hồi chiêu Chihayaburu; dùng Kazuha Slash reset hồi
   chiêu Chihayaburu.
2. Yamaarashi Tailwind — vùng Autumn Whirlwind cho Kazuha +200 EM và nhân vật
   đứng trong vùng +200 EM.
3. Maple Monogatari — tăng cấp Chihayaburu +3 (tối đa 15).
4. Oozora Genpou — khi năng lượng < 45: bấm nhanh/giữ Chihayaburu hồi 3/4 năng
   lượng; đòn nhảy trong 5s sau khi dùng Chihayaburu hồi 2 năng lượng/giây.
5. Wisdom of Bansei — tăng cấp Kazuha Slash +3 (tối đa 15).
6. Crimson Momiji — sau khi dùng Chihayaburu/Kazuha Slash, Kazuha được phú
   Anemo 5s; mỗi điểm EM tăng 0.2% sát thương Đòn thường/Trọng kích/Đòn nhảy.

**Vai trò đội hình Trầm Thủy:** Support Anemo mạnh nhất game — gom quái, hạ 40%
kháng nguyên tố bị cuốn (4 món Viridescent Venerer) và buff DMG nguyên tố toàn
đội theo EM (A4). Build EM là chính (không phải ATK). Ghép được với gần như mọi
đội phản ứng: Vaporize (Hu Tao/Xiangling), Freeze, Aggravate, Melt.
