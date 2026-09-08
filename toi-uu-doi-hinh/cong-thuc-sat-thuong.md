# Công thức tính sát thương (Damage Formula)

> Ngày lấy dữ liệu: 2026-09-08. Nguồn: trang "Damage", "Elemental Reaction/
> Level Scaling" và "RES" trên Genshin Impact Wiki (Fandom), lấy nguyên văn
> công thức qua MediaWiki API (`action=parse&prop=wikitext`). Đây là cơ chế
> lõi của game, ít khi đổi qua các bản cập nhật — nhưng phần **Lunar &
> Stellar Glimmer Reaction** (mục 9) là cơ chế mới (bản 6.x/7.0, gắn với
> Nod-Krai/Snezhnaya) nên đã được xác minh riêng, không lấy từ trí nhớ.
>
> Dùng file này cùng với [`nhan-vat/`](nhan-vat/), [`vu-khi/`](vu-khi/),
> [`thanh-di-vat/`](thanh-di-vat/) và [`quai-vat-la-hoan/`](quai-vat-la-hoan/)
> để tự tính sát thương thực tế của một đội hình lên quái Trầm Thủy cụ thể,
> thay vì chỉ so sánh hệ số % trên giấy.

## 1. Chuỗi công thức tổng quát (đòn đánh thường, không phản ứng)

Áp dụng cho sát thương từ Kỹ năng/Thường công/Trọng kích/Bùng nổ/Cung mệnh/
vũ khí passive — **trừ** sát thương phản ứng chuyển hóa (mục 8) và sát
thương Mặt Trăng/Sao gián tiếp (mục 9.1):

```
DMG = [Σ(Base DMG × Base DMG Multiplier) + Additive Base DMG Bonus]
      × DMG Bonus Multiplier
      × Elevation Multiplier
      × DEF Multiplier
      × RES Multiplier
      × CRIT Multiplier
```

### 1.1. Base DMG

```
Base DMG = % Hệ số kỹ năng × Chỉ số tương ứng
```

Chỉ số tương ứng là ATK/DEF/HP tối đa/Tinh Thông Nguyên Tố (EM) tùy kỹ
năng quy định (đa số scale ATK; một số scale HP như Xingqiu/Yelan/Nilou,
DEF như Noelle/Albedo/Itto, EM như Yumemizuki Mizuki một số đòn).

### 1.2. Base DMG Multiplier

Hệ số nhân trực tiếp với Base DMG — chỉ tồn tại khi có kỹ năng/cung mệnh
cụ thể quy định (ví dụ: X2 sát thương ở trạng thái đặc biệt). Không phải
đòn nào cũng có.

### 1.3. Additive Base DMG Bonus

Một lượng sát thương cộng thẳng (không nhân %) vào Base DMG, đến từ vũ
khí/cung mệnh/thánh di vật cụ thể, **và** từ phản ứng Aggravate/Spread
(xem mục 8).

### 1.4. DMG Bonus Multiplier

```
DMG Bonus Multiplier = 1 + %DMG Bonus − %DMG Reduction (của địch)
```

`%DMG Bonus` = tổng tất cả % Sát Thương Nguyên Tố/Vật Lý trên bảng chỉ số,
cộng mọi buff % sát thương theo loại đòn (Thường công/Trọng kích/Kỹ
năng/Nộ) hay toàn thân, từ thánh di vật/cung mệnh/buff đồng đội.

### 1.5. Elevation Multiplier (cơ chế mới — chỉ một số cung mệnh 5★)

```
Elevation Multiplier = 1 + %Elevation
```

Tách biệt với DMG Bonus (cộng dồn riêng), hiện chỉ xuất hiện ở một số cung
mệnh 5★ mới (bao gồm cung mệnh liên quan Lunar-Charged/Lunar-Bloom/
Lunar-Crystallize/Stellar-Conduct/Stellar Swirl).

### 1.6. DEF Multiplier — giảm sát thương theo Phòng Thủ địch

```
k = (1 − %DEF Reduction của người chơi) × (1 − %DEF Ignore của người chơi)

DEF Multiplier = (Cấp nhân vật + 100)
                 ────────────────────────────────────
                 k × (Cấp quái + 100) + (Cấp nhân vật + 100)
```

Với quái Trầm Thủy, cấp quái công bố trong [`quai-vat-la-hoan/`](quai-vat-la-hoan/)
(thường 90–100 ở tầng 12). `%DEF Reduction` đến từ hiệu ứng làm giảm DEF
địch (ví dụ Cung mệnh 2 Klee, Bennett một số hiệu ứng...); `%DEF Ignore`
đến từ hiệu ứng xuyên giáp trực tiếp (ví dụ một số kỹ năng Noelle/Itto).

### 1.7. RES Multiplier — giảm/khuếch đại sát thương theo Kháng địch

```
%RES = %RES gốc của quái + %RES Bonus − %RES Debuff (bị hạ bởi kỹ năng/hiệu ứng)

RES Multiplier =
  1 − (RES / 2)        nếu RES < 0
  1 − RES               nếu 0 ≤ RES < 75%
  1 / (4×RES + 1)        nếu RES ≥ 75%
```

Quái thường (không phải boss) mặc định **10% kháng mọi hệ** (kể cả Vật
Lý) trừ khi ghi chú khác trong file quái vật cụ thể — do đó hạ kháng
xuống âm (ví dụ Xoáy Cuồng Phong/Viridescent Venerer trừ 40% kháng hệ bị
cuốn) rất mạnh vì nhân sát thương lên >100%. RES của quái tầng 9-12 mùa
hiện tại: xem [`quai-vat-la-hoan/`](quai-vat-la-hoan/).

### 1.8. CRIT Multiplier

```
CRIT Multiplier = 1 + %CRIT DMG   (nếu trúng chí mạng)
                = 1                (nếu không)
```

Kỳ vọng sát thương trung bình (để so sánh build) thường tính:
`DMG kỳ vọng = DMG không CRIT × (1 − CRIT Rate) + DMG CRIT × CRIT Rate`,
tương đương nhân hệ số kỳ vọng `1 + CRIT Rate × CRIT DMG`.

**Kinh nghiệm chọn substat (Crit Value)**: để so sánh nhanh 2 dòng thánh
di vật mà không cần tính DPS đầy đủ, dùng `Crit Value = 2 × %CRIT Rate +
%CRIT DMG` — càng cao càng tốt, mục tiêu build phổ biến là CRIT Rate:CRIT
DMG ≈ 1:2 (ví dụ 70%:140%).

## 2. Phản ứng khuếch đại (Amplifying) — Vaporize / Melt

Nhân thêm hệ số vào sát thương của đòn vừa gây phản ứng:

```
Amplifying Multiplier = Hệ số gốc × (1 + %EM Bonus + %Reaction Bonus)

DMG sau phản ứng = DMG gốc × Amplifying Multiplier
```

| Trường hợp | Hệ số gốc |
|---|---|
| Melt — Pyro kích hoạt (đánh Pyro vào Cryo) | 2.0 |
| Melt — Cryo kích hoạt (đánh Cryo vào Pyro) | 1.5 |
| Vaporize — Hydro kích hoạt (đánh Hydro vào Pyro) | 2.0 |
| Vaporize — Pyro kích hoạt (đánh Pyro vào Hydro) | 1.5 |

```
%EM Bonus (Amplifying) = 2.78 × EM / (EM + 1400) × 100%
```

`%Reaction Bonus` đến từ thánh di vật/cung mệnh (ví dụ 4 món Crimson Witch
of Flames +15% Vaporize/Melt).

## 3. Phản ứng cộng dồn (Catalyze) — Aggravate / Spread

Không nhân %, mà **cộng thẳng** một lượng sát thương vào Base DMG của đòn
kế tiếp:

```
Additive Base DMG Bonus (Catalyze)
  = Hệ số gốc × Level Multiplier(cấp nhân vật) × (1 + %EM Bonus + %Reaction Bonus)

%EM Bonus (Catalyze) = 5 × EM / (EM + 1200) × 100%
```

Hệ số gốc: **Aggravate (Điện) = 1.15**, **Spread (Thảo) = 1.25**.

## 4. Phản ứng chuyển hóa (Transformative)

Overloaded (Cháy Nổ), Superconduct (Siêu Dẫn), Electro-Charged (Cảm
Điện — dạng chuyển hóa khi không Aggravate), Swirl (Khuếch Tán), Burning
(Thiêu Đốt), Bloom/Hyperbloom/Burgeon (Nảy Mầm/Kích Nổ Siêu Cấp/Sinh
Trưởng Kịch Phát), Shatter (Vỡ Băng khi đánh Vật Lý/Nham vào mục tiêu
đóng băng).

Là **một sát thương độc lập hoàn toàn** — không dùng ATK/DMG Bonus/CRIT
thường của người chơi, không bị DEF địch ảnh hưởng (gần như bỏ qua), chỉ
phụ thuộc **cấp nhân vật** (người gây phản ứng thứ hai) và **EM**:

```
DMG(Transformative) = Hệ số gốc × Level Multiplier(cấp nhân vật)
                       × (1 + %EM Bonus + %Reaction Bonus)
                       + Reaction Additive Base DMG Bonus
                     × RES Multiplier(địch)
                     × CRIT Multiplier(Transformative — mặc định = 1, hầu hết
                       nhân vật không có CRIT cho loại sát thương này)

%EM Bonus (Transformative) = 16 × EM / (EM + 2000) × 100%
```

| Phản ứng | Hệ số gốc |
|---|---|
| Burning | 0.25 |
| Swirl | 0.6 |
| Superconduct | 1.5 |
| Electro-Charged | 2.0 |
| Bloom | 2.0 |
| Overloaded | 2.75 |
| Burgeon | 3.0 |
| Hyperbloom | 3.0 |
| Shatter | 3.0 |

**Level Multiplier ở cấp 90** (cấp chuẩn dùng cho đội hình Trầm Thủy):
nhân vật = **1446.853458**, quái/môi trường = **1202.813736**. Vài mốc
tham khảo khác:

| Cấp | Nhân vật | Quái/môi trường |
|---|---|---|
| 70 | 765.640231 | 720.170325 |
| 80 | 1077.443668 | 946.370258 |
| 85 | 1253.835659 | 1066.623598 |
| 90 | 1446.853458 | 1202.813736 |

Ví dụ nhanh (bỏ qua RES/EM Bonus): 1 đòn Overloaded ở nhân vật cấp 90 =
`2.75 × 1446.853458 ≈ 3979` sát thương gốc, trước khi nhân EM Bonus và
RES Multiplier của quái.

**Lưu ý quan trọng**: chỉ số của người **gây nguyên tố đầu tiên** (áp
Pyro/Hydro/Cryo/Electro/Dendro lên địch) **không** ảnh hưởng tới sát
thương phản ứng — chỉ người **kích hoạt phản ứng** (chạm nguyên tố thứ
hai, hoặc thứ ba với Hyperbloom/Burgeon) mới tính EM/cấp độ của họ.

## 5. Sát thương Mặt Trăng & Ánh Sao (Lunar & Stellar Glimmer) — cơ chế mới

Lunar-Charged, Lunar-Bloom, Lunar-Crystallize (nhóm "Lunar", gắn Nod-Krai)
và Stellar-Conduct, Stellar Swirl (nhóm "Stellar Glimmer", gắn Snezhnaya/
Sandrone/Odette/Traveler Cryo) dùng chung một công thức, tách biệt phản
ứng chuyển hóa thường ở chỗ: có thể gây **trực tiếp** bằng kỹ năng (dùng
CRIT Rate/DMG thường của nhân vật) hoặc **gián tiếp** qua một đòn tính
riêng theo tất cả nhân vật đã góp phần áp nguyên tố.

```
%EM Bonus (Lunar/Stellar) = 6 × EM / (EM + 2000) × 100%
```

### 5.1. Sát thương gián tiếp (áp nguyên tố kích hoạt, không phải kỹ năng trực tiếp)

Chỉ Lunar-Charged, Lunar-Crystallize, Stellar Swirl có dạng gián tiếp
(Lunar-Bloom/Stellar-Conduct không có — sát thương của chúng tính qua cơ
chế lõi tương ứng, ví dụ Dendro Core của Bloom).

Bước 1 — tính riêng cho **từng nhân vật đã góp phần** áp nguyên tố kích
hoạt phản ứng:
```
DMG(cá nhân) = Hệ số gốc × Level Multiplier(cấp nhân vật đó)
               × (1 + %Reaction Base DMG Bonus)
               × (1 + %EM Bonus + %Reaction Bonus)
               × Elevation Multiplier × RES Multiplier(địch)
               × CRIT Multiplier(cá nhân đó — CRIT thường, không phải Transformative)
```
Hệ số gốc: Stellar Swirl (đợt đầu) = 0.75, Lunar-Crystallize = 1.6,
Stellar Swirl (Lv.1 tiếp theo) = 2, Stellar Swirl (Lv.2) = 3,
Lunar-Charged = 3.

Bước 2 — xếp hạng DMG cá nhân từ cao xuống thấp, cộng lại theo trọng số
giảm dần (tối đa 4 người góp mặt):
```
DMG cuối = Cao nhất × 0.6 + Nhì × 0.3 + Ba × 0.05 + Tư × 0.05
```
(Nếu ít hơn 4 người, bỏ phần thiếu, giữ nguyên hệ số các phần còn lại.)

### 5.2. Sát thương trực tiếp (kỹ năng gây thẳng, không cần kích hoạt phản ứng)

```
DMG(trực tiếp) = [Hệ số gốc × %Kỹ năng × Chỉ số × Base DMG Multiplier
                   × (1 + %Reaction Base DMG Bonus)
                   × (1 + %EM Bonus + %Reaction Bonus)
                   + Reaction Additive Base DMG Bonus]
                 × Elevation Multiplier × RES Multiplier(địch) × CRIT Multiplier
```
Hệ số gốc: Lunar-Bloom = 1, Stellar Swirl = 1, Lunar-Crystallize = 1.6,
Lunar-Charged = 3, Stellar-Conduct = 1 (không ghi nhận đòn Băng/Điện
trước đó) đến 2 (bắt đầu 1.4, +0.05 mỗi đòn Băng/Điện ghi nhận, tối đa 12
đòn).

### 5.3. Nguồn tăng Reaction Base DMG Bonus (nhóm "Moonsign"/"Stellar Jubilee")

Chỉ một số nhân vật cụ thể sở hữu passive loại này (không phải EM, cộng
thẳng vào hệ số gốc trước khi nhân RES):

| Nhân vật | Loại | Tối đa |
|---|---|---|
| Columbina | Lunar-Charged/Bloom/Crystallize | +7% |
| Lauma | Lunar-Bloom | +14% |
| Nefer | Lunar-Bloom | +14% |
| Flins | Lunar-Charged | +14% |
| Ineffa | Lunar-Charged | +14% |
| Zibai | Lunar-Crystallize | +14% |
| Linnea | Lunar-Crystallize | +14% |
| Sandrone | Stellar-Conduct, Stellar Swirl | +14% |
| Odette | Stellar-Conduct, Stellar Swirl | +14% |
| Nhà Lữ Hành (Cryo) | Stellar-Conduct, Stellar Swirl | +7% |

Đội hình có 1 trong các nhân vật trên là điều kiện gần như bắt buộc để
build đội hình chuyên sâu Lunar/Stellar Glimmer.

## 6. Sát thương thật (True DMG)

Bỏ qua hoàn toàn DEF/RES/DMG Reduction của địch (nhưng vẫn bị khiên chặn).
Chỉ tăng được qua Vaporize/Melt (không qua Spread/Aggravate). Nguồn phổ
biến: sát thương rơi/va chạm, một số Ley Line Disorder, Electrogranum,
Thunderstone, Kamuijima Cannon... — hiếm khi liên quan trực tiếp build
đội hình.

## 7. Ví dụ tính mẫu (dịch nguyên văn từ ví dụ chính thức trên wiki)

Bối cảnh: Mona cấp 70 (ATK 1500, EM 150, CRIT DMG 80%, Hydro DMG Bonus
40%) áp Hydro (Ướt) lên một Fatui Agent cấp 75 → Sucrose (4 món
Viridescent Venerer) Khuếch Tán (Swirl) hệ Hydro, hạ 40% kháng Hydro của
địch → Hydro hết hiệu lực → Klee (Cung mệnh 2 *Explosive Frags*) đánh
Pyro vào, áp Pyro lên địch và hạ 23% DEF địch → Mona tung Nộ (Kỹ năng
*Stellaris Phantasm* cấp 6), trúng đòn này kích hoạt **Vaporize** (Hydro
của Mona kích hoạt lên Pyro đang có sẵn trên địch, hệ số 2.0) và ăn chí
mạng, đồng thời Klee's Cung mệnh 2 cộng thêm 52% DMG Bonus cho đòn đó vì
vừa gây phản ứng nguyên tố.

```
DEF Multiplier = (70+100) / [(1−0.23)×(75+100) + 70+100] = 0.55783
%RES Hydro = 10% (gốc) − 40% (Sucrose) = −30% → RES Multiplier = 1 − (−0.3/2) = 1.15
%EM Bonus (Amplifying) = 2.78 × 150/(150+1400) = 26.903%
Amplifying Multiplier = 2.0 (Vaporize, Hydro kích hoạt) × (1 + 0.26903) = 2.53806

DMG CRIT = 1500 (ATK Mona) × 6.19 (hệ số Stellaris Phantasm cấp 6)
           × (1 + 0.40 Hydro DMG Bonus + 0.52 Cung mệnh 2 Klee)
           × 0.55783 (DEF Multiplier) × 1.15 (RES Multiplier)
           × 2.53806 (Amplifying Multiplier) × (1 + 0.8 CRIT DMG)
         = 52 246.50 sát thương Hydro
```

(Số liệu và kết quả trên khớp 100% với ví dụ gốc trên trang wiki "Damage",
chỉ dịch phần diễn giải sang tiếng Việt — không thay đổi hệ số.)

## 8. Áp dụng vào việc chọn đội hình Trầm Thủy

1. Xác định RES/kháng và blessing của mùa hiện tại trong
   [`quai-vat-la-hoan/`](quai-vat-la-hoan/) — đặc biệt chú ý quái có kháng
   cao hoặc miễn nhiễm một hệ cụ thể (né dùng hệ đó làm DPS chính).
2. Với đội hình phản ứng (Vaporize/Melt/Bloom family/Aggravate/Spread/
   Lunar/Stellar), ưu tiên đẩy **EM** cho nhân vật kích hoạt phản ứng
   (người chạm nguyên tố thứ hai) thay vì ATK% — nhất là Transformative
   (hệ số EM 16×) và Lunar/Stellar (hệ số EM 6×) vốn không phụ thuộc ATK.
3. Với đội hình on-field thuần crit (không phản ứng hoặc phản ứng phụ),
   dùng **Crit Value = 2×CRIT Rate% + CRIT DMG%** để so sánh nhanh các
   thánh di vật/vũ khí trong [`vu-khi/`](vu-khi/) và
   [`thanh-di-vat/`](thanh-di-vat/) trước khi tính DPS đầy đủ.
4. Hạ RES địch (Khuếch Tán + 4 món Viridescent Venerer, Cung mệnh giảm
   kháng...) luôn đáng giá hơn cộng thêm % DMG Bonus cùng lượng, vì RES
   âm khuếch đại sát thương phi tuyến (xem công thức mục 1.7).
5. Giảm DEF địch (Cung mệnh Klee, một số cung mệnh khác) hoặc xuyên giáp
   chỉ thực sự đáng kể ở tầng cao (quái cấp 90-100) vì DEF Multiplier gốc
   đã tương đối thấp (~0.5) — vẫn có lợi nhưng ROI thấp hơn hạ RES.
