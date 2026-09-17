# Quái thú Trầm Thủy (Spiral Abyss)

Dữ liệu quái thú của **mùa Trầm Thủy hiện tại** (chu kỳ 1 tháng, reset ngày
16 — xem ghi chú "Chu kỳ tháng, không phải 2 tuần" trong
`2026-09-16-den-2026-10-15.md` cho bằng chứng; trước 2025-09 từng là 2
tuần, reset ngày 1 và 16, nên các file cũ hơn có thể khác nhịp). Đây là dữ
liệu hết hạn nhanh nhất trong kho — luôn ghi
rõ khoảng ngày áp dụng ở đầu file.

Mỗi tầng (thường chỉ tầng 9–12 có gimmick riêng, tầng 1–8 chủ yếu là quái
thường không đổi theo mùa) cần ghi:

- Danh sách quái theo từng nửa tầng (bên trái/phải hoặc đợt 1/đợt 2).
- Với mỗi loại quái: kích thước (nhỏ/vừa/lớn/trùm — ảnh hưởng AoE), nguyên
  tố tấn công/khiên nguyên tố (nếu có), điểm yếu (nguyên tố khắc chế, có bị
  choáng/đóng băng/cảm điện dễ không), lượng HP tham khảo.
- Hai loại chúc phúc, cần ghi rõ riêng biệt:
  - **Uyên Nguyệt Chúc Phúc (Blessing of the Abyssal Moon)**: áp dụng cho
    TOÀN BỘ Trầm Thủy (mọi tầng 1–12) suốt cả chu kỳ, chỉ 1 buff duy nhất
    mỗi mùa (nguồn: trang Fandom `Spiral Abyss/Blessing of the Abyssal
    Moon/<ngày-bắt-đầu>`).
  - **Ley Line Disorder**: riêng từng tầng 9–12, khác nhau mỗi tầng (đôi
    khi khác nhau theo nửa tầng).
- Gợi ý loại đội hình khắc chế (không cần đội hình cụ thể, chỉ cần định
  hướng nguyên tố/cơ chế).

## File

- Tên file theo khoảng ngày, ví dụ `2026-09-01-den-2026-09-15.md`. Khi mùa
  mới bắt đầu, tạo file mới thay vì ghi đè — giữ lại lịch sử để so sánh.

## Cập nhật khi mùa mới bắt đầu

Từng là các bước thủ công rải rác (tự tính khoảng ngày, tự gõ khung JSON theo
schema, chạy hai script sync riêng, tự nhớ validate + `swift test`).
`scripts/update-abyss-cycle.py` gộp toàn bộ luồng cơ học đó thành ba lệnh —
phần còn lại (đọc quái/chúc phúc/Ley Line Disorder từ wiki hoặc TextMap và
gõ vào JSON) vẫn phải làm tay, vì đó là phần duy nhất không thể suy ra từ dữ
liệu đã có:

```bash
# 1. Sinh khung file .md (ở đây) + .json — JSON nằm ở thư mục đè
#    (~/Library/Application Support/NSLauncher/abyss-cycles/), KHÔNG phải
#    Resources/Abyss/abyss-monsters/: app đang chạy đọc thẳng từ đây (đè lên
#    bản đóng gói cùng periodStart) nên sửa xong test được ngay, còn
#    `swift test` thì không thấy — một chu kỳ dở dang sẽ không làm đỏ
#    AbyssGoldenValueTests hay các test không liên quan khác.
python3 scripts/update-abyss-cycle.py new

# 2. Điền tay từng mục "TODO": quái theo từng wave, Uyên Nguyệt Chúc Phúc,
#    Ley Line Disorder từng tầng, recommendation. Tên quái phải khớp
#    game/wiki — bước 3 khớp theo tên.

# 3. Đồng bộ resistance + HP thật từ game, validate schema, chạy swift test —
#    dừng ngay ở bước đầu tiên fail để biết sửa gì trước.
python3 scripts/update-abyss-cycle.py sync

# 4. Ưng ý rồi thì copy vào bản đóng gói — từ đây swift test mới thực sự
#    thấy chu kỳ mới, và AbyssGoldenValueTests đỏ là chuyện phải làm tiếp
#    (sinh lại golden fixture), không phải lỗi.
python3 scripts/update-abyss-cycle.py publish
```

`new` không bao giờ ghi đè file đã có (kể cả nếu ai đó đã bắt đầu viết tay
chu kỳ kế tiếp), và khung JSON sinh ra giữ nguyên số tầng/chamber/wave/
monsterLevel của chu kỳ trước (những thứ hiếm khi đổi) nhưng luôn để trống
danh sách quái và đặt các trường văn bản của chu kỳ mới về `"TODO"` — thiếu
gì thì thấy ngay, không lặng lẽ giữ dữ liệu cũ. `sync` chỉ là gọi đúng
`scripts/sync-abyss-monster-resistance.py` rồi `scripts/sync-abyss-monster-hp.py`
(xem `Sources/NSLauncherApp/Resources/Abyss/README.md`), sau đó validate theo
`abyss-cycle.schema.json` và `swift test --filter Abyss`. `publish` chỉ copy
file — refuse nếu bản đóng gói cùng tên đã tồn tại.

**Lưu ý đã biết:** `AbyssViewModel` (khác `AbyssDataLibraryTests`) luôn đọc
thư mục đè thật khi tạo `AbyssDataLibrary()`, nên trong lúc một chu kỳ nháp
còn nằm ở đó, `AbyssSearchCachingTests.testAPreExistingCacheIsUsedOnTheFirstSearchOfTheSession`
có thể tự đỏ (cache seed theo digest tính *không* có thư mục đè, còn
`AbyssViewModel` mới tạo lại tính *có* — lệch digest, cache miss). Đây là lỗ
hổng cô lập test có từ trước, không phải do chu kỳ nháp sai; `swift test` đỏ
đúng một test này (và không đỏ gì khác) trong lúc có nháp thì bỏ qua, không
phải dấu hiệu dữ liệu chu kỳ mới sai.
