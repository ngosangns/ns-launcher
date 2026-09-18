# Đại kiếm (Claymore)

> Ngày lấy dữ liệu: 2026-09-08. Phiên bản game hiện hành khi biên soạn: ~7.0
> (Genshin Impact).
>
> **Đã đối chiếu lại (2026-09-08)**: bản đầu tiên của file này được soạn khi
> `api.ambr.top`/`gi.yatta.moe` không phân giải được DNS và Fandom Wiki trả
> về HTTP 402, nên phải dùng nguồn thứ cấp và đánh dấu "chưa xác nhận" cho
> phần lớn ATK cấp 1, chỉ số phụ chính xác, và số liệu tinh luyện R1→R5.
> Lần này `gi.yatta.moe` truy cập được bình thường qua `curl` — toàn bộ số
> liệu ATK/chỉ số phụ/hiệu ứng đặc biệt đã lấy trực tiếp từ JSON thô của
> `gi.yatta.moe/api/v2/en/weapon/{id}` (đọc `initValue` và mã đường cong
> tăng trưởng `GROW_CURVE_ATTACK_*`/`GROW_CURVE_CRITICAL_*`, rồi đối chiếu
> chéo giữa các vũ khí dùng chung đường cong — hai vũ khí cùng mã đường
> cong và cùng `initValue` chắc chắn có cùng giá trị cuối ở cấp 90), đối
> chiếu thêm qua WebSearch cho cách lấy/nhân vật phù hợp của các vũ khí
> mới. Không còn mục nào bị đánh dấu "chưa xác nhận" trong file này.
>
> **Lỗi phát hiện và đã sửa so với bản trước**:
> - 7 vũ khí bị gán nhầm loại và đã bị loại khỏi file (không phải Đại
>   kiếm theo API): *Summit Shaper* (Sword), *Chain Breaker* (Bow),
>   *Clash of Kings* (Catalyst), *Heretic's Molten Blade*, *Kagotsurube
>   Isshin*, *Toukabou Shigure*, *Wolf-Fang* (đều là Sword).
> - Bổ sung 11 vũ khí Đại kiếm thật sự nhưng bị thiếu hoàn toàn trong bản
>   trước: *A Teaspoon of Transcendence*, *Beacon of the Reed Sea*, *Gest
>   of the Mighty Wolf* (5★); *"Ultimate Overlord's Mega Magic Sword"*,
>   *Blackcliff Slasher*, *Blade of Atonement*, *Flame-Forged Insight*,
>   *Forest Regalia*, *Forged by the Golden Melody*, *Katsuragikiri
>   Nagamasa*, *Mailed Flower*, *Master Key*, *Talking Stick*, *The Bell*
>   (4★) — nay file bao quát toàn bộ Đại kiếm đã phát hành đến ~7.0.
> - ATK Lv90 sai do đoán nhầm nhóm đường cong: *The Unforged* (674→608,
>   trùng đường cong với *Wolf's Gravestone*), *Song of Broken Pines*,
>   *A Thousand Blazing Suns*, *Fang of the Mountain King* (674→741, trùng
>   đường cong với *Crane's Echoing Call*/*Angelos' Heptades* đã xác nhận ở
>   `phap-khi.md`); *Bloodtainted Greatsword* (401→354); *Old Merc's Pal*
>   (2★, 220→243 — số 220 hóa ra là lỗi ở `phap-khi.md`, xác nhận chéo qua
>   WebSearch); gần như toàn bộ 4★ trước đó bị gán đồng loạt "454" dù thực
>   ra thuộc 3 nhóm đường cong khác nhau (454/510/565 tùy vũ khí).
> - Chỉ số phụ sai nhãn hoặc sai số: *Wolf's Gravestone*/*The Unforged*
>   (ghi nhầm "CRIT Rate" trong khi thực ra là ATK% 49.6%), *Summit Shaper*
>   cũ cũng bị gán nhầm tương tự trước khi bị loại khỏi file; *Akuoumaru*,
>   *Lithic Blade*, *Luxurious Sea-Lord*, *Makhaira Aquamarine*,
>   *Portable Power Saw*, *Whiteblind*, *White Iron Greatsword*,
>   *Bloodtainted Greatsword* đều bị ghi sai loại chỉ số phụ (ví dụ gán
>   "Elemental Mastery"/"Physical DMG Bonus" cho vũ khí thực ra có ATK%
>   hoặc DEF%, v.v.).
> - Hiệu ứng đặc biệt mô tả sai cơ chế (không chỉ thiếu số liệu R2–R4):
>   *Redhorn Stonethresher* (thực ra là DEF% + sát thương đòn thường/trọng
>   kích cộng thêm theo DEF, không phải giảm DEF địch), *Wolf's
>   Gravestone* (buff ATK toàn đội kích hoạt khi đánh trúng địch dưới 30%
>   HP, không phải khi hạ gục), *The Unforged* (Golden Majesty thật sự —
>   trước đó mô tả nhầm hoàn toàn), *Song of Broken Pines*, *Royal
>   Greatsword*, *Lithic Blade*, *Fruitful Hook*, *Bloodtainted
>   Greatsword*, *White Iron Greatsword*, *Rainslasher*, *Serpent Spine*,
>   *Ferrous Shadow*, *Debate Club* đều có mô tả hiệu ứng khác đáng kể so
>   với JSON gốc của game.
>
> ATK cấp 1 ít có giá trị thực chiến (chỉ ATK cấp 90 mới quan trọng để tối
> ưu đội hình) nhưng nay đã lấy đủ từ `initValue` của API nên vẫn liệt kê
> đầy đủ.
>
> Vũ khí 1★/2★ không có chỉ số phụ và không có hiệu ứng đặc biệt/tinh luyện
> (tính năng tinh luyện chỉ áp dụng từ 3★ trở lên).

## 5★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Wolf's Gravestone | 46 | 608 | ATK% 49.6% | **Wolfish Tracker**: ATK +20/25/30/35/40%. Đòn thường/trọng kích trúng địch có HP dưới 30% sẽ tăng ATK toàn đội (kể cả người mang) +40/50/60/70/80% trong 12s; hồi chuỗi 30s. | Banner giới hạn (Wish) | Eula, Itto, các DPS Claymore on-field |
| Skyward Pride | 48 | 674 | Energy Recharge 36.8% | **Sky-ripping Dragon Spine**: tăng toàn bộ sát thương +8/10/12/14/16%. Sau khi dùng Bùng nổ nguyên tố, đòn thường/trọng kích trúng địch tạo một lưỡi chém chân không gây 80/100/120/140/160% ATK sát thương xuyên các mục tiêu trên đường đi; hiệu ứng kéo dài 20s hoặc tối đa 8 lưỡi chém. | Banner giới hạn (Wish) | Xinyan, DPS Claymore cần Energy Recharge |
| Song of Broken Pines | 49 | 741 | Physical DMG Bonus 20.7% | **Rebel's Banner-Hymn**: ATK +16/20/24/28/32%; đòn thường/trọng kích trúng địch cho 1 Sigil of Whispers (hồi 0.3s). Khi đủ 4 Sigil, tiêu hao toàn bộ để cấp cho bản thân và đồng đội gần đó hiệu ứng "Banner-Hymn" trong 12s: tốc độ đánh thường +12/15/18/21/24%, ATK +20/25/30/35/40%; sau khi kích hoạt, ngừng nhận Sigil mới trong 20s (các hiệu ứng cùng loại của "Millennial Movement" không cộng dồn). | Banner giới hạn (Wish, sự kiện Chronicled cũ) | DPS Vật lý Claymore: Eula, Razor |
| The Unforged | 46 | 608 | ATK% 49.6% | **Golden Majesty**: Khiên hấp thụ +20/25/30/35/40%. Đòn đánh trúng địch tăng ATK +4/5/6/7/8% trong 8s, tối đa 5 lớp, hồi 0.3s; khi có khiên bảo vệ, mức tăng ATK này nhân đôi (8/10/12/14/16%). | Banner giới hạn (Wish, sự kiện Chronicled cũ) | DPS Claymore đội hình khiên (Zhongli, Xingqiu-Zhongli) |
| Redhorn Stonethresher | 44 | 542 | CRIT DMG 88.2% | **Gokadaiou Otogibanashi**: DEF +28/35/42/49/56%; sát thương đòn thường và trọng kích được cộng thêm 40/50/60/70/80% giá trị DEF của người mang. | Banner giới hạn (Wish, vũ khí signature Itto) | Arataki Itto |
| Verdict | 48 | 674 | CRIT Rate 22.1% | **Many Oaths of Dawn and Dusk**: ATK +20/25/30/35/40%. Khi đồng đội thu Mảnh Nguyên Tố từ phản ứng Kết Tinh (Crystallize) hoặc kích hoạt phản ứng Lunar-Crystallize, người mang nhận 1 Seal: Kỹ năng nguyên tố +18/22.5/27/31.5/36% sát thương, thời lượng 15s, tối đa 2 Seal (từ Lunar-Crystallize tối đa 1 Seal/giây); toàn bộ Seal biến mất 0.2s sau khi Kỹ năng nguyên tố gây sát thương. | Banner giới hạn (Wish, vũ khí signature Navia) | Navia |
| A Thousand Blazing Suns | 49 | 741 | CRIT Rate 11.0% | **Sunset Reignites the Dawn**: khi dùng Kỹ năng/Bùng nổ nguyên tố, nhận "Scorching Brilliance" trong 6s: CRIT DMG +20/25/30/35/40% và ATK +28/35/42/49/56%; hồi chuỗi 10s. Đòn thường/trọng kích gây sát thương nguyên tố kéo dài Scorching Brilliance thêm 2s (hồi 1s, tối đa +6s). Khi người mang trong trạng thái Nightsoul's Blessing, hiệu ứng Scorching Brilliance +75% và không đếm ngược thời lượng khi rời sân. | Banner giới hạn (Wish, vũ khí signature Mavuika) | Mavuika |
| Fang of the Mountain King | 49 | 741 | CRIT Rate 11.0% | **Turquoise Hunt**: nhận 1 lớp Canopy's Favor sau khi Kỹ năng nguyên tố trúng địch (hồi 0.5s); khi đồng đội gần đó kích hoạt phản ứng Thiêu Đốt (Burning) hoặc Nảy Mầm (Burgeon), nhận thêm 3 lớp (hồi 2s, kích hoạt được cả khi đồng đội rời sân). Mỗi lớp Canopy's Favor: sát thương Kỹ năng và Bùng nổ nguyên tố +10/12.5/15/17.5/20% trong 6s, tối đa 6 lớp, mỗi lớp tính thời lượng riêng. | Banner giới hạn (Wish, vũ khí signature Kinich) | Kinich |
| A Teaspoon of Transcendence | 48 | 674 | CRIT DMG 44.1% | **White Fairy's Queening**: ATK +28/35/42/49/56%. Mỗi lần trọng kích trúng địch, người mang nhận "Transcendence" trong thời gian ngắn: sát thương phản ứng Stellar-Conduct và Stellar Swirl +16/20/24/28/32% trong 5s, hồi 0.2s, tối đa 3 lớp. | Banner giới hạn (Wish, vũ khí signature Sandrone, bản 6.7 Luna VIII) | Sandrone |
| Beacon of the Reed Sea | 46 | 608 | CRIT Rate 33.1% | **Desert Watch**: sau khi Kỹ năng nguyên tố trúng địch, ATK +20/25/30/35/40% trong 8s; sau khi nhận sát thương, ATK +20/25/30/35/40% trong 8s (2 hiệu ứng trên kích hoạt được cả khi rời sân). Khi không có khiên bảo vệ, HP tối đa +32/40/48/56/64%. | Banner giới hạn (Weapon Event Wish, vũ khí signature Dehya, bản 3.5) | Dehya |
| Gest of the Mighty Wolf | 46 | 608 | CRIT Rate 33.1% | **Indomitable Chivalry**: tăng tốc đánh thường +10%. Đòn thường trúng địch / dùng Kỹ năng nguyên tố / bắt đầu trọng kích lần lượt cho 1/2/2 lớp Four Winds' Hymn: sát thương gây ra +7.5/9.5/11.5/13.5/15.5% trong 4s, tối đa 4 lớp, hồi 0.01s. Khi đội có hiệu ứng "Hexerei: Secret Rite", mỗi lớp Four Winds' Hymn cũng tăng CRIT DMG người mang thêm 7.5/9.5/11.5/13.5/15.5%. | Banner giới hạn (Wish, vũ khí signature Varka, bản 6.4 Luna V) | Varka |

## 4★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Akuoumaru | 42 | 510 | ATK% 41.3% | **Watatsumi Wavewalker**: mỗi điểm Năng Lượng nguyên tố tối đa cộng dồn của toàn đội cho người mang +0.12/0.15/0.18/0.21/0.24% sát thương Bùng nổ nguyên tố, tối đa +40/50/60/70/80%. | Banner tiêu chuẩn (Wish) | Gorou, nhân vật Claymore burst-focused với đội nhiều Năng Lượng tối đa |
| Blackcliff Slasher | 42 | 510 | CRIT DMG 55.1% | **Press the Advantage**: sau khi hạ gục kẻ địch, ATK +12/15/18/21/24% trong 30s, tối đa 3 lớp, mỗi lớp tính thời lượng riêng. | Đổi Starglitter (Paimon's Bargains, dòng Blackcliff luân phiên theo tháng) | DPS Claymore cần CRIT DMG giá rẻ, dùng tạm cho hầu hết DPS |
| Blade of Atonement | 44 | 565 | ATK% 27.6% | **Repentance and Redemption**: kích hoạt phản ứng nguyên tố tăng Elemental Mastery người mang +64/80/96/112/128 trong 12s; kích hoạt phản ứng Stellar Glimmer tăng ATK +16/20/24/28/32% trong 12s (cả 2 hiệu ứng kích hoạt được cả khi rời sân). | Chế tạo (bản thiết kế từ Kuzmichev, Kuznets Smithy, Snezhnograd), bản 7.0 | DPS Claymore hệ phản ứng Stellar Glimmer (Sandrone) |
| Earth Shaker | 44 | 565 | ATK% 27.6% | **Oath of Qhapaq Nan**: sau khi đồng đội kích hoạt phản ứng liên quan Pyro, sát thương Kỹ năng nguyên tố người mang +16/20/24/28/32% trong 8s (kích hoạt được cả khi đồng đội rời sân). | Chế tạo | DPS/sub-DPS Claymore hệ Pyro dùng Kỹ năng nguyên tố nhiều |
| Favonius Greatsword | 41 | 454 | Energy Recharge 61.3% | **Windfall**: đòn chí mạng có 60/70/80/90/100% tỉ lệ tạo Hạt Nguyên Tố hồi 6 Năng Lượng, hồi chuỗi 12/10.5/9/7.5/6s. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore cần Energy Recharge |
| Flame-Forged Insight | 42 | 510 | Elemental Mastery 165 | **Mind in Bloom**: khi kích hoạt Điện Cảm (Electro-Charged), Lunar-Charged, Bloom/Lunar-Bloom, Kết Tinh (Crystallize) hoặc Lunar-Crystallize, hồi 12/15/18/21/24 Năng Lượng nguyên tố và Elemental Mastery +60/75/90/105/120 trong 15s; hồi chuỗi 15s, kích hoạt được cả khi rời sân. | Sự kiện (Sunspray Summer Resort) | Kaveh, Sayu, nhân vật scale Elemental Mastery cần hồi năng lượng |
| Forest Regalia | 44 | 565 | Energy Recharge 30.6% | **Forest Sanctuary**: sau khi kích hoạt Thiêu Đốt, Kích Phát, Tăng Kích, Lan Tỏa, Nảy Mầm (Bloom/Lunar-Bloom), Kích Nổ Siêu Cấp hoặc Bùng Nổ, một Leaf of Consciousness xuất hiện quanh người mang (tối đa 10s); nhặt được cho Elemental Mastery +60/75/90/105/120 trong 12s (chỉ tạo 1 lá/20s, kích hoạt được cả khi rời sân, hiệu ứng không cộng dồn). | Chế tạo (bản thiết kế "Tale of the Forest King" từ Aravinay sau chuỗi nhiệm vụ Aranyaka, Vanarana, Sumeru) | DPS/sub-DPS Claymore hệ phản ứng nguyên tố cần Energy Recharge |
| Forged by the Golden Melody | 42 | 510 | CRIT Rate 27.6% | **Day and Night in Counterpoint**: mỗi 10s, người mang lần lượt nhận 1 "Harmonic Movement" (10s): ATK +18/22.5/27/31.5/36% → Elemental Mastery +120/150/180/210/240 → sát thương phản ứng Stellar Glimmer +28/35/42/49/56% (kích hoạt được cả khi rời sân). Kích hoạt phản ứng Stellar Glimmer cho thêm 12s "Harmonic Movement: Contrapuntal" cùng hiệu ứng với lượt đang active, cộng dồn với Harmonic Movement gốc; hồi 12s. | Vé Thông Hành (Gnostic Hymn 3), bản 7.0 | DPS Claymore hệ phản ứng Stellar Glimmer (Sandrone, Beidou) |
| Fruitful Hook | 44 | 565 | ATK% 27.6% | **The Weight of Falling Branches**: CRIT Rate trọng kích rơi (Plunging Attack) +16/20/24/28/32%; sau khi trọng kích rơi trúng địch, sát thương đòn thường/trọng kích/trọng kích rơi +16/20/24/28/32% trong 10s. | Banner tiêu chuẩn (Wish) | DPS Claymore chuyên trọng kích rơi (build plunge) |
| Katsuragikiri Nagamasa | 42 | 510 | Energy Recharge 45.9% | **Samurai Conduct**: sát thương Kỹ năng nguyên tố +6/7.5/9/10.5/12%. Sau khi Kỹ năng nguyên tố trúng địch, người mang mất 3 Năng Lượng nhưng hồi 3/3.5/4/4.5/5 Năng Lượng mỗi 2s trong 6s tiếp theo; hồi chuỗi 10s, kích hoạt được cả khi rời sân. | Chế tạo (bản thiết kế từ rương kho báu cao cấp tại Tatarasuna, Inazuma) | Kuki Shinobu, Gorou, nhân vật Claymore cần Energy Recharge/spam Kỹ năng |
| Lithic Blade | 42 | 510 | ATK% 41.3% | **Lithic Axiom: Unity**: mỗi nhân vật trong đội có quê quán Liyue cho người mang +7/8/9/10/11% ATK và +3/4/5/6/7% CRIT Rate, tối đa 4 lần (tính theo quê quán Liyue, không phụ thuộc hệ nguyên tố). | Banner tiêu chuẩn (Wish) | Đội hình nhiều nhân vật Liyue: Itto, Albedo, Noelle, Xiao |
| Luxurious Sea-Lord | 41 | 454 | ATK% 55.1% | **Oceanic Victory**: tăng sát thương Bùng nổ nguyên tố +12/15/18/21/24%. Khi Bùng nổ nguyên tố trúng địch, 100% tỉ lệ triệu hồi đàn cá ngừ gây 100/125/150/175/200% ATK sát thương AoE; hồi chuỗi 15s. | Sự kiện (Event) | DPS/sub-DPS Claymore hệ Thủy |
| Mailed Flower | 44 | 565 | Elemental Mastery 110 | **Whispers of Wind and Flower**: trong 8s sau khi Kỹ năng nguyên tố trúng địch hoặc kích hoạt phản ứng nguyên tố, ATK +12/15/18/21/24% và Elemental Mastery +48/60/72/84/96. | Sự kiện (Windblume Festival 2023, mini-game "Floral Pursuit") — đã kết thúc, không lặp lại | Dehya, DPS/sub-DPS Claymore hệ phản ứng nguyên tố |
| Makhaira Aquamarine | 42 | 510 | Elemental Mastery 165 | **Desert Pavilion**: mỗi 10s, người mang nhận thêm ATK = 24/30/36/42/48% Elemental Mastery của bản thân trong 12s; đồng đội gần đó nhận 30% giá trị buff này trong cùng thời lượng. Nhiều bản sao vũ khí cho phép cộng dồn; kích hoạt được cả khi rời sân. | Banner tiêu chuẩn (Wish) | DPS Claymore scale Elemental Mastery |
| Master Key | 41 | 454 | Energy Recharge 61.3% | **Fall Into Place**: kích hoạt phản ứng nguyên tố tăng Elemental Mastery +60/75/90/105/120 trong 12s; khi có "Moonsign: Ascendant Gleam", tăng thêm 60/75/90/105/120 Elemental Mastery nữa; kích hoạt được cả khi rời sân. | Chế tạo (bản thiết kế từ Lyulka, Rossum Workshop, Nasha Town) | Aino, DPS/sub-DPS Claymore hệ phản ứng nguyên tố mùa Luna |
| Portable Power Saw | 41 | 454 | HP% 55.1% | **Sea Shanty**: khi người mang được hồi máu hoặc hồi máu cho đồng đội, nhận 1 Stoic's Symbol (tối đa 3, thời lượng 30s); dùng Kỹ năng/Bùng nổ nguyên tố tiêu hao toàn bộ Symbol để nhận "Roused" 10s: mỗi Symbol tiêu hao cho 40/50/60/70/80 Elemental Mastery, 2s sau đó hồi 2/2.5/3/3.5/4 Năng Lượng mỗi Symbol; hồi chuỗi Roused 15s, nhận Symbol được cả khi rời sân. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore hồi máu/scale Elemental Mastery |
| Prototype Archaic | 44 | 565 | ATK% 27.6% | **Crush**: đòn thường/trọng kích trúng địch có 50% tỉ lệ gây thêm 240/300/360/420/480% ATK sát thương AoE nhỏ; hồi chuỗi 15s. | Chế tạo | DPS Claymore trọng kích Vật lý |
| Rainslasher | 42 | 510 | Elemental Mastery 165 | **Bane of Storm and Tide**: sát thương gây cho địch dính hiệu ứng Thủy hoặc Lôi +20/24/28/32/36%. | Banner tiêu chuẩn (Wish) | DPS Claymore hệ Thủy/Lôi |
| Royal Greatsword | 44 | 565 | ATK% 27.6% | **Focus**: gây sát thương lên địch tăng CRIT Rate +8/10/12/14/16%, tối đa 5 lớp; một đòn chí mạng sẽ xóa toàn bộ lớp. | Đổi Starglitter (Paimon's Bargains, dòng Royal luân phiên theo tháng) | DPS Claymore ưu tiên ATK% thuần, build stack CRIT Rate |
| Sacrificial Greatsword | 44 | 565 | Energy Recharge 30.6% | **Composed**: sau khi Kỹ năng nguyên tố trúng địch, có 40/50/60/70/80% tỉ lệ hồi chuỗi Kỹ năng ngay lập tức; hồi chuỗi hiệu ứng 30/26/22/19/16s. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore cần spam Kỹ năng |
| Serpent Spine | 42 | 510 | CRIT Rate 27.6% | **Wavesplitter**: cứ mỗi 4s trên sân, sát thương gây ra +6/7/8/9/10% và sát thương phải nhận +3/2.7/2.4/2.2/2%; tối đa 5 lớp, không mất khi rời sân nhưng giảm 1 lớp khi nhận sát thương. | Battle Pass (Gnostic Hymn Bounty) | DPS trụ sân bền bỉ (mọi hệ vũ khí, đặc biệt Claymore) |
| Snow-Tombed Starsilver | 44 | 565 | Physical DMG Bonus 34.5% | **Frost Burial**: đòn thường/trọng kích trúng địch có 60/70/80/90/100% tỉ lệ tạo cơn lốc băng gây 80/95/110/125/140% ATK sát thương AoE (200/240/280/320/360% ATK nếu địch dính Băng); hồi chuỗi 10s. | Chế tạo (Dragonspine) | DPS Claymore hệ Băng |
| Talking Stick | 44 | 565 | CRIT Rate 18.4% | **"The Silver Tongue"**: sau khi dính Hỏa, ATK +16/20/24/28/32% trong 15s, hồi 12s. Sau khi dính Thủy/Băng/Lôi/Thảo, toàn bộ Elemental DMG Bonus +12/15/18/21/24% trong 15s, hồi 12s. | Vé Thông Hành (Gnostic Hymn 2) | Razor, nhân vật Claymore tự áp nguyên tố lên bản thân |
| The Bell | 42 | 510 | HP% 41.3% | **Rebellious Guardian**: nhận sát thương tạo khiên hấp thụ tối đa 20/23/26/29/32% HP tối đa, kéo dài 10s hoặc đến khi vỡ, hồi chuỗi 45s; trong lúc có khiên, sát thương gây ra +12/15/18/21/24%. | Banner tiêu chuẩn (Wish) hoặc Epitome Invocation (banner vũ khí giới hạn, tỉ lệ cao hơn) | DPS/tank Claymore scale HP, phổ thông giai đoạn đầu game |
| Tidal Shadow | 42 | 510 | ATK% 41.3% | **White Cruising Wave**: sau khi người mang được hồi máu, ATK +24/30/36/42/48% trong 8s; kích hoạt được cả khi rời sân. | Chế tạo (Fontaine) | DPS/sub-DPS Claymore hệ Thủy, đội hình hồi máu |
| Whiteblind | 42 | 510 | DEF% 51.7% | **Infusion Blade**: đòn thường/trọng kích trúng địch tăng ATK và DEF +6/7.5/9/10.5/12% trong 6s, tối đa 4 lớp, hồi 0.5s. | Chế tạo | DPS Claymore on-field phổ thông |
| "Ultimate Overlord's Mega Magic Sword" | 44 | 565 | Energy Recharge 30.6% | **Melussistance!**: ATK +12/15/18/21/24%. Ngoài ra, dựa theo số Melusine đã giúp đỡ tại Merusea Village, ATK cộng thêm tối đa +12/15/18/21/24% nữa. | Sự kiện Roses and Muskets (vũ khí miễn phí, không lặp lại ngoài rerun) | Vũ khí F2P ATK% thuần, không gắn với nhân vật cụ thể |

## 3★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Bloodtainted Greatsword | 38 | 354 | Elemental Mastery 187 | **Bane of Fire and Thunder**: sát thương gây cho địch dính hiệu ứng Hỏa hoặc Lôi +12/15/18/21/24%. | Banner tiêu chuẩn (Wish) | Sub-DPS Claymore hệ Hỏa/Lôi, nhân vật sơ khai |
| Debate Club | 39 | 401 | ATK% 35.2% | **Blunt Conclusion**: sau khi dùng Kỹ năng nguyên tố, đòn thường/trọng kích trúng địch gây thêm 60/75/90/105/120% ATK sát thương AoE nhỏ, hiệu ứng kéo dài 15s; sát thương cộng thêm chỉ kích hoạt 1 lần/3s. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore sơ khai, trọng kích |
| Ferrous Shadow | 39 | 401 | HP% 35.2% | **Unbending**: khi HP dưới 70/75/80/85/90%, sát thương trọng kích +30/35/40/45/50% và trọng kích khó bị ngắt hơn. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore sơ khai, trọng kích |
| Skyrider Greatsword | 39 | 401 | Physical DMG Bonus 43.9% | **Courage**: đòn thường/trọng kích trúng địch tăng ATK +6/7/8/9/10% trong 6s, tối đa 4 lớp, hồi 0.5s. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore sơ khai |
| White Iron Greatsword | 39 | 401 | DEF% 43.9% | **Cull the Weak**: hạ gục địch hồi 8/10/12/14/16% HP cho người mang. | Banner tiêu chuẩn (Wish) | Nhân vật Claymore sơ khai |

## 2★

| Vũ khí | ATK Lv1 | ATK Lv90 | Ghi chú |
|---|---|---|---|
| Old Merc's Pal | 33 | 243 | Không có chỉ số phụ, không có hiệu ứng đặc biệt. Chỉ dùng tạm giai đoạn đầu game. |

## 1★

| Vũ khí | ATK Lv1 | ATK Lv90 | Ghi chú |
|---|---|---|---|
| Waster Greatsword | 23 | 185 | Không có chỉ số phụ, không có hiệu ứng đặc biệt. Vũ khí khởi đầu, không dùng trong đội hình thực chiến. |

## Ghi chú tổng hợp

- Danh sách trên bao quát toàn bộ vũ khí Đại kiếm đã phát hành tính đến
  phiên bản ~7.0 (09/2026), lấy trực tiếp từ danh mục vũ khí đầy đủ của
  `gi.yatta.moe` (lọc theo `type = WEAPON_CLAYMORE`, loại trừ các bản
  "weapon skin" như *Ardent Storm*, *Silver Radiance of Gradlon*, *Super
  Awesome Magic Key*, *Unbreakable: Durandarte* vì chúng chỉ đổi hình dạng
  chứ không có thông số/passive riêng).
- Trước đó file này bị thiếu 11 vũ khí Đại kiếm thật sự và lẫn 7 vũ khí
  thực ra thuộc loại khác (Sword/Bow/Catalyst) — xem chi tiết ở ghi chú
  nguồn đầu file. Trường hợp tương tự từng gặp ở lần soạn trước cho
  Crimson Moon's Semblance, Disaster and Remorse, Bloodsoaked Ruins (thực
  ra là Polearm, đã chuyển sang `thuong.md`) — cho thấy việc đối chiếu
  `type` trực tiếp từ API đáng tin cậy hơn nhiều so với các bảng tổng hợp
  của bên thứ ba.
- Toàn bộ ATK Lv1/Lv90, chỉ số phụ, và số liệu tinh luyện R1→R5 trong file
  này đã được xác nhận qua JSON gốc của API — không còn mục nào đánh dấu
  "chưa xác nhận".
