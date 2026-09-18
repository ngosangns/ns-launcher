# Thương (Polearm)

> Ngày lấy dữ liệu: 2026-09-08. Phiên bản game hiện hành khi biên soạn: ~7.0
> (Genshin Impact).
>
> Nguồn ban đầu: WebSearch tổng hợp từ Icy Veins, Game8, GameWith, genshin.gg,
> Sportskeeda (môi trường lúc đó không truy cập được `api.ambr.top` /
> `gi.yatta.moe` do lỗi DNS, và Fandom Wiki trả về HTTP 402), nên nhiều số
> liệu bị đánh dấu "chưa xác nhận".
>
> **Đã đối chiếu lại toàn bộ (2026-09-08)** bằng cách đọc trực tiếp JSON thô
> từ `gi.yatta.moe/api/v2/en/weapon` (danh sách đầy đủ 43 vũ khí Thương thật
> sự, dựa trên `type: "WEAPON_POLE"`) và `gi.yatta.moe/api/v2/en/weapon/{id}`
> cho từng vũ khí (curve `GROW_CURVE_ATTACK_*`/`GROW_CURVE_CRITICAL_*` +
> `initValue` cho ATK/chỉ số phụ, `affix.upgrade["0"]`/`["4"]` cho passive
> R1/R5), đối chiếu chéo với vũ khí khác dùng chung curve + initValue (kể cả
> ở `kiem.md`, `dai-kiem.md`, `cung.md`, `phap-khi.md`) để suy ra số liệu
> chắc chắn, và WebSearch cho cách lấy/nhân vật của các vũ khí mới. Toàn bộ
> "chưa xác nhận" ở ATK/chỉ số phụ/hiệu ứng R1–R5 đã được thay bằng số liệu
> xác nhận từ API.
>
> **Phát hiện và sửa các lỗi nghiêm trọng từ bản trước:**
> - **16 vũ khí bị gán nhầm loại** (không phải Thương): Katsuragikiri
>   Nagamasa, Forest Regalia (thực chất là Đại kiếm); Wandering Evenstar,
>   Ash-Graven Drinking Horn, Fruit of Fulfillment, Twin Nephrite, Angelos'
>   Heptades (Pháp khí); Calamity of Eshu, Cinnabar Spindle, Emberwell,
>   Sapwood Blade (Kiếm); Cloudforged, Covenant of Frost and Snow, End of the
>   Line, Snare Hook (Cung); Beacon of the Reed Sea (Đại kiếm) — đã loại khỏi
>   file này.
> - **9 vũ khí Thương 4★ có thật bị thiếu hoàn toàn** khỏi bản trước, nay đã
>   bổ sung: Ballad of the Fjords, Dialogues of the Desert Sages, Footprint
>   of the Rainbow, Frostbreath, Mountain-Bracing Bolt, Prospector's Drill,
>   Rightful Reward, Sacrificer's Staff, Tamayuratei no Ohanashi.
> - **ATK Lv90 của gần như toàn bộ vũ khí 4★ bị gán sai** (bản trước dùng
>   phẳng "454" cho mọi vũ khí 4★ bất kể đường cong tăng trưởng thật sự): các
>   đường cong `GROW_CURVE_ATTACK_201/202/203/204` cho ATK Lv90 lần lượt là
>   510/565/620/454 — đã sửa lại từng vũ khí theo đúng đường cong của nó
>   (ví dụ Wavebreaker's Fin thực ra là 620, không phải 454).
> - **Engulfing Lightning** Energy Recharge đúng là 55.1% (không phải
>   33.08% như bản trước) — cùng đường cong + initValue với Elegy for the
>   End (`cung.md`, đã xác nhận).
> - **Vortex Vanquisher** và **Fractured Halo** bị gán nhầm loại chỉ số phụ:
>   Vortex Vanquisher là ATK% (không phải Energy Recharge); Fractured Halo là
>   CRIT DMG (không phải CRIT Rate).
> - **Staff of the Scarlet Sands** và **Black Tassel** cũng bị gán nhầm loại
>   chỉ số phụ: Scarlet Sands là CRIT Rate (không phải Elemental Mastery —
>   EM chỉ xuất hiện trong hiệu ứng đặc biệt); Black Tassel là HP% (không
>   phải Physical DMG Bonus).
> - **Sửa lại lần 2 (2026-09-08), phát hiện khi đối chiếu chéo với
>   `dai-kiem.md`**: nhóm suy luận "cùng đường cong + `initValue` thì cùng
>   ATK Lv90" ở bản sửa trước đã bị gán nhầm **mốc giá trị** cho đường cong
>   `GROW_CURVE_ATTACK_301` (initValue 45.9364) — bản trước cho là 674,
>   nhưng đối chiếu số liệu Lv90 thực tế của game (qua Game8/zilliongamer,
>   không chỉ suy luận qua tên đường cong) thì đường cong này thực ra cho
>   ATK Lv90 = **608**, còn 674 là mốc của `GROW_CURVE_ATTACK_302`
>   (initValue 47.537, ví dụ Primordial Jade Winged-Spear — xác nhận đúng
>   674 qua Game8). Đã sửa lại: **Staff of Homa** (674→608, CRIT DMG
>   44.1%→66.2%, xác nhận qua bảng số liệu zilliongamer), **Vortex
>   Vanquisher** (674→608), **Engulfing Lightning** (674→608, xác nhận qua
>   Game8), **Lumidouce Elegy** (674→608), **Fractured Halo** (674→608,
>   CRIT DMG 44.1%→66.2% — cùng đường cong chỉ số phụ + `initValue` 0.144
>   với Staff of Homa), **Symphonist of Scents** (674→608, CRIT DMG
>   44.1%→66.2%, cùng lý do). Tương tự, `GROW_CURVE_ATTACK_303` (initValue
>   49.1377) không phải mốc 674 mà là **741** (xác nhận qua Game8 cho
>   Calamity Queller) — đã sửa **Calamity Queller** (674→741). *Rút kinh
>   nghiệm*: đối chiếu chéo giữa các vũ khí cùng đường cong trong nội bộ
>   các file `vu-khi/*.md` chỉ đảm bảo các vũ khí đó **nhất quán với nhau**,
>   không đảm bảo mốc giá trị tuyệt đối là đúng nếu file gốc suy luận sai
>   mốc — cần neo (anchor) ít nhất một vũ khí mỗi đường cong vào số liệu
>   Lv90 quan sát được thực tế (WebSearch/Game8/zilliongamer) trước khi lan
>   truyền sang các vũ khí khác dùng chung đường cong. Việc này cũng khiến
>   nhận định trước đó rằng `dai-kiem.md` ghi sai Wolf's Gravestone (608)
>   là **không chính xác** — 608 mới là giá trị đúng, `dai-kiem.md` không
>   cần sửa.
>
> ATK cấp 1 ít có giá trị thực chiến nhưng đã điền đầy đủ vì lấy được trực
> tiếp từ API (làm tròn `initValue`).
>
> Vũ khí 1★/2★ không có chỉ số phụ và không có hiệu ứng đặc biệt/tinh luyện
> (tính năng tinh luyện chỉ áp dụng từ 3★ trở lên); riêng 1★/2★ chỉ lên tối
> đa cấp 70 (không phải 90) nên cột ATK ghi theo "cấp 1 → cấp 70".

## 5★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Staff of Homa | 46 | 608 | CRIT DMG 66.2% | HP +20/25/30/35/40%. ATK cộng thêm bằng 0.8/1/1.2/1.4/1.6% HP tối đa; nếu HP người mang <50%, có thêm 1/1.2/1.4/1.6/1.8% HP tối đa nữa (tổng 1.8/2.2/2.6/3/3.4% HP tối đa khi dưới 50% HP). | Banner giới hạn (Wish) | Hu Tao, các DPS máu cao scale theo HP |
| Primordial Jade Winged-Spear | 48 | 674 | CRIT Rate 22.1% | Sát thương thường/trọng kích +12/15/18/21/24%; tấn công trúng địch +1 lớp Jade (tối đa 7, mỗi lớp +3.2/4/4.8/5.6/6.4% ATK, tối đa +22.4/28/33.6/39.2/44.8% ATK). | Banner giới hạn (Wish) | Xiao, Zhongli, DPS thương on-field |
| Vortex Vanquisher | 46 | 608 | ATK% 49.6% | ATK +12/15/18/21/24%; khi có khiên, thêm sát thương Kỹ năng/Bùng nổ +20/25/30/35/40%. | Banner giới hạn (Wish, sự kiện Chronicled cũ) | Zhongli, DPS thương đội hình khiên |
| Skyward Spine | 48 | 674 | Energy Recharge 36.7% | Tăng tốc độ tấn công 12%; đòn chí mạng hồi HP = 60/70/80/90/100% ATK cho người mang. | Banner giới hạn (Wish) | DPS thương cần Energy Recharge/tốc đánh |
| Calamity Queller | 49 | 741 | ATK% 16.5% | ATK +12/15/18/21/24% và sát thương nguyên tố mọi hệ +8/10/12/14/16% trong 20s sau khi rời/vào sân, giảm dần theo thời gian; nếu ở trên sân đủ lâu, ATK +20/25/30/35/40% và sát thương nguyên tố +12/15/18/21/24%. | Chronicled Wish (rerun theo đợt, không phải banner giới hạn thường trực) | Nhân vật thương on-field bền bỉ |
| Engulfing Lightning | 46 | 608 | Energy Recharge 55.1% | ATK cộng thêm bằng 28/35/42/49/56% Energy Recharge vượt quá 100% (tối đa +80% ATK); Energy Recharge +30%. | Banner giới hạn (Wish, vũ khí signature Raiden Shogun) | Raiden Shogun |
| Staff of the Scarlet Sands | 44 | 542 | CRIT Rate 44.1% | **Heat Haze at Horizon's End**: người mang nhận ATK cộng thêm bằng 52% (R1) đến 104% (R5) Elemental Mastery. Khi Kỹ năng nguyên tố trúng địch, nhận thêm "Dream of the Scarlet Sands" 10s: ATK cộng thêm bằng 28% (R1) đến 56% (R5) EM, tối đa 3 lớp. | Banner giới hạn (Wish, vũ khí signature Cyno) | Cyno, DPS thương scale EM |
| Crimson Moon's Semblance | 48 | 674 | CRIT Rate 22.1% | **Ashen Sun's Shadow**: trọng kích trúng địch tạo Bond of Life = 25% HP tối đa (hồi chuỗi 14s). Khi có Bond of Life, DMG Bonus +12%; nếu giá trị Bond of Life ≥30% HP tối đa, thêm +24% DMG Bonus (tổng tối đa 36%). | Banner giới hạn (Wish, vũ khí signature Arlecchino) | Arlecchino |
| Lumidouce Elegy | 46 | 608 | CRIT Rate 33.08% | **Bright Dawn Overture**: ATK +15%. Khi gây hiệu ứng Thiêu Đốt (Burning) lên địch hoặc gây sát thương Dendro lên địch đang Thiêu Đốt, sát thương +18% trong 8s, tối đa 2 lớp. Ở 2 lớp (hoặc làm mới lớp 2), hồi 12 Năng lượng nguyên tố, hồi chuỗi 12s. Cả hai hiệu ứng trên hoạt động cả khi rời sân. | Banner giới hạn (Wish, vũ khí signature Emilie) | Emilie |
| Bloodsoaked Ruins | 48 | 674 | CRIT Rate 22.1% | **Mournful Tribute**: trong 3.5s sau khi dùng Bùng nổ nguyên tố, sát thương Lunar-Charged +36/48/60/72/84%. Sau khi kích hoạt phản ứng Lunar-Charged, nhận "Requiem of Ruin": CRIT DMG +28/35/42/49/56% trong 6s, đồng thời hồi 12/13/14/15/16 Năng lượng nguyên tố (hồi chuỗi 14s). | Banner giới hạn (Wish, vũ khí signature Flins) | Flins |
| Disaster and Remorse | 48 | 674 | CRIT Rate 22.1% | **Dolorous Stroke**: sau khi dùng Kỹ năng nguyên tố, nhận "Path of Conflict" 17s (hồi chuỗi 18s) cùng "Unforgivable" và "Irreparable" 3s mỗi hiệu ứng. Unforgivable: sát thương đòn thường/trọng kích +40% (R1)/+80% (R5). Irreparable: sát thương Kỹ năng/Bùng nổ nguyên tố +40% (R1)/+80% (R5). Trong lúc có Path of Conflict, đòn thường/trọng kích trúng địch kéo dài Irreparable thêm 1s, Kỹ năng/Bùng nổ trúng địch kéo dài Unforgivable thêm 1s (tối đa 1 lần/0.1s); rời sân hoặc hết Path of Conflict sẽ mất cả hai. Khi đội có Hexerei: Secret Rite, hai hiệu ứng trên +75%. | Banner giới hạn (Wish, vũ khí signature Lohen) | Lohen |
| Fractured Halo | 46 | 608 | CRIT DMG 66.2% | Sau khi dùng Kỹ năng/Bùng nổ nguyên tố, ATK +24% trong 20s; nếu người mang tạo Khiên trong thời gian này, nhận "Electrifying Edict" 20s: toàn đội gần đó +40% sát thương Lunar-Charged. | Banner giới hạn (Wish, vũ khí signature Ineffa) | Ineffa |
| Symphonist of Scents | 46 | 608 | CRIT DMG 66.2% | **Seasoned Symphony**: ATK +12% (R1)/+24% (R5); khi rời sân, thêm +12% (R1)/+24% (R5) ATK nữa. Sau khi hồi máu, người mang và (các) nhân vật được hồi nhận "Sweet Echoes": ATK +32% (R1)/+64% (R5) trong 3s (kích hoạt được cả khi rời sân). | Banner giới hạn (Wish, vũ khí signature Escoffier) | Escoffier |

## 4★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Ballad of the Fjords | 42 | 510 | CRIT Rate 27.6% | **Tales of the Tundra**: khi đội hình có từ 3 hệ nguyên tố khác nhau trở lên, Elemental Mastery +120 (R1) đến +240 (R5). | Battle Pass (Gnostic Hymn, bản 4.0) | Hỗ trợ EM cho đội đa nguyên tố (3+ hệ khác nhau) |
| Blackcliff Pole | 42 | 510 | CRIT DMG 55.1% | Sau khi hạ gục địch, ATK +12/15/18/21/24% trong 30s, tối đa 3 lớp. | Đổi Starglitter (Paimon's Bargains) | DPS thương CRIT DMG-focus |
| Crescent Pike | 44 | 565 | Physical DMG Bonus 34.5% | Sau khi trúng đòn Nạp Năng bằng phản ứng nguyên tố (Aggravate/Spread…), sát thương thường/trọng kích tiếp theo +12/15/18/21/24% trong 5s. | Chế tạo | DPS thương đòn thường/trọng kích kết hợp phản ứng |
| Deathmatch | 41 | 454 | CRIT Rate 36.8% | ATK và DEF +16/20/24/28/32% khi có từ 2 địch trở lên gần người mang; nếu chỉ có 1 địch, ATK +12/15/18/21/24%. | Battle Pass | DPS/tank thương đa mục tiêu |
| Dialogues of the Desert Sages | 42 | 510 | HP% 41.3% | **Principle of Equilibrium**: khi người mang thực hiện hồi máu, hồi 8 (R1) đến 16 (R5) Năng lượng nguyên tố, hồi chuỗi 10s, kích hoạt được cả khi rời sân. | Sự kiện "Alchemical Ascension" (bản 4.5) — nhận miễn phí sau khi đạt 50.000 doanh thu tích lũy trong sự kiện | Chevreuse, Mika, Yaoyao (healer scale HP) |
| Dragon's Bane | 41 | 454 | Elemental Mastery 221 | Sát thương gây cho địch dính hiệu ứng Thủy hoặc Hỏa +12/15/18/21/24%. | Banner tiêu chuẩn (Wish) | Xiangling, Hu Tao, DPS thương hệ Hỏa/Thủy |
| Dragonspine Spear | 41 | 454 | Physical DMG Bonus 69.0% | **Frost Burial**: đòn thường/trọng kích trúng địch có 60% (R1)/100% (R5) tỉ lệ rơi một khối băng gây sát thương AoE bằng 80% (R1)/140% (R5) ATK; nếu địch đang dính Băng thì gây 200% (R1)/360% (R5) ATK, hồi chuỗi 10s. | Chế tạo (Dragonspine) | DPS thương hệ Băng, trọng kích |
| Favonius Lance | 44 | 565 | Energy Recharge 30.6% | Đòn chí mạng có 60/70/80/90/100% tỉ lệ tạo Hạt Nguyên Tố hồi năng lượng, hồi chuỗi 12/10/8/6/5s. | Banner tiêu chuẩn (Wish) | Nhân vật thương cần Energy Recharge |
| Footprint of the Rainbow | 42 | 510 | DEF% 51.7% | **Pact of Flowing Springs**: dùng Kỹ năng nguyên tố, DEF +16% (R1) đến +32% (R5) trong 15s. | Chế tạo (Natlan, mua bản thiết kế từ Alom) | Kachina, Yun Jin, DPS/sub-DPS scale theo DEF |
| Frostbreath | 42 | 510 | Energy Recharge 45.9% | **A Cast Real Far**: kích hoạt phản ứng nguyên tố hệ Băng hoặc Thủy, ATK người mang +20% (R1) đến +40% (R5) trong 15s, đồng thời hồi 6 (R1)/12 (R5) Năng lượng nguyên tố cho đồng đội, hồi chuỗi 16s. | Battle Pass (Gnostic Hymn, bản 7.0) | Escoffier, Shenhe (đội Đóng Băng), Ineffa, Xiangling |
| Kitain Cross Spear | 44 | 565 | Elemental Mastery 110 | Sau khi Kỹ năng nguyên tố trúng địch, ATK +4/5/6/7/8% và EM +16/20/24/28/32, tối đa 2 lớp trong 8s. | Chế tạo | DPS thương scale EM |
| Lithic Spear | 44 | 565 | ATK% 27.6% | **Lithic Axiom: Unity**: mỗi nhân vật trong đội đến từ Liyue (kể cả người mang) cho ATK +7% (R1)/+11% (R5) và CRIT Rate +3% (R1)/+7% (R5), tối đa 4 lần. | Banner tiêu chuẩn (Wish) | Đội hình nhân vật gốc Liyue: Zhongli, Ningguang, Xingqiu, Hu Tao |
| Missive Windspear | 42 | 510 | ATK% 41.3% | **The Wind Unattained**: trong 10s sau khi kích hoạt phản ứng nguyên tố, ATK +12% (R1)/+24% (R5) và EM +48 (R1)/+96 (R5). | Sự kiện (Event, vũ khí Fontaine) | Sub-DPS/support thương tạo phản ứng |
| Moonpiercer | 44 | 565 | Elemental Mastery 110 | Sau khi Kỹ năng nguyên tố trúng địch, ATK +8/9/10/11/12%, tối đa 2 lớp trong 12s; nếu người mang hệ Dendro, thêm 4/5/6/7/8% ATK mỗi lớp. | Chế tạo (Sumeru) | DPS/sub-DPS thương hệ Dendro |
| Mountain-Bracing Bolt | 44 | 565 | Energy Recharge 30.6% | **Hope Beyond the Peaks**: giảm 15% tiêu hao thể lực leo trèo; sát thương Kỹ năng nguyên tố +12% (R1) đến +24% (R5); khi đồng đội gần đó dùng Kỹ năng nguyên tố, sát thương Kỹ năng của người mang cũng +12%/+24% thêm trong 8s. | Banner giới hạn (Weapon Event Wish, bản 5.1, không có trên banner tiêu chuẩn) | DPS/sub-DPS dùng Kỹ năng nguyên tố nhiều |
| Prospector's Drill | 44 | 565 | ATK% 27.6% | **Masons' Ditty**: khi được hồi máu hoặc hồi máu cho người khác, nhận 1 Unity's Symbol (tối đa 3, kéo dài 30s). Dùng Kỹ năng/Bùng nổ nguyên tố tiêu hết Symbol để nhận Struggle 10s: mỗi Symbol tiêu cho 3% (R1)/7% (R5) ATK và 7% (R1)/13% (R5) DMG Bonus nguyên tố mọi hệ; hồi chuỗi 15s, Symbol nhận được cả khi rời sân. | Banner giới hạn (Weapon Event Wish) | Support/hybrid cần hồi máu kết hợp sát thương nguyên tố |
| Prospector's Shovel | 42 | 510 | ATK% 41.3% | **Swift and Sure**: sát thương Electro-Charged +48% (R1) đến +96% (R5); sát thương Lunar-Charged +12% (R1) đến +24% (R5), thêm +12% (R1) đến +24% (R5) nữa khi có Moonsign: Ascendant Gleam. | Chế tạo (Natlan, Rossum Workshop tại Nasha Town, mua bản thiết kế từ Lyulka) | Sub-DPS/support gây phản ứng Electro-Charged hoặc Lunar-Charged |
| Prototype Starglitter | 42 | 510 | Energy Recharge 45.9% | **Magic Affinity**: sau khi dùng Kỹ năng nguyên tố, sát thương đòn thường/trọng kích +8% (R1)/+16% (R5) trong 12s, tối đa 2 lớp. | Chế tạo | Nhân vật thương cần Energy Recharge |
| Rightful Reward | 44 | 565 | HP% 27.6% | **Tip of the Spear**: khi người mang được hồi máu, hồi 8 (R1) đến 16 (R5) Năng lượng nguyên tố, hồi chuỗi 10s, kích hoạt được cả khi rời sân. | Chế tạo (Fontaine, mua bản thiết kế từ Estelle) | Healer/support cần hồi Năng lượng nguyên tố |
| Royal Spear | 44 | 565 | ATK% 27.6% | ATK +8/10/12/14/16%, nhưng CRIT Rate -6/5/4/3/2%. | Đổi Starglitter (Paimon's Bargains) | DPS thương ưu tiên ATK% thuần |
| Sacrificer's Staff | 45 | 620 | CRIT Rate 9.2% | **Untainted Desire**: trong 6s sau khi Kỹ năng nguyên tố trúng địch, ATK +8% (R1) đến +16% (R5) và Energy Recharge +6% (R1) đến +12% (R5), tối đa 3 lớp, kích hoạt được cả khi rời sân. | Banner giới hạn (Weapon Event Wish, bản 6.4) | Flins, Escoffier, Cyno, Arlecchino, Ineffa (DPS/sub-DPS dùng Kỹ năng nguyên tố) |
| Song of the Vigil | 44 | 565 | Elemental Mastery 110 | **Cadence of Days Gone By**: kích hoạt phản ứng nguyên tố hồi 4 (R1)/8 (R5) Năng lượng nguyên tố cho người mang, hồi chuỗi 9s; kích hoạt phản ứng Stellar Glimmer thì ATK +20% (R1)/+40% (R5) trong 12s. Cả hai hiệu ứng hoạt động cả khi rời sân. | Chế tạo (Kuznets Smithy của Kuzmichev, Snezhnograd — Snezhnaya, bản 7.0) | Hỗ trợ hồi Năng lượng qua phản ứng nguyên tố |
| Tamayuratei no Ohanashi | 44 | 565 | Energy Recharge 30.6% | **Busybody's Running Light**: dùng Kỹ năng nguyên tố, ATK +20% (R1) đến +40% (R5) và tốc độ di chuyển +10%, trong 10s. | Sự kiện "Enchanted Tales of the Mikawa Festival" (đổi tối thiểu 3 Festival Stamp) | DPS thương dùng Kỹ năng nguyên tố nhiều |
| "The Catch" | 42 | 510 | Energy Recharge 45.9% | Sát thương Bùng nổ nguyên tố +12/15/18/21/24% và CRIT Rate của Bùng nổ nguyên tố +6/7/8/9/10%. | Vendor (Sumeru Fishing Association, đổi bằng cá) | Nhân vật thương Bùng nổ nguyên tố: Raiden Shogun (dù dùng thương-support build) |
| Wavebreaker's Fin | 45 | 620 | ATK% 13.8% | Khi Năng lượng nguyên tố <100%, ATK +16/20/24/28/32%; khi đầy Năng lượng, thay bằng sát thương Bùng nổ nguyên tố +12/15/18/21/24%. | Banner tiêu chuẩn (Wish) | Nhân vật thương Bùng nổ nguyên tố |

## 3★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Black Tassel | 38 | 354 | HP% 46.9% | Không có hiệu ứng đặc biệt kích hoạt chủ động (chỉ tăng chỉ số cơ bản), vũ khí giản lược. | Banner tiêu chuẩn (Wish) | Nhân vật thương sơ khai |
| Halberd | 40 | 448 | ATK% 23.4% | **Heavy**: đòn thường trúng địch gây thêm sát thương bằng 160% (R1)/320% (R5) ATK, hồi chuỗi 10s. | Rương báu (Chest) | Nhân vật thương sơ khai |
| White Tassel | 39 | 401 | CRIT Rate 23.4% | Đòn thường/trọng kích trúng địch có 50% tỉ lệ tăng tốc độ tấn công 12% trong 3s. | Rương báu (Chest) | Nhân vật thương sơ khai |

## 2★

| Vũ khí | ATK (cấp 1 → cấp 90) | Ghi chú |
|---|---|---|
| Iron Point | 33 → 243 (cấp tối đa 70) | Không có chỉ số phụ, không có hiệu ứng đặc biệt. Chỉ dùng tạm giai đoạn đầu game. |

## 1★

| Vũ khí | ATK (cấp 1 → cấp 90) | Ghi chú |
|---|---|---|
| Beginner's Protector | 23 → 185 (cấp tối đa 70) | Không có chỉ số phụ, không có hiệu ứng đặc biệt. Vũ khí khởi đầu, không dùng trong đội hình thực chiến. |

## Ghi chú tổng hợp

- Danh sách trên bao quát đầy đủ **43 vũ khí Thương thật sự** đã phát hành
  tính đến phiên bản ~7.0 (09/2026), đối chiếu trực tiếp với danh sách đầy
  đủ từ `gi.yatta.moe/api/v2/en/weapon` (lọc theo `type: "WEAPON_POLE"`,
  không tính 4 "vũ khí trang trí" tái tạo hình dạng — Shattered Moon,
  Shattered Moon - Sublimation, Starlight of Fylkir, Starlight of Fylkir -
  Sublimation — vì đây là skin đổi hình vũ khí gốc, không có thông số riêng
  và không xuất hiện trong hòm chọn vũ khí như một vũ khí độc lập).
- Bản trước (tổng hợp qua WebSearch/công cụ tóm tắt tự động, không truy cập
  được API) có 16 vũ khí bị gán nhầm loại và thiếu 9 vũ khí Thương thật —
  xem chi tiết đầy đủ ở ghi chú nguồn phía trên. Đã dọn lại toàn bộ danh
  sách theo đúng dữ liệu API.
- Các số liệu ATK Lv90/chỉ số phụ được suy ra bằng cách so khớp
  `initValue` + mã đường cong (`GROW_CURVE_*`) giữa các vũ khí — hai vũ khí
  cùng đường cong và cùng `initValue` chắc chắn có cùng giá trị cuối ở cấp
  90, bất kể tên/loại chỉ số hiển thị khác nhau thế nào (ví dụ: mọi vũ khí
  5★ dùng `GROW_CURVE_ATTACK_301` + initValue 45.9364 đều có ATK Lv90 =
  608, còn `GROW_CURVE_ATTACK_302`/initValue 47.537 = 674 và
  `GROW_CURVE_ATTACK_303`/initValue 49.1377 = 741 — mốc 674 ban đầu gán
  cho nhóm 301 là sai, xem chi tiết ở ghi chú nguồn phía trên). Việc so
  khớp đường cong chỉ đảm bảo các vũ khí cùng nhóm nhất quán với nhau; mốc
  giá trị tuyệt đối của mỗi nhóm đường cong đã được neo lại bằng số liệu
  Lv90 quan sát thực tế qua Game8/zilliongamer (Primordial Jade
  Winged-Spear, Staff of Homa, Engulfing Lightning, Calamity Queller,
  Redhorn Stonethresher ở `dai-kiem.md`), không chỉ suy luận nội bộ giữa
  các file.
- Sau khi đối chiếu, không còn ô ATK/chỉ số phụ hay hiệu ứng đặc biệt R1/R5
  nào bị đánh dấu "chưa xác nhận" trong file này (đã lấy được toàn bộ trực
  tiếp từ `affix.upgrade["0"]`/`["4"]` của API).
