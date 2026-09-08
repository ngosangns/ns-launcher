# Kiếm (Sword)

> Ngày lấy dữ liệu: 2026-09-08 (đợt biên soạn ban đầu), đối chiếu lại toàn bộ
> cùng ngày. Phiên bản game hiện hành khi biên soạn: ~7.0 (Genshin Impact).
>
> **Cập nhật đối chiếu (2026-09-08):** Lần biên soạn đầu chạy trong môi
> trường không truy cập được `api.ambr.top` / `gi.yatta.moe` (DNS không phân
> giải được) và Fandom Wiki (mọi endpoint trả về HTTP 402), nên phải dùng
> nguồn thứ cấp và đánh dấu "chưa xác nhận" rất nhiều ô. Trong lần đối chiếu
> này, cả `gi.yatta.moe` (API v2, đọc trực tiếp dữ liệu game qua
> `upgrade.prop`/`upgrade.promote`/`affix`) lẫn Fandom Wiki (đọc qua
> MediaWiki API `action=parse`, cả wikitext lẫn HTML infobox đã render) đều
> truy cập được bình thường, nên toàn bộ bảng bên dưới đã được đối chiếu lại
> với 2 nguồn ưu tiên số 1/2 theo quy định của `README.md` gốc — **không còn
> ô nào bị đánh dấu "chưa xác nhận"**, trừ 1 trường hợp trong cột "Nhân vật
> phù hợp" (Sword of Narzissenkreuz, vũ khí quá mới, chưa có meta rõ ràng).
>
> Việc đối chiếu phát hiện và sửa các lỗi sau từ bản biên soạn đầu (không chỉ
> ở các ô "chưa xác nhận" mà cả nhiều ô tưởng đã "chắc chắn"):
> - **ATK Lv90 sai hàng loạt**: bản đầu gán nhầm 674 cho nhiều vũ khí 5★
>   thực ra thuộc nhóm 608 (Skyward Blade, Freedom-Sworn, Haran Geppaku
>   Futsu, Exaiphanes Blade) hoặc nhóm 542 (Primordial Jade Cutter, Uraku
>   Misugiri, Peak Patrol Song); và gán đồng loạt 454 cho **mọi** vũ khí 4★
>   dù thực tế có ít nhất 5 mốc khác nhau (454/510/565/620/440 tùy đường
>   cong ATK riêng của từng vũ khí).
> - **Chỉ số phụ sai loại hoàn toàn** (không chỉ sai giá trị): Haran Geppaku
>   Futsu (CRIT Rate chứ không phải Elemental Mastery), Uraku Misugiri (CRIT
>   DMG chứ không phải CRIT Rate), và ở vũ khí 4★/3★: Amenoma Kageuchi,
>   Finale of the Deep, Lion's Roar, Royal Longsword, The Flute, Sword of
>   Narzissenkreuz (đều là ATK%, bản đầu ghi nhầm loại khác), Cool Steel
>   (ATK%, không phải Physical DMG Bonus), Dark Iron Sword (Elemental
>   Mastery, không phải Physical DMG Bonus).
> - **Primordial Jade Cutter**: CRIT Rate 44.1% (bản đầu ghi 22.1% — lẫn với
>   một vũ khí khác cùng đường cong ATK 674 nhưng đường cong chỉ số phụ khác
>   nhau; đây chính là loại lỗi "gán nhầm cả nhóm cùng đường cong" mà file
>   `phap-khi.md` cũng từng gặp).
> - **Hiệu ứng đặc biệt (passive) mô tả sai cơ chế**, không chỉ sai số:
>   Freedom-Sworn/Haran Geppaku Futsu (mô tả theo bản passive cũ trước khi
>   được rework), Primordial Jade Cutter, Skyward Blade, Uraku Misugiri,
>   Mistsplitter Reforged, Royal Longsword, The Black Sword, Finale of the
>   Deep, The Alley Flash, Xiphos' Moonlight, Lion's Roar (đổi cả nguyên tố
>   Pyro/Cryo → Pyro/Electro) — các mô tả này dường như bị bịa/lẫn cơ chế
>   giữa các vũ khí khác nhau; đã viết lại theo đúng dữ liệu game gốc.
> - **6 vũ khí bị xếp nhầm loại**: "Blade of Atonement", "Mailed Flower",
>   "Ultimate Overlord's Mega Magic Sword" (thực ra là Đại kiếm/Claymore),
>   "Echoes of the Heart", "Flowing Purity" (thực ra là Pháp khí/Catalyst),
>   và "Jade Vista" (thực ra là Cung/Bow) — cả 6 đã bị xóa khỏi file này vì
>   không phải Kiếm. **Đã kiểm tra lại (2026-09-08, đợt 2)**: cả 6 vũ khí này
>   đều đã có mặt và đúng dữ liệu ở file loại tương ứng (`dai-kiem.md` cho 3
>   Đại kiếm, `phap-khi.md` cho 2 Pháp khí, `cung.md` cho Jade Vista) — không
>   cần bổ sung gì thêm.
>
> **Cập nhật (2026-09-08, đợt 2):** đã bổ sung 14 vũ khí Kiếm 4★ còn thiếu —
> Cinnabar Spindle, Kagotsurube Isshin, Sapwood Blade, Toukabou Shigure,
> Wolf-Fang, Fleuve Cendre Ferryman, The Dockhand's Assistant, Sturdy Bone,
> Flute of Ezpitzal, Calamity of Eshu, Serenity's Call, Moonweaver's Dawn,
> Heretic's Molten Blade, Emberwell — số liệu ATK/chỉ số phụ lấy trực tiếp từ
> `gi.yatta.moe` (đối chiếu đường cong `GROW_CURVE_ATTACK_20x`/
> `GROW_CURVE_CRITICAL_201` với các vũ khí đã xác nhận trong bảng) và xác
> nhận chéo bằng giá trị Lv1→Lv90 dựng sẵn (`pi-smart-data-value`) trong
> infobox đã render của Fandom; cách lấy/nhiệm vụ/nhân vật phù hợp xác minh
> qua `obtain`/`series`/`event_name`/`quest` trong wikitext Fandom. 5 vũ khí
> 5★ từng bị liệt là "còn thiếu" ở bản trước (Summit Shaper, Key of
> Khaj-Nisut, Light of Foliar Incision, Splendor of Tranquil Waters,
> Lightbearing Moonshard) hóa ra **đã có sẵn** trong bảng 5★ ở trên từ trước
> — không cần thêm. Ba trang Fandom "Prized Isshin Blade (Awakened)",
> "Prized Isshin Blade (Shattered)" và "Sword of Narzissenkreuz (Quest)"
> **không phải vũ khí thật** — đây là các phiên bản tạm thời chỉ tồn tại
> trong lúc làm nhiệm vụ (không có trong danh mục vũ khí của
> `gi.yatta.moe`, `maxrank=1`), bị thay thế/biến mất khi hoàn thành nhiệm vụ
> tương ứng, nên không đưa vào bảng. File hiện có đủ 56 vũ khí Kiếm khả dụng
> thật sự (không tính các vật phẩm quest-exclusive tạm thời nói trên).
>
> ATK cấp 1 nhìn chung **không quan trọng** cho việc tối ưu đội hình (chỉ
> ATK cấp 90 mới có ý nghĩa thực chiến) nhưng nay đã điền đầy đủ vì lấy được
> trực tiếp từ dữ liệu game (không tốn thêm công sức đáng kể).
>
> Vũ khí 1★/2★ không có chỉ số phụ và không có hiệu ứng đặc biệt/tinh luyện
> (tính năng tinh luyện chỉ áp dụng từ 3★ trở lên).

## 5★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Aquila Favonia | 48 | 674 | Physical DMG Bonus 41.3% | **Falcon's Defiance**: ATK +20/25/30/35/40%. Khi nhận sát thương: hồi HP = 100/115/130/145/160% ATK và gây 200/230/260/290/320% ATK sát thương AoE quanh nhân vật; hồi chuỗi 15s. | Banner giới hạn (Wish, tỉ lệ rất thấp) | Diluc, Bennett, các DPS/sub-DPS hệ Vật lý |
| Freedom-Sworn | 46 | 608 | Elemental Mastery 198 | **Revolutionary Chorale**: Nhận +10/12.5/15/17.5/20% sát thương. Khi người mang gây phản ứng nguyên tố, nhận 1 Sigil of Rebellion (hồi chuỗi 0.5s, có thể kích hoạt cả khi rời sân). Khi có đủ 2 Sigil, tiêu hao toàn bộ để cấp cho các thành viên gần đó hiệu ứng "Millennial Movement: Song of Resistance" trong 12s: đòn thường/trọng kích/rơi tự do +16/20/24/28/32% sát thương và ATK +20/25/30/35/40%; sau khi kích hoạt, không nhận thêm Sigil trong 20s (các buff cùng loại từ nhiều vũ khí Millennial Movement không cộng dồn). | Banner giới hạn (Wish, sự kiện Chronicled cũ) | Sub-DPS/hỗ trợ buff cả đội: Kazuha, Sucrose, Yelan |
| Haran Geppaku Futsu | 46 | 608 | CRIT Rate 33.1% | **Honed Flow**: Nhận +12/15/18/21/24% sát thương nguyên tố mọi hệ (thường trực). Khi đồng đội gần đó dùng Kỹ năng nguyên tố, người mang nhận 1 lớp Wavespike (tối đa 2 lớp, hồi chuỗi 0.3s). Khi người mang dùng Kỹ năng nguyên tố, tiêu hao toàn bộ lớp Wavespike để nhận Rippling Upheaval: mỗi lớp tiêu hao +20/25/30/35/40% sát thương đòn thường trong 8s. | Banner giới hạn (Wish) | Ayato, các DPS đòn thường tần suất cao |
| Mistsplitter Reforged | 48 | 674 | CRIT DMG 44.1% | **Mistsplitter's Edge**: Nhận +12/15/18/21/24% sát thương nguyên tố mọi hệ, đồng thời nhận stack Mistsplitter's Emblem: ở 1/2/3 lớp Emblem, cộng thêm sát thương nguyên tố hệ nhân vật là 8/16/28% (R1), 10/20/35% (R2), 12/24/42% (R3), 14/28/49% (R4), 16/32/56% (R5). Nhận 1 lớp khi đòn thường gây sát thương nguyên tố (5s) hoặc dùng Bùng nổ nguyên tố (10s); mất lớp khi đầy Năng lượng. | Banner giới hạn (Wish) | Raiden Shogun, Yoimiya, Kazuha, DPS on-field mono hệ |
| Primordial Jade Cutter | 44 | 542 | CRIT Rate 44.1% | **Protector's Virtue**: HP tối đa +20/25/30/35/40%. Ngoài ra, nhận thêm ATK bằng 1.2/1.5/1.8/2.1/2.4% HP tối đa của người mang. | Banner giới hạn (Wish) | Hầu hết DPS kiếm on-field: Kamisato Ayaka, Keqing |
| Skyward Blade | 46 | 608 | Energy Recharge 55.1% | **Sky-Piercing Fang**: CRIT Rate +4/5/6/7/8%. Khi dùng Bùng nổ nguyên tố, nhận Skypiercing Might trong 12s: tốc độ di chuyển +10%, tốc độ tấn công +10%, đòn thường/trọng kích gây thêm sát thương bằng 20/25/30/35/40% ATK. | Banner giới hạn (Wish) | DPS cần Energy Recharge, đội cần tần suất Bùng nổ cao |
| Uraku Misugiri | 44 | 542 | CRIT DMG 88.2% | **Brocade Bloom, Shrine Sword**: Sát thương đòn thường +16/20/24/28/32%, sát thương Kỹ năng nguyên tố +24/30/36/42/48%; khi có đồng đội gây sát thương Geo gần đó, hiệu ứng trên +100% trong 15s và DEF người mang +20/25/30/35/40%. | Sự kiện Event-Wish giới hạn (không lặp lại ngoài rerun) | Chiori, các DPS/sub-DPS scale theo DEF |
| Absolution | 48 | 674 | CRIT DMG 44.1% | **Deathly Pact**: CRIT DMG +20/25/30/35/40%. Khi tăng giá trị Bond of Life, sát thương gây ra +16/20/24/28/32% trong 6s, tối đa 3 lớp. | Banner giới hạn (Wish, vũ khí signature Clorinde) | Clorinde, các DPS cơ chế Bond of Life |
| Athame Artis | 46 | 608 | CRIT Rate 33.1% | **Day King's Splendor Solis**: CRIT DMG của Bùng nổ nguyên tố +16/20/24/28/32%. Khi Bùng nổ nguyên tố trúng địch, nhận hiệu ứng: ATK người mang +20/25/30/35/40%, ATK đồng đội xuất trận gần đó +16/20/24/28/32% trong 3s; nếu đội có hiệu ứng Hexerei: Secret Rite, hiệu ứng trên +75%. | Banner giới hạn (Weapon Event Wish, vũ khí signature Durin) | Durin, sub-DPS/hỗ trợ kiếm dùng Bùng nổ nguyên tố |
| Azurelight | 48 | 674 | CRIT Rate 22.1% | **Whitehill's Bestowal**: Trong 12s sau khi dùng Kỹ năng nguyên tố, ATK +24/30/36/42/48%; nếu người mang có 0 Năng lượng trong thời gian này, ATK tăng thêm 24/30/36/42/48% và CRIT DMG +40/50/60/70/80%. | Banner giới hạn (Wish, vũ khí signature Skirk) | Skirk (gần như độc quyền do cơ chế 0 Năng lượng) |
| Exaiphanes Blade | 46 | 608 | CRIT Rate 33.1% | **Traveler's Path** (chỉ có hiệu lực khi trang bị cho Nhà Lữ Hành): sau khi đòn tấn công trúng địch, hồi 3 (R1) hoặc 5 (R2–R5) Năng lượng nguyên tố, hồi chuỗi 5s, có thể kích hoạt cả khi rời sân. R1: ATK +16% trong 8s. R2–R5: thêm CRIT DMG +6% cho mỗi nguyên tố đã cộng hưởng (Elemental Resonance), và ATK tăng 20/24/32/40% (R2/R3/R4/R5) trong 8s thay vì 16%. | Nhiệm vụ (Quest: Great Deeds on the Tundra, thuộc cốt truyện Nod-Krai) — vũ khí miễn phí | Nhà Lữ Hành (Traveler), đặc biệt bản Cryo mới |
| Whitelake Frostfeather | 48 | 674 | CRIT Rate 22.1% | **Snow Swan's Finale**: đòn Kỹ năng nguyên tố trúng địch cho "Lake-Hued Lament": ATK +8/10/12/14/16% trong 8s (trúng tối đa 1 lần/0.1s, tối đa 3 lớp, mỗi lớp tính thời lượng riêng). Ở 3 lớp: CRIT DMG của sát thương phản ứng Stellar-Glimmer +50/65/80/95/110%; khi kích hoạt phản ứng/gây sát thương Stellar-Glimmer, hồi 4/4.5/5/5.5/6 Năng lượng nguyên tố (hồi chuỗi 3.5s, có thể kích hoạt cả khi rời sân). | Banner giới hạn (Wish, vũ khí signature Odette) | Odette |
| Peak Patrol Song | 44 | 542 | DEF% 82.7% | **Halcyon Years Unending**: sau đòn thường/trọng kích trúng địch, nhận "Ode to Flowers": DEF +8/10/12/14/16% và sát thương nguyên tố mọi hệ +10/12.5/15/17.5/20% trong 6s (trúng tối đa 1 lần/0.1s, tối đa 2 lớp). Ở 2 lớp (hoặc làm mới lớp 2), toàn đội gần đó nhận thêm 8/10/12/14/16% sát thương nguyên tố mọi hệ cho mỗi 1000 DEF của người mang, tối đa 25.6/32/38.4/44.8/51.2%, trong 15s. | Banner giới hạn (Wish) | DPS/hỗ trợ scale theo DEF |
| Summit Shaper | 46 | 608 | ATK% 49.6% | **Golden Majesty**: Shield Strength +20/25/30/35/40%. Đòn đánh trúng địch tăng ATK +4/5/6/7/8% trong 8s, tối đa 5 lớp, hồi chuỗi 0.3s; khi đang có khiên bảo vệ, hiệu ứng tăng ATK trên nhân đôi. | Banner giới hạn (Wish) | DPS/hỗ trợ đội hình có khiên (Zhongli, Xianyun, đội Geo mono) |
| Key of Khaj-Nisut | 44 | 542 | HP% 66.1% | **Sunken Song of the Sands**: HP +20/25/30/35/40%. Kỹ năng nguyên tố trúng địch cho hiệu ứng Grand Hymn 20s: EM +0.12/0.15/0.18/0.21/0.24% HP tối đa (hồi chuỗi 0.3s, tối đa 3 lớp). Đủ 3 lớp (hoặc làm mới lớp 3), toàn đội gần đó nhận thêm EM +0.2/0.25/0.3/0.35/0.4% HP tối đa của người mang trong 20s. | Banner giới hạn (Wish, vũ khí signature Nilou) | Nilou |
| Light of Foliar Incision | 44 | 542 | CRIT DMG 88.2% | **Whitemoon Bristle**: CRIT Rate +4/5/6/7/8%. Đòn thường gây sát thương nguyên tố cho hiệu ứng Foliar Incision: sát thương Đòn thường và Kỹ năng nguyên tố +120/150/180/210/240% Tinh Thông Nguyên Tố, mất sau 28 lần trúng đòn hoặc 12s, chỉ nhận lại tối đa 1 lần mỗi 12s. | Banner giới hạn (Wish, vũ khí signature Alhaitham) | Alhaitham |
| Splendor of Tranquil Waters | 44 | 542 | CRIT DMG 88.2% | **Dawn and Dusk by the Lake**: khi HP hiện tại của người mang tăng/giảm, sát thương Kỹ năng nguyên tố +8/10/12/14/16% trong 6s, tối đa 3 lớp (hồi chuỗi 0.2s). Khi HP hiện tại của đồng đội khác tăng/giảm, HP tối đa người mang +14/17.5/21/24.5/28% trong 6s, tối đa 2 lớp (hồi chuỗi 0.2s, kích hoạt được cả khi rời sân). | Banner giới hạn (Wish, vũ khí signature Furina) | Furina |
| Lightbearing Moonshard | 44 | 542 | CRIT DMG 88.2% | **Legacy of Lang-Gan**: DEF +20/25/30/35/40%. Sau khi dùng Kỹ năng nguyên tố, sát thương phản ứng Lunar-Crystallize +64/80/96/112/128% trong 5s. | Banner giới hạn (Wish, vũ khí signature Zibai, bản 6.3 Luna IV) | Zibai; các DPS/hỗ trợ scale DEF hệ Geo khác (Chiori, Albedo) cũng dùng tốt nếu có nguồn Lunar-Crystallize |

## 4★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Amenoma Kageuchi | 41 | 454 | ATK% 55.1% | **Iwakura Succession**: Sau khi dùng Kỹ năng nguyên tố, nhận 1 Bản Nguyên Kết Tinh (hồi chuỗi 5s; mỗi Bản Nguyên tồn tại 30s, tối đa 3 Bản Nguyên cùng lúc). Khi dùng Bùng nổ nguyên tố, tiêu hao toàn bộ Bản Nguyên đang có, sau 2s hồi 6/7.5/9/10.5/12 Năng lượng nguyên tố cho mỗi Bản Nguyên đã tiêu hao. | Chế tạo (công thức mở qua nhiệm vụ "The Farmer's Treasure" ở Inazuma) | Nhân vật kiếm cần Energy Recharge sớm game |
| Blackcliff Longsword | 44 | 565 | CRIT DMG 36.8% | **Press the Advantage**: Sau khi hạ gục địch, ATK +12/15/18/21/24% trong 30s, tối đa 3 lớp, mỗi lớp tính thời lượng riêng. | Đổi Starglitter (Paimon's Bargains) | DPS kiếm CRIT DMG-focus giai đoạn giữa game |
| Calamity of Eshu | 44 | 565 | ATK% 27.6% | **Diffusing Boundary**: Khi nhân vật đang thi đấu được khiên bảo vệ, sát thương đòn thường/trọng kích +20/25/30/35/40% và CRIT Rate đòn thường/trọng kích +8/10/12/14/16%. | Sự kiện Iktomi Spiritseeking Scrolls (đã kết thúc, không lặp lại ngoài rerun; tinh luyện qua đổi Shuttle of Odara) | DPS kiếm đòn thường/trọng kích trong đội hình có khiên (Zhongli, Xianyun) |
| Cinnabar Spindle | 41 | 454 | DEF% 69.0% | **Spotless Heart**: Sát thương Kỹ năng nguyên tố +40/50/60/70/80% DEF của người mang. Hiệu ứng kích hoạt tối đa 1 lần/1.5s, mất 0.1s sau khi Kỹ năng nguyên tố gây sát thương. | Sự kiện Shadows Amidst Snowstorms (bản 2.2, đã kết thúc, không lặp lại ngoài rerun; tinh luyện qua đổi Alkahest) | Chiori, Zibai, các DPS/sub-DPS kiếm dùng Kỹ năng nguyên tố, scale theo DEF |
| Emberwell | 42 | 510 | Elemental Mastery 165 | **Starfire Upon the Snowplains**: Khi kích hoạt phản ứng nguyên tố, ATK +16/20/24/28/32% trong 12s. Khi kích hoạt phản ứng Stellar Glimmer, sát thương Stellar Glimmer +16/20/24/28/32% trong 12s. Cả 2 hiệu ứng kích hoạt được cả khi rời sân. | Chế tạo (bản thiết kế từ Kuzmichev, Kuznets Smithy, Snezhnograd), bản 7.0 | Odette, các DPS/sub-DPS kiếm hệ phản ứng Stellar Glimmer/Stellar-Conduct |
| Favonius Sword | 41 | 454 | Energy Recharge 61.3% | **Windfall**: Đòn chí mạng có 60/70/80/90/100% tỉ lệ tạo Hạt Nguyên Tố hồi 6 Năng lượng, hồi chuỗi 12/10.5/9/7.5/6s. | Banner tiêu chuẩn (Wish) | Nhân vật cần Energy Recharge, off-field support |
| Festering Desire | 42 | 510 | Energy Recharge 45.9% | **Undying Admiration**: Kỹ năng nguyên tố sát thương +16/20/24/28/32%, CRIT Rate của Kỹ năng nguyên tố +6/7.5/9/10.5/12%. | Sự kiện (The Chalk Prince and the Dragon) | DPS/sub-DPS dùng Kỹ năng nguyên tố nhiều |
| Finale of the Deep | 44 | 565 | ATK% 27.6% | **An End Sublime**: Khi dùng Kỹ năng nguyên tố, ATK +12/15/18/21/24% trong 15s và nhận Bond of Life bằng 25% HP tối đa (hồi chuỗi 10s). Khi Bond of Life được xóa, nhận thêm tối đa 150/187.5/225/262.5/300 ATK (cộng thẳng, không phải %) dựa trên 2.4/3/3.6/4.2/4.8% tổng lượng Bond of Life đã xóa, kéo dài 15s. | Chế tạo (Fontaine) | Nhân vật kiếm dùng Kỹ năng nguyên tố, scale Bond of Life |
| Fleuve Cendre Ferryman | 42 | 510 | Energy Recharge 45.9% | **Ironbone**: CRIT Rate của Kỹ năng nguyên tố +8/10/12/14/16%. Ngoài ra, sau khi dùng Kỹ năng nguyên tố, Energy Recharge +16/20/24/28/32% trong 5s. | Hiệp Hội Câu Cá Fontaine (đổi Martens' Omni-Fix bằng cá câu được để tinh luyện) | Nhân vật kiếm cần Energy Recharge và CRIT Rate cho Kỹ năng nguyên tố |
| Flute of Ezpitzal | 41 | 454 | DEF% 69.0% | **Smoke-and-Mirror Mystery**: Dùng Kỹ năng nguyên tố, DEF +16/20/24/28/32% trong 15s. | Chế tạo (bản thiết kế bán bởi Alom, Natlan) hoặc nhận miễn phí qua kích hoạt đủ 5 Furnace of Fiery Embers rồi rút thanh kiếm cổ tại Ochkanatlan (thử thách ẩn "Stoking the Ancient Flames") | Chiori, Zibai, các DPS/tank kiếm scale DEF dùng nhiều Kỹ năng nguyên tố |
| Heretic's Molten Blade | 42 | 510 | CRIT Rate 27.6% | **Lone Light's Blessing**: Sau khi dùng Kỹ năng nguyên tố, nhận "Gleam of First Light" (tối đa 14s, hồi chuỗi 14s, mất khi rời sân): mỗi giây, ATK tăng từ 18/22.5/27/31.5/36% đến 36/45/54/63/72% tùy quãng đường di chuyển trong giây trước đó. | Battle Pass (Gnostic Hymn 3), bản 7.0 | DPS kiếm cần di chuyển nhiều sau khi dùng Kỹ năng nguyên tố |
| Iron Sting | 42 | 510 | Elemental Mastery 165 | **Infusion Stinger**: Khi gây sát thương nguyên tố, tất cả sát thương +6/7.5/9/10.5/12% trong 6s, tối đa 2 lớp, hồi chuỗi 1s. | Chế tạo | Sub-DPS/hỗ trợ tạo phản ứng nguyên tố |
| Kagotsurube Isshin | 42 | 510 | ATK% 41.3% | **Isshin Art Clarity** (không có tinh luyện, chỉ 1 cấp duy nhất): Đòn thường/trọng kích/rơi tự do trúng địch tạo một cơn gió chém gây 180% ATK sát thương AoE và ATK +15% trong 8s; hồi chuỗi 8s. | Phần thưởng nhiệm vụ (Quest: Ere the End, a Glance Back — phần cuối của A Strange and Friendless Road, cốt truyện Kazuha) | Kazuha (phần thưởng gắn với nhiệm vụ của chính anh), các DPS kiếm đòn thường Vật Lý khác (vũ khí không thể tinh luyện thêm) |
| Lion's Roar | 42 | 510 | ATK% 41.3% | **Bane of Fire and Thunder**: Tăng sát thương lên địch đang dính hiệu ứng Pyro hoặc Electro (Sấm) +20/24/28/32/36%. | Banner tiêu chuẩn (Wish) | DPS Pyro/Electro dùng kiếm: Diluc, Keqing, Chevreuse-team |
| Moonweaver's Dawn | 44 | 565 | ATK% 27.6% | **Secret Silver's Testament**: Sát thương Bùng nổ nguyên tố +20/25/30/35/40%. Nếu Năng Lượng tối đa của người mang không vượt quá 60/40, sát thương Bùng nổ nguyên tố tăng thêm 16/20/24/28/32% (ngưỡng 60) hoặc 28/35/42/49/56% (ngưỡng 40). | Banner giới hạn (Weapon Event Wishes) hoặc Phần thưởng nhiệm vụ (Quest: Echoes of an Unfinished Past, thuộc chuỗi nhiệm vụ thế giới "Polkka Beneath the Moon's Oracle" ở Nod-Krai) | Keqing, Bennett, Kaeya, Jean — các DPS/support kiếm Bùng nổ nguyên tố có chi phí Năng Lượng ≤60 |
| Prototype Rancour | 44 | 565 | Physical DMG Bonus 34.5% | **Smashed Stone**: Đòn thường/trọng kích trúng địch: ATK +4/5/6/7/8% và DEF +4/5/6/7/8%, tối đa 4 lớp trong 6s, hồi chuỗi 0.3s. | Chế tạo | DPS kiếm on-field phổ thông giai đoạn đầu-giữa game |
| Royal Longsword | 42 | 510 | ATK% 41.3% | **Focus**: Khi gây sát thương lên địch, CRIT Rate +8/10/12/14/16% (tối đa 5 lớp, tối đa +40/50/60/70/80%); một đòn chí mạng sẽ xóa toàn bộ lớp đang có. | Đổi Starglitter (Paimon's Bargains) | DPS kiếm cần ATK% thuần, quản lý CRIT Rate qua stack |
| Sacrificial Sword | 41 | 454 | Energy Recharge 61.3% | **Composed**: Sau khi Kỹ năng nguyên tố gây sát thương lên địch, có 40/50/60/70/80% tỉ lệ hồi chuỗi Kỹ năng ngay lập tức, hồi chuỗi 30/26/22/19/16s. | Banner tiêu chuẩn (Wish) | Nhân vật cần spam Kỹ năng nguyên tố: Kaeya, Xingqiu (dù Xingqiu dùng kiếm) |
| Sapwood Blade | 44 | 565 | Energy Recharge 30.6% | **Forest Sanctuary**: Sau khi kích hoạt Thiêu Đốt, Kích Phát, Tăng Kích, Lan Tỏa, Nảy Mầm (Bloom/Lunar-Bloom), Kích Nổ Siêu Cấp hoặc Bùng Nổ, một Leaf of Consciousness xuất hiện quanh người mang (tối đa 10s); nhặt được cho EM +60/75/90/105/120 trong 12s (chỉ tạo 1 lá/20s, kích hoạt được cả khi rời sân, hiệu ứng không cộng dồn). | Chế tạo (bản thiết kế "Tale of the Desert" từ Aravinay sau chuỗi nhiệm vụ Aranyaka, Vanarana, Sumeru) | Alhaitham, Nhà Lữ Hành (Thảo), các DPS/sub-DPS kiếm hệ phản ứng Thảo/Bloom |
| Serenity's Call | 41 | 454 | Energy Recharge 61.3% | **Solemn Silence**: Khi gây phản ứng nguyên tố, HP tối đa +16/20/24/28/32% trong 12s; nếu có Moonsign: Ascendant Gleam, HP tối đa tăng thêm 16/20/24/28/32% nữa; kích hoạt được cả khi rời sân. | Chế tạo (bản thiết kế từ Lyulka, Rossum Workshop, Nasha Town) | Nhân vật kiếm gây phản ứng nguyên tố cần Energy Recharge, đặc biệt hưởng lợi mùa Luna (Moonsign: Ascendant Gleam) |
| Sturdy Bone | 44 | 565 | ATK% 27.6% | **Trapper's Pride**: Giảm 15% tiêu hao Thể Lực khi Chạy nước rút/Chạy nước rút thay thế. Sau khi dùng Chạy nước rút/Chạy nước rút thay thế, sát thương Đòn thường +16/20/24/28/32% ATK, hết hiệu lực sau 18 lần trúng đòn hoặc 7s. | Banner giới hạn (Weapon Event Wishes, series Heroes of Natlan) | DPS kiếm đòn thường Vật Lý tận dụng cơ chế Chạy nước rút tại Natlan |
| Sword of Descension | 39 | 440 | ATK% 35.2% | **Descension** (hiệu ứng cố định, không đổi theo cấp tinh luyện): đòn thường/trọng kích trúng địch có 50% tỉ lệ gây 200% ATK sát thương AoE nhỏ, hồi chuỗi 10s. Nếu trang bị cho Nhà Lữ Hành, ATK +66 (cộng thẳng, không phải %). | Quà tặng qua Mail (chỉ tài khoản từng chơi trên PS4/PS5; lấy được trên PC/Mobile qua Cross-Save) | Chỉ dùng được đầy đủ nếu có tài khoản liên kết PlayStation |
| Sword of Narzissenkreuz | 42 | 510 | ATK% 41.3% | **Hero's Blade**: Khi người mang không mang thuộc tính Arkhe (Pneuma/Ousia): đòn thường/trọng kích/rơi tự do trúng địch kích hoạt một vụ nổ năng lượng Pneuma hoặc Ousia, gây 160/200/240/280/320% ATK sát thương, hồi chuỗi 12s; loại năng lượng phụ thuộc thuộc tính hiện tại của vũ khí. | Phần thưởng nhiệm vụ (Quest: Rowboat's Wake) | Chưa xác nhận nhân vật đại diện cụ thể (vũ khí mới, chưa có meta rõ ràng) |
| The Alley Flash | 45 | 620 | Elemental Mastery 55 | **Itinerant Hero**: Tăng sát thương gây ra của người mang +12/15/18/21/24%. Khi người mang nhận sát thương, hiệu ứng này bị vô hiệu hóa trong 5s. | Banner giới hạn (Weapon Event Wish) | DPS kiếm EM/hybrid ít bị trúng đòn |
| The Black Sword | 42 | 510 | CRIT Rate 27.6% | **Justice**: Sát thương đòn thường/trọng kích +20/25/30/35/40%. Ngoài ra, khi đòn thường/trọng kích chí mạng (CRIT), hồi HP bằng 60/70/80/90/100% ATK, hồi chuỗi 5s. | Battle Pass (Gnostic Hymn Bounty) | DPS kiếm đòn thường: Kamisato Ayaka off-elemental build |
| The Dockhand's Assistant | 42 | 510 | HP% 41.3% | **Sea Shanty**: Khi người mang được hồi máu hoặc hồi máu cho đồng đội, nhận 1 Stoic's Symbol (tối đa 3, kéo dài 30s). Dùng Kỹ năng/Bùng nổ nguyên tố tiêu hao toàn bộ Symbol để nhận Roused trong 10s: mỗi Symbol tiêu cho 40/50/60/70/80 EM, 2s sau hồi 2/2.5/3/3.5/4 Năng lượng mỗi Symbol; hồi chuỗi Roused 15s, nhận Symbol được cả khi rời sân. | Banner giới hạn (Weapon Event Wishes, series Construction) | Nhân vật kiếm hồi máu/scale EM trong đội có healer |
| The Flute | 42 | 510 | ATK% 41.3% | **Chord**: Đòn thường/trọng kích trúng địch tích 1 nốt Harmonic (tối đa 1 nốt/0.5s, mỗi nốt tồn tại tối đa 30s). Đủ 5 nốt sẽ kích hoạt, gây 100/125/150/175/200% ATK sát thương Vật lý diện rộng quanh người mang. | Banner tiêu chuẩn (Wish) | DPS kiếm đòn thường/trọng kích tần suất cao |
| Toukabou Shigure | 42 | 510 | Elemental Mastery 165 | **Kaidan: Rainfall Earthbinder**: Đòn tấn công trúng địch gây hiệu ứng Cursed Parasol lên 1 mục tiêu trong 10s (hồi chuỗi 15s; hạ gục mục tiêu trong lúc còn hiệu ứng sẽ làm mới hồi chuỗi ngay lập tức). Người mang gây thêm 16/20/24/28/32% sát thương lên mục tiêu đang dính Cursed Parasol. | Sự kiện Akitsu Kimodameshi (đã kết thúc, không lặp lại ngoài rerun; tinh luyện qua đổi Parasol Talcum) | Kazuha, Alhaitham, các DPS/sub-DPS kiếm đơn mục tiêu cần Tinh Thông Nguyên Tố |
| Wolf-Fang | 42 | 510 | CRIT Rate 27.6% | **Northwind Wolf**: Sát thương Kỹ năng và Bùng nổ nguyên tố +16/20/24/28/32%. Khi Kỹ năng nguyên tố trúng địch, CRIT Rate của Kỹ năng +2/2.5/3/3.5/4% (tối đa 4 lớp); khi Bùng nổ nguyên tố trúng địch, CRIT Rate của Bùng nổ +2/2.5/3/3.5/4% (tối đa 4 lớp); mỗi hiệu ứng tính riêng, kéo dài 10s, hồi chuỗi 0.1s. | Battle Pass (Gnostic Hymn 2) | Kamisato Ayato, các DPS kiếm scale sát thương Kỹ năng/Bùng nổ nguyên tố |
| Xiphos' Moonlight | 42 | 510 | Elemental Mastery 165 | **Jinni's Whisper**: Cứ mỗi 10s, người mang nhận Energy Recharge bằng 0.036/0.045/0.054/0.063/0.072% cho mỗi điểm Elemental Mastery đang sở hữu, kéo dài 12s; đồng đội gần đó nhận 30% hiệu ứng này trong cùng thời gian (có thể kích hoạt cả khi rời sân; nhiều vũ khí cùng loại cộng dồn). | Banner giới hạn (Weapon Event Wish, series Tulaytullah) | Hỗ trợ buff Energy Recharge toàn đội theo EM |

## 3★

| Vũ khí | ATK Lv1 | ATK Lv90 | Chỉ số phụ (Lv90) | Hiệu ứng đặc biệt (R1 → R5) | Cách lấy | Nhân vật phù hợp |
|---|---|---|---|---|---|---|
| Cool Steel | 39 | 401 | ATK% 35.2% | **Bane of Water and Ice**: Tăng sát thương lên địch đang dính hiệu ứng Thủy hoặc Băng +12/15/18/21/24%. | Banner tiêu chuẩn (Wish) | Nhân vật kiếm sơ khai, F2P giai đoạn đầu |
| Dark Iron Sword | 39 | 401 | Elemental Mastery 141 | **Overloaded**: Khi người mang gây phản ứng Overloaded, Superconduct, Stellar-Conduct, Electro-Charged, Quicken, Aggravate, Hyperbloom, Lunar-Charged, hoặc Swirl (khi mang thuộc tính Electro), ATK +20/25/30/35/40% trong 12s. | Rương báu (Chest) | Nhân vật kiếm sơ khai gây phản ứng Electro |
| Fillet Blade | 39 | 401 | ATK% 35.2% | **Gash**: Trúng đòn có 50% tỉ lệ gây thêm 240/280/320/360/400% ATK sát thương lên 1 mục tiêu, hồi chuỗi 15/14/13/12/11s. | Rương báu (Chest) | Nhân vật cần ATK% sơ khai |
| Harbinger of Dawn | 39 | 401 | CRIT DMG 46.9% | **Vigorous**: Khi HP >90%, CRIT Rate +14/17.5/21/24.5/28%. | Banner tiêu chuẩn (Wish) | DPS máu cao, giữ HP trên 90% |
| Skyrider Sword | 38 | 354 | Energy Recharge 51.7% | **Determination**: Dùng Bùng nổ nguyên tố tăng ATK và tốc độ di chuyển +12/15/18/21/24% trong 15s. | Banner tiêu chuẩn (Wish) | Nhân vật kiếm sơ khai |
| Traveler's Handy Sword | 40 | 448 | DEF% 29.3% | **Journey**: Mỗi Hạt/Cầu Nguyên Tố nhặt được hồi 1/1.25/1.5/1.75/2% HP. | Rương báu (Chest) | Nhân vật kiếm sơ khai, F2P |

## 2★

| Vũ khí | ATK Lv1 | ATK Lv90 | Ghi chú |
|---|---|---|---|
| Silver Sword | 33 | 243 | Không có chỉ số phụ, không có hiệu ứng đặc biệt. Chỉ dùng tạm giai đoạn đầu game hoặc thử nghiệm chuỗi đòn. |

## 1★

| Vũ khí | ATK Lv1 | ATK Lv90 | Ghi chú |
|---|---|---|---|
| Dull Blade | 23 | 185 | Không có chỉ số phụ, không có hiệu ứng đặc biệt. Vũ khí khởi đầu, không dùng trong đội hình thực chiến. |

## Ghi chú tổng hợp

- Toàn bộ bảng 5★/4★/3★/2★/1★ đã được đối chiếu trực tiếp với `gi.yatta.moe`
  API v2 (dữ liệu trích xuất từ game) và Fandom Wiki (infobox đã render,
  gồm cả bảng "Ascensions and Stats" tính sẵn range Lv1→Lv90). Hai nguồn này
  khớp nhau ở mọi trường hợp đã kiểm tra chéo, nên độ tin cậy cao.
- **Cập nhật (2026-09-08, đợt 2):** đã bổ sung 14 vũ khí Kiếm 4★ còn thiếu
  (xem chi tiết nguồn/phương pháp ở ghi chú đầu file) và xác nhận 5 vũ khí
  5★ tưởng thiếu thực ra đã có sẵn trong bảng, cùng với việc xác nhận 6 vũ
  khí bị xếp nhầm loại ở đợt 1 đã tồn tại đúng chỗ tại `dai-kiem.md`/
  `phap-khi.md`/`cung.md`. File hiện có đủ 56 vũ khí Kiếm khả dụng thật sự
  trong game. Kagotsurube Isshin là trường hợp đặc biệt: hiệu ứng đặc biệt
  cố định, không đổi theo cấp tinh luyện R1–R5 (giống Sword of Descension).
- Sword of Descension là vũ khí không có refinement scaling chuẩn (hiệu ứng
  cố định bất kể R1–R5) và có cách lấy đặc biệt (quà tặng Mail cho tài khoản
  từng chơi PS4/PS5, mở khóa nơi khác qua Cross-Save) — không phải Wish tiêu
  chuẩn như bản trước ghi nhầm.
- Exaiphanes Blade chỉ có hiệu lực khi trang bị cho Nhà Lữ Hành (Traveler);
  cơ chế R1 khác hẳn R2–R5 (R2–R5 mới có thêm CRIT DMG theo số nguyên tố đã
  cộng hưởng).
